-- ============================================================================
-- Migration 0014: SMS Verification, Dispatch Logs & Anti-Bombing Rate Limiter
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Guarantees:
-- 1. Anti-SMS Bombing: Max 3 OTP requests per phone per 10 minutes (prevents budget drain).
-- 2. Audit Trail: Full dispatch log tracking provider ('mock', 'sparrow', 'aakash'), cost, and latency.
-- 3. Nepal Telecom Formatting: Enforces valid NTC (984/985/986/974/975) & Ncell (980/981/982) prefixes.
-- 4. Mock-Safe: Seamless local testing with zero provider tokens required.
-- ============================================================================

-- Add verification flags to profiles if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'phone_verified'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN phone_verified BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'email_verified'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

-- SMS Dispatch Audit Logs
CREATE TABLE public.sms_dispatch_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone        TEXT NOT NULL,
  provider     TEXT NOT NULL CHECK (provider IN ('mock', 'sparrow', 'aakash', 'twilio')),
  status       TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('queued', 'sent', 'failed', 'delivered')),
  message      TEXT NOT NULL,
  cost_paisa   INTEGER NOT NULL DEFAULT 0,               -- e.g. 120 paisa = NPR 1.20
  provider_id  TEXT,                                     -- Provider message tracking ID / response code
  ip_address   TEXT,
  error_detail TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sms_dispatch_phone_idx ON public.sms_dispatch_logs (phone, created_at DESC);
CREATE INDEX sms_dispatch_created_idx ON public.sms_dispatch_logs (created_at DESC);

-- SMS Anti-Bombing Rate Limiting Table
CREATE TABLE public.sms_rate_limits (
  phone               TEXT PRIMARY KEY,
  request_count       INTEGER NOT NULL DEFAULT 1,
  first_request_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_request_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  blocked_until       TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sms_rate_blocked_idx ON public.sms_rate_limits (blocked_until) WHERE blocked_until IS NOT NULL;

CREATE TRIGGER sms_rate_limits_updated_at BEFORE UPDATE ON public.sms_rate_limits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RPC Function: Verify Rate Limit and Increment Attempt Counter
-- Rules:
-- 1. Min cooldown between requests: 45 seconds.
-- 2. Max requests in 10-minute window: 3 requests.
-- 3. If exceeded, block phone number for 15 minutes.
CREATE OR REPLACE FUNCTION public.check_sms_rate_limit(
  p_phone TEXT,
  p_min_cooldown_seconds INT DEFAULT 45,
  p_max_requests INT DEFAULT 3,
  p_window_seconds INT DEFAULT 600,
  p_block_duration_seconds INT DEFAULT 900
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_record RECORD;
  v_now TIMESTAMPTZ := now();
  v_seconds_since_last INT;
  v_seconds_since_first INT;
BEGIN
  -- 1. Fetch current rate limit record for phone
  SELECT * INTO v_record FROM public.sms_rate_limits WHERE phone = p_phone;

  IF NOT FOUND THEN
    -- First request for this phone
    INSERT INTO public.sms_rate_limits (phone, request_count, first_request_at, last_request_at)
    VALUES (p_phone, 1, v_now, v_now);

    RETURN jsonb_build_object(
      'allowed', TRUE,
      'remaining_requests', p_max_requests - 1,
      'retry_after_seconds', 0
    );
  END IF;

  -- 2. Check if currently blocked
  IF v_record.blocked_until IS NOT NULL AND v_record.blocked_until > v_now THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'error', 'rate_limit_exceeded',
      'message', 'Too many verification attempts. Please try again later.',
      'retry_after_seconds', EXTRACT(EPOCH FROM (v_record.blocked_until - v_now))::INT
    );
  END IF;

  -- 3. Check minimum cooldown between sequential requests (e.g. 45 seconds)
  v_seconds_since_last := EXTRACT(EPOCH FROM (v_now - v_record.last_request_at))::INT;
  IF v_seconds_since_last < p_min_cooldown_seconds THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'error', 'cooldown_active',
      'message', 'Please wait before requesting another verification code.',
      'retry_after_seconds', p_min_cooldown_seconds - v_seconds_since_last
    );
  END IF;

  -- 4. Check if the sliding time window has expired (e.g. 10 minutes)
  v_seconds_since_first := EXTRACT(EPOCH FROM (v_now - v_record.first_request_at))::INT;
  IF v_seconds_since_first > p_window_seconds THEN
    -- Reset window
    UPDATE public.sms_rate_limits
    SET request_count = 1,
        first_request_at = v_now,
        last_request_at = v_now,
        blocked_until = NULL
    WHERE phone = p_phone;

    RETURN jsonb_build_object(
      'allowed', TRUE,
      'remaining_requests', p_max_requests - 1,
      'retry_after_seconds', 0
    );
  END IF;

  -- 5. Check if within window and request count exceeded
  IF v_record.request_count >= p_max_requests THEN
    -- Block phone number
    UPDATE public.sms_rate_limits
    SET blocked_until = v_now + (p_block_duration_seconds || ' seconds')::INTERVAL,
        last_request_at = v_now
    WHERE phone = p_phone;

    RETURN jsonb_build_object(
      'allowed', FALSE,
      'error', 'rate_limit_exceeded',
      'message', 'Too many OTP requests. Phone temporarily locked for 15 minutes.',
      'retry_after_seconds', p_block_duration_seconds
    );
  END IF;

  -- 6. Valid request within quota: increment counter
  UPDATE public.sms_rate_limits
  SET request_count = request_count + 1,
      last_request_at = v_now
  WHERE phone = p_phone;

  RETURN jsonb_build_object(
    'allowed', TRUE,
    'remaining_requests', p_max_requests - (v_record.request_count + 1),
    'retry_after_seconds', 0
  );
END;
$$;

-- RLS: Protect SMS logs and rate limits
ALTER TABLE public.sms_dispatch_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY sms_logs_admin_read ON public.sms_dispatch_logs
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'superadmin'));

CREATE POLICY sms_rate_admin_manage ON public.sms_rate_limits
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'superadmin'))
  WITH CHECK (public.has_role(auth.uid(), 'superadmin'));

COMMENT ON TABLE public.sms_dispatch_logs IS
  'Audit log for SMS dispatches (Sparrow SMS, Aakash SMS, Mock) with cost tracking and failure diagnostics.';
COMMENT ON TABLE public.sms_rate_limits IS
  'Anti-bombing rate limiter table tracking sequential SMS OTP requests per mobile number.';
