-- =============================================================================
-- 0003 — Identity, partners, KYC & superadmin moderation
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles  (1:1 with auth.users)
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role             public.user_role NOT NULL DEFAULT 'consumer',
  status           public.account_status NOT NULL DEFAULT 'active',
  suspended_until  TIMESTAMPTZ,
  cod_enabled      BOOLEAN NOT NULL DEFAULT TRUE,   -- superadmin can disable for abusers
  display_name     TEXT,
  handle           TEXT UNIQUE CHECK (handle ~ '^[a-z0-9_.]{3,30}$'),  -- WeChat-style discoverability
  phone            TEXT UNIQUE,
  avatar_path      TEXT,
  referral_code    TEXT UNIQUE NOT NULL DEFAULT upper(substr(encode(extensions.gen_random_bytes(5), 'hex'), 1, 8)),
  discoverable     BOOLEAN NOT NULL DEFAULT FALSE,  -- opt-in to be found by handle/QR
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX profiles_role_idx ON public.profiles (role);
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Create a profile automatically for every new auth user. Role is ALWAYS
-- 'consumer' here — it can never be chosen by the client via signup metadata.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, display_name)
  VALUES (NEW.id, NEW.phone, NEW.raw_user_meta_data ->> 'display_name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Role helpers (SECURITY DEFINER so RLS policies can call them without recursion)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'superadmin') AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_account_active(p_user UUID DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_user
      AND (status = 'active' OR (status = 'suspended' AND suspended_until IS NOT NULL AND suspended_until < now()))
  );
$$;

-- Prevent privilege escalation: a user may edit their own profile but never
-- role / status / suspension / COD flag. Those change only via admin RPCs or
-- the service role (auth.uid() IS NULL).
CREATE OR REPLACE FUNCTION public.guard_profile_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    IF NEW.role IS DISTINCT FROM OLD.role
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.suspended_until IS DISTINCT FROM OLD.suspended_until
       OR NEW.cod_enabled IS DISTINCT FROM OLD.cod_enabled
       OR NEW.referral_code IS DISTINCT FROM OLD.referral_code THEN
      RAISE EXCEPTION 'insufficient privilege to modify protected profile columns'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_guard BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_privileged_columns();

-- ---------------------------------------------------------------------------
-- user_addresses
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_addresses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label           TEXT NOT NULL DEFAULT 'Home',
  local_level_id  SMALLINT REFERENCES public.local_levels(id),
  ward_no         SMALLINT CHECK (ward_no BETWEEN 1 AND 35),
  street          TEXT,
  landmark        TEXT,
  instructions    TEXT,
  location        extensions.geography(Point, 4326) NOT NULL,
  is_default      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX user_addresses_user_idx ON public.user_addresses (user_id);
CREATE UNIQUE INDEX user_addresses_one_default ON public.user_addresses (user_id) WHERE is_default;

