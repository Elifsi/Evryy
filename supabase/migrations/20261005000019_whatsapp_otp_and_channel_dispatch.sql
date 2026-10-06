-- ============================================================================
-- Migration 0019: WhatsApp Cloud API OTP Verification, Multi-Channel Fallback & Audit Trail
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Guarantees:
-- 1. WhatsApp Cloud API First: Primary OTP verification channel via Meta WhatsApp Business API.
-- 2. Multi-Channel Support: Tracks both 'whatsapp' and 'sms' channels with provider attribution.
-- 3. Automatic Failover: Seamless fallback from WhatsApp to Sparrow/Aakash domestic SMS.
-- 4. Unified Anti-Bombing Rate Limiter: Shared 45s cooldown, 3 requests / 10 mins window across channels.
-- 5. Mock-Safe: Zero cost in local development; prints WhatsApp OTP directly to console.
-- ============================================================================

-- 1. Extend sms_dispatch_logs to support channel ('whatsapp', 'sms') and provider 'whatsapp_cloud'
ALTER TABLE public.sms_dispatch_logs
  DROP CONSTRAINT IF EXISTS sms_dispatch_logs_provider_check;

ALTER TABLE public.sms_dispatch_logs
  ADD CONSTRAINT sms_dispatch_logs_provider_check 
  CHECK (provider IN ('mock', 'sparrow', 'aakash', 'twilio', 'whatsapp_cloud', 'infobip'));

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'sms_dispatch_logs' AND column_name = 'channel'
  ) THEN
    ALTER TABLE public.sms_dispatch_logs ADD COLUMN channel TEXT NOT NULL DEFAULT 'sms' CHECK (channel IN ('sms', 'whatsapp'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'sms_dispatch_logs' AND column_name = 'template_name'
  ) THEN
    ALTER TABLE public.sms_dispatch_logs ADD COLUMN template_name TEXT;
  END IF;
END $$;

-- Create index on channel
CREATE INDEX IF NOT EXISTS sms_dispatch_channel_idx ON public.sms_dispatch_logs (channel, created_at DESC);

-- 2. Create view for otp_dispatch_logs for modern unified multi-channel reporting
CREATE OR REPLACE VIEW public.otp_dispatch_logs AS
  SELECT 
    id,
    phone,
    channel,
    provider,
    status,
    message,
    template_name,
    cost_paisa,
    provider_id,
    ip_address,
    error_detail,
    created_at
  FROM public.sms_dispatch_logs;

-- 3. Unified Rate Limiting Function for OTP (WhatsApp & SMS)
CREATE OR REPLACE FUNCTION public.check_otp_rate_limit(
  p_phone TEXT,
  p_channel TEXT DEFAULT 'whatsapp',
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
BEGIN
  -- Reuses the anti-bombing rate limiter across all OTP dispatch channels
  RETURN public.check_sms_rate_limit(
    p_phone,
    p_min_cooldown_seconds,
    p_max_requests,
    p_window_seconds,
    p_block_duration_seconds
  );
END;
$$;

COMMENT ON VIEW public.otp_dispatch_logs IS
  'Unified audit view tracking both WhatsApp Cloud API and domestic SMS OTP dispatches.';
COMMENT ON FUNCTION public.check_otp_rate_limit IS
  'Anti-bombing rate limiter checking sequential OTP requests across WhatsApp and SMS channels.';
