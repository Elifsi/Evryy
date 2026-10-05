-- =============================================================================
-- 0010 — Function privileges & Storage buckets
--
-- Supabase grants EXECUTE on every new public function to anon + authenticated
-- by default. That is unsafe for SECURITY DEFINER code, so we lock everything
-- down and re-grant only what each role legitimately needs.
-- =============================================================================

DO $$
DECLARE
  v_helpers TEXT[] := ARRAY[
    -- helpers invoked from RLS policies (evaluated with the caller's privileges)
    'is_admin()', 'is_account_active(uuid)', 'is_partner_member(uuid,text[])', 'is_active_partner(uuid)',
    'is_service_blocked(smallint,smallint,text)', 'is_chat_member(uuid)', 'are_connected(uuid,uuid)'
  ];
  v_h TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
    FOREACH v_h IN ARRAY v_helpers LOOP
      EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO anon', v_h);
    END LOOP;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    -- Service-role-only: payment confirmation, refunds, payouts, cron targets, ledger writer.
    REVOKE EXECUTE ON FUNCTION public.confirm_payment(TEXT, UUID, public.payment_method, TEXT, TEXT, BIGINT, JSONB) FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.record_payment_refund(UUID, BIGINT, TEXT) FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.mark_payout_paid(UUID, TEXT) FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.expire_unpaid_holds() FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.purge_old_ai_chats() FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.purge_expired_ephemera() FROM authenticated;
    REVOKE EXECUTE ON FUNCTION public.post_ledger_group(TEXT, UUID, TEXT, JSONB) FROM authenticated;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Storage buckets (skipped on plain Postgres where the storage schema is absent)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NULL THEN
    RAISE NOTICE 'storage schema not present: skipping bucket creation';
    RETURN;
  END IF;

  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
    ('kyc',        'kyc',        false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('catalog',    'catalog',    true,  5242880,  ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('avatars',    'avatars',    true,  2097152,  ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('snaps',      'snaps',      false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'video/mp4']),
    ('stories',    'stories',    false, 20971520, ARRAY['image/jpeg', 'image/png', 'image/webp', 'video/mp4']),
    ('chat-media', 'chat-media', false, 20971520, NULL)
  ON CONFLICT (id) DO NOTHING;

  -- Path convention: <owner-uuid>/<file>. The first folder is the owner id
  -- (partner id for kyc/catalog, user id otherwise).

  -- KYC: partner owners upload & read their own documents; admins read all. Never public.
  EXECUTE $p$CREATE POLICY kyc_owner_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kyc' AND public.is_partner_member(((storage.foldername(name))[1])::uuid, ARRAY['owner']))$p$;
  EXECUTE $p$CREATE POLICY kyc_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'kyc' AND (public.is_admin() OR public.is_partner_member(((storage.foldername(name))[1])::uuid, ARRAY['owner'])))$p$;

  -- Catalog images: world-readable, written by that partner's owners/managers.
  EXECUTE $p$CREATE POLICY catalog_read ON storage.objects FOR SELECT USING (bucket_id = 'catalog')$p$;
  EXECUTE $p$CREATE POLICY catalog_write ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'catalog' AND public.is_partner_member(((storage.foldername(name))[1])::uuid, ARRAY['owner', 'manager']))$p$;
  EXECUTE $p$CREATE POLICY catalog_update ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'catalog' AND public.is_partner_member(((storage.foldername(name))[1])::uuid, ARRAY['owner', 'manager']))$p$;
  EXECUTE $p$CREATE POLICY catalog_delete ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'catalog' AND public.is_partner_member(((storage.foldername(name))[1])::uuid, ARRAY['owner', 'manager']))$p$;

  -- Avatars: public read, own folder write.
  EXECUTE $p$CREATE POLICY avatars_read ON storage.objects FOR SELECT USING (bucket_id = 'avatars')$p$;
  EXECUTE $p$CREATE POLICY avatars_write ON storage.objects FOR ALL TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)$p$;

  -- Snaps: sender uploads into own folder. Reading goes through open_and_burn_snap()
  -- + a service-role signed URL (so a burned snap can never be re-downloaded).
  EXECUTE $p$CREATE POLICY snaps_upload ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'snaps' AND (storage.foldername(name))[1] = auth.uid()::text)$p$;

  -- Stories: author writes; readers must be able to see the story row (RLS-inherited).
  EXECUTE $p$CREATE POLICY stories_upload ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'stories' AND (storage.foldername(name))[1] = auth.uid()::text)$p$;
  EXECUTE $p$CREATE POLICY stories_read ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'stories' AND EXISTS (SELECT 1 FROM public.stories s WHERE s.storage_path = name))$p$;

  -- Chat media: members of the chat named by the first folder.
  EXECUTE $p$CREATE POLICY chat_media_rw ON storage.objects FOR ALL TO authenticated
    USING (bucket_id = 'chat-media' AND public.is_chat_member(((storage.foldername(name))[1])::uuid))
    WITH CHECK (bucket_id = 'chat-media' AND public.is_chat_member(((storage.foldername(name))[1])::uuid))$p$;
END $$;
