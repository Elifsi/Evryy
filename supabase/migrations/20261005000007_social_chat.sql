-- =============================================================================
-- 0007 — Social: connections, E2E-encrypted chat, ephemeral snaps & stories
-- Message bodies are ciphertext (client-side E2E). The server stores
-- `encrypted_payload` only and never sees plaintext.
-- =============================================================================

CREATE TABLE public.user_public_keys (
  user_id     UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  public_key  TEXT NOT NULL,                 -- base64 identity key for E2E key agreement
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- WeChat-style gate: strangers must be accepted before they can chat.
CREATE TABLE public.connections (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  addressee_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (requester_id <> addressee_id)
);
-- One relationship per unordered pair.
CREATE UNIQUE INDEX connections_pair_uniq ON public.connections (
  LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id)
);
CREATE INDEX connections_addressee_idx ON public.connections (addressee_id, status);

CREATE TABLE public.chats (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type          TEXT NOT NULL CHECK (type IN ('DIRECT', 'ORDER_SUPPORT', 'RIDE_COORDINATION', 'ROOM_ENQUIRY')),
  reference_id  UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX chats_reference_uniq ON public.chats (type, reference_id) WHERE reference_id IS NOT NULL;

CREATE TABLE public.chat_members (
  chat_id    UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);
CREATE INDEX chat_members_user_idx ON public.chat_members (user_id);

CREATE OR REPLACE FUNCTION public.is_chat_member(p_chat UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.chat_members WHERE chat_id = p_chat AND user_id = auth.uid());
$$;

CREATE TABLE public.messages (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id            UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id          UUID NOT NULL REFERENCES public.profiles(id),
  encrypted_payload  TEXT NOT NULL CHECK (length(encrypted_payload) <= 2000000),
  message_type       TEXT NOT NULL DEFAULT 'TEXT' CHECK (message_type IN ('TEXT', 'IMAGE', 'VOICE_NOTE', 'LIVE_RIDE_SHARE')),
  status             TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX messages_chat_idx ON public.messages (chat_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.start_direct_chat(p_other UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_me UUID := auth.uid(); v_chat UUID; v_ok BOOLEAN;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF NOT public.is_account_active(v_me) THEN RAISE EXCEPTION 'account is not active' USING ERRCODE = '42501'; END IF;
  IF p_other = v_me THEN RAISE EXCEPTION 'cannot chat with yourself'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.connections c
    WHERE c.status = 'accepted'
      AND ((c.requester_id = v_me AND c.addressee_id = p_other) OR (c.requester_id = p_other AND c.addressee_id = v_me))
  ) INTO v_ok;
  IF NOT v_ok THEN RAISE EXCEPTION 'you must be connected before chatting' USING ERRCODE = '42501'; END IF;

  SELECT cm1.chat_id INTO v_chat
    FROM public.chat_members cm1
    JOIN public.chat_members cm2 ON cm2.chat_id = cm1.chat_id AND cm2.user_id = p_other
    JOIN public.chats ch ON ch.id = cm1.chat_id AND ch.type = 'DIRECT'
   WHERE cm1.user_id = v_me LIMIT 1;
  IF v_chat IS NOT NULL THEN RETURN v_chat; END IF;

  INSERT INTO public.chats (type) VALUES ('DIRECT') RETURNING id INTO v_chat;
  INSERT INTO public.chat_members (chat_id, user_id) VALUES (v_chat, v_me), (v_chat, p_other);
  RETURN v_chat;
END;
$$;

-- Support / coordination chat for an order: consumer + store staff + assigned rider.
CREATE OR REPLACE FUNCTION public.open_order_chat(p_order UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_o public.orders; v_chat UUID; v_partner UUID;
BEGIN
  SELECT * INTO v_o FROM public.orders WHERE id = p_order;
  IF NOT FOUND OR v_o.consumer_id <> auth.uid() THEN RAISE EXCEPTION 'order not found'; END IF;
  SELECT id INTO v_chat FROM public.chats WHERE type = 'ORDER_SUPPORT' AND reference_id = p_order;
  IF v_chat IS NULL THEN
    INSERT INTO public.chats (type, reference_id) VALUES ('ORDER_SUPPORT', p_order) RETURNING id INTO v_chat;
  END IF;
  SELECT partner_id INTO v_partner FROM public.stores WHERE id = v_o.store_id;
  INSERT INTO public.chat_members (chat_id, user_id)
  SELECT v_chat, uid FROM (
    SELECT v_o.consumer_id AS uid
    UNION SELECT user_id FROM public.partner_members WHERE partner_id = v_partner
    UNION SELECT user_id FROM public.partner_members WHERE partner_id = v_o.rider_partner_id AND member_role = 'owner'
  ) u WHERE uid IS NOT NULL
  ON CONFLICT DO NOTHING;
  RETURN v_chat;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_messages_read(p_chat UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_chat_member(p_chat) THEN RAISE EXCEPTION 'not a member' USING ERRCODE = '42501'; END IF;
  UPDATE public.messages SET status = 'read'
   WHERE chat_id = p_chat AND sender_id <> auth.uid() AND status <> 'read';
END;
$$;

-- Ephemeral snaps
CREATE TABLE public.snaps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  storage_path  TEXT NOT NULL,
  filter_name   TEXT,
  opened_at     TIMESTAMPTZ,
  is_burned     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX snaps_recipient_idx ON public.snaps (recipient_id, is_burned);

-- The viewer is ALWAYS auth.uid() (never a caller-supplied id).
CREATE OR REPLACE FUNCTION public.open_and_burn_snap(p_snap_id UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_path TEXT;
BEGIN
  UPDATE public.snaps SET opened_at = now(), is_burned = TRUE
   WHERE id = p_snap_id AND recipient_id = auth.uid() AND is_burned = FALSE
   RETURNING storage_path INTO v_path;
  RETURN v_path;      -- NULL when not found / already burned
END;
$$;

CREATE TABLE public.stories (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  storage_path  TEXT NOT NULL,
  caption       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours')
);
CREATE INDEX stories_user_idx ON public.stories (user_id, expires_at DESC);

CREATE OR REPLACE FUNCTION public.are_connected(p_a UUID, p_b UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.connections c WHERE c.status = 'accepted'
      AND ((c.requester_id = p_a AND c.addressee_id = p_b) OR (c.requester_id = p_b AND c.addressee_id = p_a))
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_public_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snaps            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories          ENABLE ROW LEVEL SECURITY;

-- Public keys are needed by anyone who wants to message you.
CREATE POLICY pubkeys_read ON public.user_public_keys FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY pubkeys_write ON public.user_public_keys FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY connections_select ON public.connections FOR SELECT
  USING (requester_id = auth.uid() OR addressee_id = auth.uid() OR public.is_admin());
CREATE POLICY connections_request ON public.connections FOR INSERT
  WITH CHECK (requester_id = auth.uid() AND status = 'pending' AND public.is_account_active());
CREATE POLICY connections_respond ON public.connections FOR UPDATE
  USING (addressee_id = auth.uid()) WITH CHECK (addressee_id = auth.uid() AND status IN ('accepted', 'blocked'));
CREATE POLICY connections_delete ON public.connections FOR DELETE
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

CREATE POLICY chats_select ON public.chats FOR SELECT USING (public.is_chat_member(id));
CREATE POLICY chat_members_select ON public.chat_members FOR SELECT USING (public.is_chat_member(chat_id));

CREATE POLICY messages_select ON public.messages FOR SELECT USING (public.is_chat_member(chat_id));
CREATE POLICY messages_insert ON public.messages FOR INSERT
  WITH CHECK (sender_id = auth.uid() AND public.is_chat_member(chat_id) AND public.is_account_active());

CREATE POLICY snaps_select ON public.snaps FOR SELECT
  USING ((sender_id = auth.uid() OR recipient_id = auth.uid()) AND is_burned = FALSE);
CREATE POLICY snaps_insert ON public.snaps FOR INSERT
  WITH CHECK (sender_id = auth.uid() AND public.are_connected(sender_id, recipient_id) AND public.is_account_active());

CREATE POLICY stories_select ON public.stories FOR SELECT
  USING (expires_at > now() AND (user_id = auth.uid() OR public.are_connected(user_id, auth.uid())));
CREATE POLICY stories_write ON public.stories FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid() AND public.is_account_active());
