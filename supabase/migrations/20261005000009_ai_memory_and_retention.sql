-- =============================================================================
-- 0009 — AI memory, 30-day chat retention & scheduled maintenance
--
-- Design (see docs/architecture/dependencies-master.md §7):
--   * Raw AI chat is transient: purged after 30 days.
--   * Durable personalization = user_ai_profile (deterministic, computed from
--     orders) + user_memories (<= 50 short facts the user stated).
--   * Orders live in `orders`/`order_items` forever, so "what did I order last
--     Friday?" never depends on chat history.
--   * Personalization is CONSENT-BASED (Nepal Privacy Act 2018). Nothing is
--     injected into prompts unless the user opted in, and the user can view and
--     delete everything we remember.
-- =============================================================================

ALTER TABLE public.profiles
  ADD COLUMN ai_personalization_consent BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN ai_consent_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- Transient chat
-- ---------------------------------------------------------------------------
CREATE TABLE public.ai_chat_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  channel     TEXT NOT NULL DEFAULT 'chat' CHECK (channel IN ('chat', 'voice')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ai_sessions_user_idx ON public.ai_chat_sessions (user_id, created_at DESC);

CREATE TABLE public.ai_chat_messages (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id  UUID NOT NULL REFERENCES public.ai_chat_sessions(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'tool')),
  content     JSONB NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ai_messages_session_idx ON public.ai_chat_messages (session_id, id);
CREATE INDEX ai_messages_created_idx ON public.ai_chat_messages (created_at);   -- purge scan

-- ---------------------------------------------------------------------------
-- Durable memory
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_ai_profile (
  user_id                UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  spending_tier          TEXT NOT NULL DEFAULT 'budget' CHECK (spending_tier IN ('budget', 'mid', 'premium')),
  avg_order_value_paisa  BIGINT NOT NULL DEFAULT 0,
  orders_90d             INTEGER NOT NULL DEFAULT 0,
  top_items              JSONB NOT NULL DEFAULT '[]'::jsonb,      -- [{"name":"Buff Momo","qty":14}]
  top_stores             JSONB NOT NULL DEFAULT '[]'::jsonb,
  usual_order_hour       SMALLINT,                                -- 0..23, Asia/Kathmandu
  usual_order_weekday    SMALLINT,                                -- 0=Sun..6=Sat
  refreshed_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_memories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category    TEXT NOT NULL CHECK (category IN ('dietary', 'allergy', 'preference', 'routine', 'household', 'other')),
  fact        TEXT NOT NULL CHECK (length(fact) BETWEEN 3 AND 200),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX user_memories_user_idx ON public.user_memories (user_id, created_at DESC);

-- Hard cap of 50 facts per user: oldest drops first.
CREATE OR REPLACE FUNCTION public.cap_user_memories()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM public.user_memories
   WHERE id IN (SELECT id FROM public.user_memories WHERE user_id = NEW.user_id
                ORDER BY created_at DESC OFFSET 49);
  RETURN NEW;
END;
$$;
CREATE TRIGGER user_memories_cap AFTER INSERT ON public.user_memories
  FOR EACH ROW EXECUTE FUNCTION public.cap_user_memories();

-- LLM usage telemetry for the superadmin cost/error dashboard (no prompt text stored).
CREATE TABLE public.ai_usage_log (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id        UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  model          TEXT NOT NULL,
  prompt_tokens  INTEGER,
  output_tokens  INTEGER,
  cost_micro_usd BIGINT,
  latency_ms     INTEGER,
  ok             BOOLEAN NOT NULL DEFAULT TRUE,
  error_code     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ai_usage_created_idx ON public.ai_usage_log (created_at DESC);

-- ---------------------------------------------------------------------------
-- Deterministic profile refresh (zero LLM cost)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_user_ai_profile(p_user UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n INT; v_aov BIGINT; v_tier TEXT; v_items JSONB; v_stores JSONB; v_hour INT; v_dow INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user THEN
    RAISE EXCEPTION 'not permitted' USING ERRCODE = '42501';
  END IF;

  SELECT count(*), COALESCE(round(avg(total_paisa)), 0)::bigint INTO v_n, v_aov
    FROM public.orders WHERE consumer_id = p_user AND status = 'delivered' AND placed_at > now() - interval '90 days';

  v_tier := CASE WHEN v_n < 2 OR v_aov < 40000 THEN 'budget' WHEN v_aov < 120000 THEN 'mid' ELSE 'premium' END;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('name', name, 'qty', qty)), '[]'::jsonb) INTO v_items FROM (
    SELECT oi.name, sum(oi.quantity)::int AS qty
      FROM public.order_items oi JOIN public.orders o ON o.id = oi.order_id
     WHERE o.consumer_id = p_user AND o.status = 'delivered' AND o.placed_at > now() - interval '90 days'
     GROUP BY oi.name ORDER BY qty DESC, oi.name LIMIT 5) t;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('name', sname, 'orders', cnt)), '[]'::jsonb) INTO v_stores FROM (
    SELECT s.name AS sname, count(*)::int AS cnt
      FROM public.orders o JOIN public.stores s ON s.id = o.store_id
     WHERE o.consumer_id = p_user AND o.status = 'delivered' AND o.placed_at > now() - interval '90 days'
     GROUP BY s.name ORDER BY cnt DESC, s.name LIMIT 3) t;

  SELECT mode() WITHIN GROUP (ORDER BY extract(hour FROM placed_at AT TIME ZONE 'Asia/Kathmandu')),
         mode() WITHIN GROUP (ORDER BY extract(dow  FROM placed_at AT TIME ZONE 'Asia/Kathmandu'))
    INTO v_hour, v_dow
    FROM public.orders WHERE consumer_id = p_user AND status = 'delivered' AND placed_at > now() - interval '90 days';

  INSERT INTO public.user_ai_profile (user_id, spending_tier, avg_order_value_paisa, orders_90d, top_items, top_stores,
                                      usual_order_hour, usual_order_weekday, refreshed_at)
  VALUES (p_user, v_tier, v_aov, v_n, v_items, v_stores, v_hour, v_dow, now())
  ON CONFLICT (user_id) DO UPDATE SET
    spending_tier = EXCLUDED.spending_tier, avg_order_value_paisa = EXCLUDED.avg_order_value_paisa,
    orders_90d = EXCLUDED.orders_90d, top_items = EXCLUDED.top_items, top_stores = EXCLUDED.top_stores,
    usual_order_hour = EXCLUDED.usual_order_hour, usual_order_weekday = EXCLUDED.usual_order_weekday,
    refreshed_at = now();
