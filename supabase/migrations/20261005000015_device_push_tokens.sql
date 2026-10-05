-- ============================================================================
-- Migration 0015: Device Push Tokens & Realtime Notification Dispatch
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Guarantees:
-- 1. Multi-Device Registration: Supports Android (FCM), iOS (APNs), and Web Push.
-- 2. Multi-App Variant Isolation: Separates 'consumer', 'partner', and 'admin' tokens.
-- 3. Dynamic Token Recycling: Automatically rebinds tokens on device re-login.
-- ============================================================================

CREATE TABLE public.user_device_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  partner_id   UUID REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  platform     TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  token        TEXT NOT NULL UNIQUE,
  device_model TEXT,
  app_variant  TEXT NOT NULL CHECK (app_variant IN ('consumer', 'partner', 'admin')),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX user_device_tokens_user_idx    ON public.user_device_tokens (user_id) WHERE is_active = TRUE;
CREATE INDEX user_device_tokens_partner_idx ON public.user_device_tokens (partner_id) WHERE is_active = TRUE;
CREATE INDEX user_device_tokens_token_idx   ON public.user_device_tokens (token);

CREATE TRIGGER user_device_tokens_updated_at BEFORE UPDATE ON public.user_device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS: Users can only manage their own device tokens; admins can view all
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_tokens_user_read ON public.user_device_tokens
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY device_tokens_user_manage ON public.user_device_tokens
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- RPC: Register or update device push token
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_token TEXT,
  p_platform TEXT,
  p_app_variant TEXT,
  p_device_model TEXT DEFAULT NULL,
  p_partner_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.user_device_tokens (
    user_id,
    partner_id,
    platform,
    token,
    device_model,
    app_variant,
    is_active,
    last_seen_at
  )
  VALUES (
    auth.uid(),
    p_partner_id,
    p_platform,
    p_token,
    p_device_model,
    p_app_variant,
    TRUE,
    now()
  )
  ON CONFLICT (token) DO UPDATE
  SET user_id = auth.uid(),
      partner_id = EXCLUDED.partner_id,
      platform = EXCLUDED.platform,
      device_model = COALESCE(EXCLUDED.device_model, public.user_device_tokens.device_model),
      app_variant = EXCLUDED.app_variant,
      is_active = TRUE,
      last_seen_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- RPC: Unregister / deactivate token on logout
CREATE OR REPLACE FUNCTION public.unregister_device_token(p_token TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  UPDATE public.user_device_tokens
  SET is_active = FALSE
  WHERE token = p_token AND user_id = auth.uid();
END;
$$;

COMMENT ON TABLE public.user_device_tokens IS
  'Device push notification tokens (FCM/APNs) for Android, iOS, and Web clients.';
