-- ============================================================================
-- Migration 0020: Automated Maintenance, Midnight Settlement & pg_cron Schedules
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Automates:
-- 1. Midnight Bank Settlement: Disburses daily merchant net earnings to ConnectIPS bank accounts at 00:00 NPT.
-- 2. Stale Ride Bids Expiration: Closes unaccepted InDrive ride bids older than 10 minutes (runs every 2 mins).
-- 3. Expire Unpaid Holds: Releases reservation hold locks after 15 minutes of inactivity (runs every 5 mins).
-- 4. Ephemeral Media Cleanup: Purges expired snaps (24h) and viewed ephemeral messages (runs hourly).
-- 5. Rate Limit Maintenance: Prunes expired anti-bombing blocks older than 24 hours (runs daily).
-- ============================================================================

-- Maintenance Function 1: Expire Stale Ride Bids
CREATE OR REPLACE FUNCTION public.expire_stale_ride_bids()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_updated_count INT;
BEGIN
  -- Mark bids submitted > 10 minutes ago that are still pending as 'expired'
  UPDATE public.ride_bids
  SET status = 'expired',
      updated_at = now()
  WHERE status = 'pending'
    AND created_at < (now() - INTERVAL '10 minutes');

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  RETURN v_updated_count;
END;
$$;

-- Maintenance Function 2: Prune Expired Anti-Bombing Rate Limits
CREATE OR REPLACE FUNCTION public.cleanup_expired_rate_limits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_deleted_count INT;
BEGIN
  -- Delete rate limit tracking rows older than 24 hours where lockout has expired
  DELETE FROM public.sms_rate_limits
  WHERE (blocked_until IS NULL OR blocked_until < now())
    AND updated_at < (now() - INTERVAL '24 hours');

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$;

-- Register Automated pg_cron Schedules (Runs when pg_cron extension is active)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule any previously registered jobs with same names to prevent duplicates
    PERFORM cron.unschedule('midnight_merchant_settlement') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'midnight_merchant_settlement');
    PERFORM cron.unschedule('expire_stale_ride_bids') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_stale_ride_bids');
    PERFORM cron.unschedule('expire_unpaid_holds') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_unpaid_holds');
    PERFORM cron.unschedule('purge_expired_ephemera') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge_expired_ephemera');
    PERFORM cron.unschedule('cleanup_expired_rate_limits') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_expired_rate_limits');

    -- 1. Midnight Settlement: Daily at 00:00 (Nepal Time ~ UTC 18:15)
    PERFORM cron.schedule(
      'midnight_merchant_settlement',
      '15 18 * * *',
      'SELECT public.settle_daily_merchant_balances();'
    );

    -- 2. Expire Stale InDrive Bids: Every 2 minutes
    PERFORM cron.schedule(
      'expire_stale_ride_bids',
      '*/2 * * * *',
      'SELECT public.expire_stale_ride_bids();'
    );

    -- 3. Expire Unpaid Reservation Holds: Every 5 minutes
    PERFORM cron.schedule(
      'expire_unpaid_holds',
      '*/5 * * * *',
      'SELECT public.expire_unpaid_holds();'
    );

    -- 4. Purge Expired Ephemera (Snaps & Stories): Hourly
    PERFORM cron.schedule(
      'purge_expired_ephemera',
      '0 * * * *',
      'SELECT public.purge_expired_ephemera();'
    );

    -- 5. Cleanup Expired Rate Limits: Daily at 03:00 NPT (UTC 21:15)
    PERFORM cron.schedule(
      'cleanup_expired_rate_limits',
      '15 21 * * *',
      'SELECT public.cleanup_expired_rate_limits();'
    );

    RAISE NOTICE 'pg_cron automated maintenance schedules successfully configured.';
  ELSE
    RAISE NOTICE 'pg_cron extension not active in current environment. Maintenance functions compiled and ready for hosted schedule.';
  END IF;
END $$;

COMMENT ON FUNCTION public.expire_stale_ride_bids IS
  'Automated cron maintenance function expiring unaccepted InDrive ride bids older than 10 minutes.';
COMMENT ON FUNCTION public.cleanup_expired_rate_limits IS
  'Automated cron maintenance function pruning stale SMS and WhatsApp rate limit entries older than 24 hours.';