END;
$$;

-- Everything the AI route needs at session start, in one cheap call.
-- Returns NULL when the user has not opted in.
CREATE OR REPLACE FUNCTION public.get_ai_context(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_consent BOOLEAN; v_prof public.user_ai_profile; v_mem JSONB;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user THEN
    RAISE EXCEPTION 'not permitted' USING ERRCODE = '42501';
  END IF;
  SELECT ai_personalization_consent INTO v_consent FROM public.profiles WHERE id = p_user;
  IF NOT COALESCE(v_consent, FALSE) THEN RETURN NULL; END IF;

  SELECT * INTO v_prof FROM public.user_ai_profile WHERE user_id = p_user;
  IF NOT FOUND OR v_prof.refreshed_at < now() - interval '6 hours' THEN
    PERFORM public.refresh_user_ai_profile(p_user);
    SELECT * INTO v_prof FROM public.user_ai_profile WHERE user_id = p_user;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category, 'fact', fact) ORDER BY created_at DESC), '[]'::jsonb)
    INTO v_mem FROM public.user_memories WHERE user_id = p_user;

  RETURN jsonb_build_object(
    'spending_tier', v_prof.spending_tier,
    'avg_order_value_npr', round(v_prof.avg_order_value_paisa / 100.0),
    'orders_90d', v_prof.orders_90d,
    'top_items', v_prof.top_items, 'top_stores', v_prof.top_stores,
    'usual_order_hour', v_prof.usual_order_hour, 'usual_order_weekday', v_prof.usual_order_weekday,
    'memories', v_mem);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_user_memory(p_user UUID, p_category TEXT, p_fact TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user THEN
    RAISE EXCEPTION 'not permitted' USING ERRCODE = '42501';
  END IF;
  IF NOT COALESCE((SELECT ai_personalization_consent FROM public.profiles WHERE id = p_user), FALSE) THEN
    RETURN;                                -- silently ignore: no consent, nothing stored
  END IF;
  IF EXISTS (SELECT 1 FROM public.user_memories WHERE user_id = p_user AND lower(fact) = lower(trim(p_fact))) THEN
    RETURN;
  END IF;
  INSERT INTO public.user_memories (user_id, category, fact) VALUES (p_user, p_category, trim(p_fact));
END;
$$;

-- Owner-invoked: set / withdraw consent. Withdrawing erases memory immediately.
CREATE OR REPLACE FUNCTION public.set_ai_personalization(p_enabled BOOLEAN)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  UPDATE public.profiles SET ai_personalization_consent = p_enabled,
         ai_consent_at = CASE WHEN p_enabled THEN now() ELSE NULL END WHERE id = auth.uid();
  IF NOT p_enabled THEN
    DELETE FROM public.user_memories WHERE user_id = auth.uid();
    DELETE FROM public.user_ai_profile WHERE user_id = auth.uid();
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_my_ai_data()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  DELETE FROM public.ai_chat_sessions WHERE user_id = auth.uid();   -- cascades to messages
  DELETE FROM public.user_memories    WHERE user_id = auth.uid();
  DELETE FROM public.user_ai_profile  WHERE user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.purge_old_ai_chats()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_n INT;
BEGIN
  DELETE FROM public.ai_chat_messages WHERE created_at < now() - interval '30 days';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  DELETE FROM public.ai_chat_sessions s
   WHERE s.created_at < now() - interval '30 days'
     AND NOT EXISTS (SELECT 1 FROM public.ai_chat_messages m WHERE m.session_id = s.id);
  RETURN v_n;
END;
$$;

-- ---------------------------------------------------------------------------
-- Maintenance housekeeping (cron targets)
-- ---------------------------------------------------------------------------
CREATE TABLE public.storage_cleanup_queue (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bucket      TEXT NOT NULL,
  path        TEXT NOT NULL,
  queued_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (bucket, path)
);
ALTER TABLE public.storage_cleanup_queue ENABLE ROW LEVEL SECURITY;   -- no policies: service role only

CREATE OR REPLACE FUNCTION public.purge_expired_ephemera()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Queue the files first; the `storage-janitor` Edge Function drains the queue
  -- and deletes the objects (SQL cannot safely delete Storage blobs itself).
  INSERT INTO public.storage_cleanup_queue (bucket, path)
  SELECT 'stories', storage_path FROM public.stories WHERE expires_at < now()
  UNION ALL
  SELECT 'snaps', storage_path FROM public.snaps
   WHERE (is_burned AND opened_at < now() - interval '1 day')
      OR (NOT is_burned AND created_at < now() - interval '30 days')
  ON CONFLICT DO NOTHING;

  DELETE FROM public.stories WHERE expires_at < now();
  DELETE FROM public.snaps   WHERE is_burned AND opened_at < now() - interval '1 day';
  DELETE FROM public.snaps   WHERE NOT is_burned AND created_at < now() - interval '30 days';
END;
$$;

-- Withdrawing consent by ANY route (RPC or direct column update) erases memory.
CREATE OR REPLACE FUNCTION public.erase_ai_memory_on_consent_withdrawal()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.ai_personalization_consent AND NOT NEW.ai_personalization_consent THEN
    DELETE FROM public.user_memories   WHERE user_id = NEW.id;
    DELETE FROM public.user_ai_profile WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER profiles_erase_ai_memory AFTER UPDATE OF ai_personalization_consent ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.erase_ai_memory_on_consent_withdrawal();

-- ---------------------------------------------------------------------------
-- Privileges for AI / maintenance functions
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.purge_old_ai_chats()      FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_expired_ephemera()  FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_ai_profile  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_memories    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_log     ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_sessions_own ON public.ai_chat_sessions FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY ai_messages_own ON public.ai_chat_messages FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.ai_chat_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));