-- ---------------------------------------------------------------------------
-- partner_profiles — one business / rider / driver / hotel / landlord entity
-- ---------------------------------------------------------------------------
CREATE TABLE public.partner_profiles (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id          UUID NOT NULL REFERENCES public.profiles(id),
  type              public.partner_type NOT NULL,
  status            public.partner_status NOT NULL DEFAULT 'draft',
  legal_name        TEXT NOT NULL,
  trade_name        TEXT,
  pan_number        TEXT,
  contact_phone     TEXT,
  local_level_id    SMALLINT REFERENCES public.local_levels(id),
  ward_no           SMALLINT CHECK (ward_no BETWEEN 1 AND 35),
  address_text      TEXT,
  location          extensions.geography(Point, 4326),
  commission_bps    INTEGER NOT NULL DEFAULT 1500 CHECK (commission_bps BETWEEN 0 AND 5000),
  rejection_reason  TEXT,
  verified_by       UUID REFERENCES public.profiles(id),
  verified_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX partner_profiles_owner_idx  ON public.partner_profiles (owner_id);
CREATE INDEX partner_profiles_queue_idx  ON public.partner_profiles (type, status);
CREATE INDEX partner_profiles_geo_idx    ON public.partner_profiles USING gist (location);
CREATE TRIGGER partner_profiles_updated_at BEFORE UPDATE ON public.partner_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Staff access with RBAC (owner / manager / cashier)
CREATE TABLE public.partner_members (
  partner_id  UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  member_role TEXT NOT NULL CHECK (member_role IN ('owner', 'manager', 'cashier')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (partner_id, user_id)
);
CREATE INDEX partner_members_user_idx ON public.partner_members (user_id);

CREATE OR REPLACE FUNCTION public.is_partner_member(p_partner UUID, p_roles TEXT[] DEFAULT NULL)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.partner_members m
    WHERE m.partner_id = p_partner AND m.user_id = auth.uid()
      AND (p_roles IS NULL OR m.member_role = ANY (p_roles))
  );
$$;

-- Owner is automatically a member.
CREATE OR REPLACE FUNCTION public.add_owner_as_member()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.partner_members (partner_id, user_id, member_role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER partner_profiles_owner_member AFTER INSERT ON public.partner_profiles
  FOR EACH ROW EXECUTE FUNCTION public.add_owner_as_member();

-- Partners may not self-approve: verification columns are admin-only.
CREATE OR REPLACE FUNCTION public.guard_partner_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    IF NEW.commission_bps IS DISTINCT FROM OLD.commission_bps
       OR NEW.verified_by IS DISTINCT FROM OLD.verified_by
       OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
       OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
       OR NEW.type IS DISTINCT FROM OLD.type THEN
      RAISE EXCEPTION 'insufficient privilege to modify protected partner columns' USING ERRCODE = '42501';
    END IF;
    -- Only draft/rejected -> pending_verification transitions are partner-driven.
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NOT (OLD.status IN ('draft', 'rejected') AND NEW.status = 'pending_verification') THEN
      RAISE EXCEPTION 'partners cannot change verification status' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER partner_profiles_guard BEFORE UPDATE ON public.partner_profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_partner_privileged_columns();

CREATE OR REPLACE FUNCTION public.is_active_partner(p_partner UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.partner_profiles WHERE id = p_partner AND status = 'active');
$$;

-- Rider / driver specifics
CREATE TABLE public.rider_details (
  partner_id        UUID PRIMARY KEY REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  vehicle_type      public.vehicle_type NOT NULL,
  plate_number      TEXT NOT NULL,
  license_number    TEXT NOT NULL,
  license_expiry    DATE NOT NULL,
  bluebook_tax_valid_until DATE,
  is_online         BOOLEAN NOT NULL DEFAULT FALSE,
  cod_cash_in_hand_paisa BIGINT NOT NULL DEFAULT 0 CHECK (cod_cash_in_hand_paisa >= 0)
);
CREATE UNIQUE INDEX rider_details_plate_uniq ON public.rider_details (upper(plate_number));

-- ---------------------------------------------------------------------------
-- KYC documents (files live in the private `kyc` storage bucket)
-- ---------------------------------------------------------------------------
CREATE TABLE public.partner_kyc_documents (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id       UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  doc_type         public.kyc_doc_type NOT NULL,
  storage_path     TEXT NOT NULL,
  expires_on       DATE,
  status           public.kyc_doc_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  reviewed_by      UUID REFERENCES public.profiles(id),
  reviewed_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX kyc_docs_partner_idx ON public.partner_kyc_documents (partner_id);
CREATE INDEX kyc_docs_pending_idx ON public.partner_kyc_documents (status) WHERE status = 'pending';

CREATE OR REPLACE FUNCTION public.guard_kyc_review_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    IF NEW.status IS DISTINCT FROM OLD.status
       OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
       OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
       OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason THEN
      RAISE EXCEPTION 'only admins can review KYC documents' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER kyc_docs_guard BEFORE UPDATE ON public.partner_kyc_documents
  FOR EACH ROW EXECUTE FUNCTION public.guard_kyc_review_columns();

-- Bank accounts for midnight payouts (sensitive: owner + admin only)
CREATE TABLE public.partner_bank_accounts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id     UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  bank_code      TEXT NOT NULL,
  branch_code    TEXT,
  account_name   TEXT NOT NULL,
  account_number TEXT NOT NULL,
  is_verified    BOOLEAN NOT NULL DEFAULT FALSE,
  is_primary     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX partner_bank_one_primary ON public.partner_bank_accounts (partner_id) WHERE is_primary;

-- ---------------------------------------------------------------------------
-- Superadmin: audit log, device blacklist, ward kill-switches
-- ---------------------------------------------------------------------------
CREATE TABLE public.admin_audit_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id       UUID NOT NULL REFERENCES public.profiles(id),
  action_type    TEXT NOT NULL,           -- PARTNER_VERIFIED, USER_BANNED, DISPUTE_REFUNDED...
  target_entity  TEXT NOT NULL,           -- e.g. 'partner:<uuid>'
  previous_state JSONB,
  new_state      JSONB,
  reason         TEXT NOT NULL,
  ip_address     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX admin_audit_target_idx ON public.admin_audit_logs (target_entity, created_at DESC);

-- Append-only: nobody (not even admins) can rewrite history.
CREATE OR REPLACE FUNCTION public.reject_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% on % is not permitted (append-only table)', TG_OP, TG_TABLE_NAME
    USING ERRCODE = '42501';
END;
$$;
CREATE TRIGGER admin_audit_immutable BEFORE UPDATE OR DELETE ON public.admin_audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

CREATE TABLE public.banned_identifiers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        TEXT NOT NULL CHECK (kind IN ('phone', 'device')),
  value_hash  TEXT NOT NULL,              -- sha256 hex of normalized phone / device id
  reason      TEXT NOT NULL,
  banned_by   UUID NOT NULL REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (kind, value_hash)
);

-- Ward/palika-level service kill-switch (floods, strikes). NULL vertical = everything.
CREATE TABLE public.service_kill_switches (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local_level_id SMALLINT NOT NULL REFERENCES public.local_levels(id),
  ward_no        SMALLINT CHECK (ward_no BETWEEN 1 AND 35),   -- NULL = whole palika
  vertical       TEXT CHECK (vertical IN ('food', 'grocery', 'rides', 'stays', 'rooms')),
  reason         TEXT NOT NULL,
  enabled_by     UUID NOT NULL REFERENCES public.profiles(id),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  lifted_at      TIMESTAMPTZ
);
CREATE INDEX kill_switch_active_idx ON public.service_kill_switches (local_level_id) WHERE is_active;

CREATE OR REPLACE FUNCTION public.is_service_blocked(p_local_level SMALLINT, p_ward SMALLINT, p_vertical TEXT)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.service_kill_switches k
    WHERE k.is_active AND k.local_level_id = p_local_level
      AND (k.ward_no IS NULL OR k.ward_no = p_ward)
      AND (k.vertical IS NULL OR k.vertical = p_vertical)
  );
$$;

-- ---------------------------------------------------------------------------
-- Admin RPCs — the ONLY supported way to change protected state. Each writes
-- the audit log in the same transaction.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_review_partner(
  p_partner UUID, p_approve BOOLEAN, p_reason TEXT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old public.partner_profiles;
  v_new public.partner_profiles;
  v_pending_docs INT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'a reason is required';
  END IF;

  SELECT * INTO v_old FROM public.partner_profiles WHERE id = p_partner FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'partner not found'; END IF;

  IF p_approve THEN
    SELECT count(*) INTO v_pending_docs FROM public.partner_kyc_documents
      WHERE partner_id = p_partner AND status <> 'approved';
    IF v_pending_docs > 0 OR NOT EXISTS (SELECT 1 FROM public.partner_kyc_documents WHERE partner_id = p_partner) THEN
      RAISE EXCEPTION 'all KYC documents must be approved before activating a partner';
    END IF;
  END IF;

  UPDATE public.partner_profiles SET
    status = CASE WHEN p_approve THEN 'active'::public.partner_status ELSE 'rejected'::public.partner_status END,
    rejection_reason = CASE WHEN p_approve THEN NULL ELSE p_reason END,
    verified_by = auth.uid(),
    verified_at = now()
  WHERE id = p_partner
  RETURNING * INTO v_new;

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, previous_state, new_state, reason)
  VALUES (auth.uid(),
          CASE WHEN p_approve THEN 'PARTNER_VERIFIED' ELSE 'PARTNER_REJECTED' END,
          'partner:' || p_partner,
          jsonb_build_object('status', v_old.status),
          jsonb_build_object('status', v_new.status),
          p_reason);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_account_status(
  p_user UUID, p_status public.account_status, p_until TIMESTAMPTZ, p_reason TEXT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old public.profiles;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'a reason is required';
  END IF;
  IF p_user = auth.uid() THEN
    RAISE EXCEPTION 'admins cannot change their own account status';
  END IF;

  SELECT * INTO v_old FROM public.profiles WHERE id = p_user FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user not found'; END IF;

  UPDATE public.profiles
     SET status = p_status,
         suspended_until = CASE WHEN p_status = 'suspended' THEN p_until ELSE NULL END
   WHERE id = p_user;

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, previous_state, new_state, reason)
  VALUES (auth.uid(), 'ACCOUNT_' || upper(p_status::text), 'user:' || p_user,
          jsonb_build_object('status', v_old.status, 'suspended_until', v_old.suspended_until),
          jsonb_build_object('status', p_status, 'suspended_until', p_until),
          p_reason);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_cod_enabled(p_user UUID, p_enabled BOOLEAN, p_reason TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_old BOOLEAN;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  SELECT cod_enabled INTO v_old FROM public.profiles WHERE id = p_user FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user not found'; END IF;
  UPDATE public.profiles SET cod_enabled = p_enabled WHERE id = p_user;
  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, previous_state, new_state, reason)
  VALUES (auth.uid(), 'COD_' || CASE WHEN p_enabled THEN 'ENABLED' ELSE 'DISABLED' END, 'user:' || p_user,
          jsonb_build_object('cod_enabled', v_old), jsonb_build_object('cod_enabled', p_enabled), p_reason);
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_details          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_kyc_documents  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_bank_accounts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banned_identifiers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_kill_switches  ENABLE ROW LEVEL SECURITY;

-- profiles: owner reads/updates self; discoverable profiles are visible to
-- signed-in users (exposes only what the app selects); admins read all.
CREATE POLICY profiles_select ON public.profiles FOR SELECT
  USING (id = auth.uid() OR discoverable OR public.is_admin());
CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY addresses_owner ON public.user_addresses FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY addresses_admin_read ON public.user_addresses FOR SELECT USING (public.is_admin());

-- partner_profiles: public can see ACTIVE partners; members see their own; admins all.
CREATE POLICY partners_select ON public.partner_profiles FOR SELECT
  USING (status = 'active' OR public.is_partner_member(id) OR public.is_admin());
CREATE POLICY partners_insert ON public.partner_profiles FOR INSERT
  WITH CHECK (owner_id = auth.uid() AND status IN ('draft', 'pending_verification') AND public.is_account_active());
CREATE POLICY partners_update ON public.partner_profiles FOR UPDATE
  USING (public.is_partner_member(id, ARRAY['owner', 'manager']) OR public.is_admin())
  WITH CHECK (public.is_partner_member(id, ARRAY['owner', 'manager']) OR public.is_admin());

CREATE POLICY members_select ON public.partner_members FOR SELECT
  USING (user_id = auth.uid() OR public.is_partner_member(partner_id, ARRAY['owner', 'manager']) OR public.is_admin());
CREATE POLICY members_manage ON public.partner_members FOR ALL
  USING (public.is_partner_member(partner_id, ARRAY['owner']))
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner']));

CREATE POLICY rider_details_member ON public.rider_details FOR ALL
  USING (public.is_partner_member(partner_id) OR public.is_admin())
  WITH CHECK (public.is_partner_member(partner_id) OR public.is_admin());

CREATE POLICY kyc_select ON public.partner_kyc_documents FOR SELECT
  USING (public.is_partner_member(partner_id, ARRAY['owner']) OR public.is_admin());
CREATE POLICY kyc_insert ON public.partner_kyc_documents FOR INSERT
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner']) AND status = 'pending');
CREATE POLICY kyc_update ON public.partner_kyc_documents FOR UPDATE
  USING (public.is_partner_member(partner_id, ARRAY['owner']) OR public.is_admin())
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner']) OR public.is_admin());

CREATE POLICY bank_select ON public.partner_bank_accounts FOR SELECT
  USING (public.is_partner_member(partner_id, ARRAY['owner']) OR public.is_admin());
CREATE POLICY bank_insert ON public.partner_bank_accounts FOR INSERT
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner']) AND is_verified = FALSE);
CREATE POLICY bank_admin_update ON public.partner_bank_accounts FOR UPDATE
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY audit_admin_read ON public.admin_audit_logs FOR SELECT USING (public.is_admin());
-- (no INSERT policy: writes happen only inside SECURITY DEFINER admin RPCs)

CREATE POLICY banned_admin_all ON public.banned_identifiers FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin() AND banned_by = auth.uid());

CREATE POLICY kill_switch_read ON public.service_kill_switches FOR SELECT USING (true);
CREATE POLICY kill_switch_admin_write ON public.service_kill_switches FOR ALL
  USING (public.is_admin()) WITH CHECK (public.is_admin() AND enabled_by = auth.uid());