-- Users may SEE and DELETE what we remember (transparency); inserts only via save_user_memory().
CREATE POLICY ai_profile_read   ON public.user_ai_profile FOR SELECT USING (user_id = auth.uid());
CREATE POLICY memories_read     ON public.user_memories   FOR SELECT USING (user_id = auth.uid());
CREATE POLICY memories_delete   ON public.user_memories   FOR DELETE USING (user_id = auth.uid());

CREATE POLICY ai_usage_admin ON public.ai_usage_log FOR SELECT USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- Scheduling (only when pg_cron is available — hosted Supabase and the
-- self-hosted image both ship it; plain Postgres test containers do not).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    PERFORM cron.schedule('evrry-expire-unpaid-holds', '* * * * *',  'SELECT public.expire_unpaid_holds()');
    PERFORM cron.schedule('evrry-purge-ai-chats',      '15 21 * * *', 'SELECT public.purge_old_ai_chats()');      -- 03:00 NPT
    PERFORM cron.schedule('evrry-purge-ephemera',      '*/30 * * * *', 'SELECT public.purge_expired_ephemera()');
  ELSE
    RAISE NOTICE 'pg_cron not available: schedule expire_unpaid_holds / purge_old_ai_chats / purge_expired_ephemera externally';
  END IF;
END $$;
