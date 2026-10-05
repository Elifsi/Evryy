-- =============================================================================
-- 0012 — Operational Enhancements: VAT Configuration, Zero-Hub COD Digital
--        Settlement, Vehicle Visuals, Reviews & Ratings, Grocery Packaging
-- evrry Super App · Elifsi Technologies Private Limited
-- Forward-only. Do not edit after applying to a shared environment.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. VAT Configuration (Default: 0% until IRD VAT registration)
-- ---------------------------------------------------------------------------
-- Elifsi is currently pre-VAT registration. When the business surpasses the
-- Inland Revenue Department (IRD) turnover threshold (NPR 50L goods / 20L services),
-- superadmins simply update `value_int = 1300` in public.platform_settings.
UPDATE public.platform_settings
   SET value_int = 0,
       description = 'VAT in basis points (currently 0% as Elifsi is not yet VAT-registered; set to 1300 for 13% upon IRD registration)'
 WHERE key = 'vat_bps';

-- Soft limit for cash held by riders (NPR 5,000 = 500,000 paisa).
-- Above this threshold, riders are prompted to clear cash digitally via eSewa/Khalti.
INSERT INTO public.platform_settings (key, value_int, description) VALUES
  ('rider_cod_limit_paisa', 500000, 'Soft limit on cash in hand (in paisa); above this, new COD dispatches pause until digital settlement')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Vehicle Visual Details for Rides & Food Deliveries
-- ---------------------------------------------------------------------------
-- Displays recognizable model and color to passengers & customers (e.g. 'Red Pulsar 150').
ALTER TABLE public.rider_details
  ADD COLUMN IF NOT EXISTS vehicle_model TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_color TEXT,
  ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(3,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count INTEGER NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- 3. Catalog Grocery Packaging & Restaurant Customizations
-- ---------------------------------------------------------------------------
-- packaging_unit: e.g. '1 kg', '500 ml', '1 packet', '1 dozen'
-- options: e.g. [{"title":"Spicy Level","choices":["Mild","Medium","Hot"]}]
ALTER TABLE public.catalog_items
  ADD COLUMN IF NOT EXISTS packaging_unit TEXT,
  ADD COLUMN IF NOT EXISTS options JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS packaging_unit TEXT,
  ADD COLUMN IF NOT EXISTS selected_options JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS item_note TEXT;

-- ---------------------------------------------------------------------------
-- 4. Unified Customer Reviews & Star Ratings Subsystem
-- ---------------------------------------------------------------------------
CREATE TABLE public.reviews (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_type      TEXT NOT NULL CHECK (target_type IN ('store', 'rider', 'driver', 'property')),
  target_id        UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  order_id         UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  ride_id          UUID REFERENCES public.rides(id) ON DELETE SET NULL,
  reservation_id   UUID REFERENCES public.room_reservations(id) ON DELETE SET NULL,
  rating           SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment          TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT reviews_one_reference CHECK (
    (order_id IS NOT NULL)::int + (ride_id IS NOT NULL)::int + (reservation_id IS NOT NULL)::int = 1
  ),
  CONSTRAINT reviews_unique_order UNIQUE (user_id, order_id),
  CONSTRAINT reviews_unique_ride UNIQUE (user_id, ride_id),
  CONSTRAINT reviews_unique_reservation UNIQUE (user_id, reservation_id)
);
CREATE INDEX reviews_target_idx ON public.reviews (target_type, target_id, created_at DESC);
CREATE INDEX reviews_user_idx   ON public.reviews (user_id);

-- Submit a verified review and automatically recompute target average & count.
CREATE OR REPLACE FUNCTION public.submit_review(
  p_target_type TEXT,
  p_target_id UUID,
  p_rating SMALLINT,
  p_comment TEXT DEFAULT NULL,
  p_order_id UUID DEFAULT NULL,
  p_ride_id UUID DEFAULT NULL,
  p_reservation_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_store_id UUID;
  v_partner_id UUID;
  v_rev_id UUID;
  v_cur_avg NUMERIC(3,2);
  v_cur_count INT;
  v_new_avg NUMERIC(3,2);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF p_rating NOT BETWEEN 1 AND 5 THEN RAISE EXCEPTION 'rating must be between 1 and 5'; END IF;

  -- 1. Validate that the user actually completed this transaction
  IF p_order_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id = p_order_id AND consumer_id = v_uid AND status = 'delivered') THEN
      RAISE EXCEPTION 'cannot review an order that was not completed by you';
    END IF;
  ELSIF p_ride_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.rides WHERE id = p_ride_id AND passenger_id = v_uid AND status = 'completed') THEN
      RAISE EXCEPTION 'cannot review a ride that was not completed by you';
    END IF;
  ELSIF p_reservation_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.room_reservations WHERE id = p_reservation_id AND guest_id = v_uid AND status = 'completed') THEN
      RAISE EXCEPTION 'cannot review a reservation that was not completed by you';
    END IF;
  ELSE
    RAISE EXCEPTION 'a valid order_id, ride_id, or reservation_id is required';
  END IF;

  -- 2. Insert the review record
  INSERT INTO public.reviews (
    user_id, target_type, target_id, order_id, ride_id, reservation_id, rating, comment
  ) VALUES (
    v_uid, p_target_type, p_target_id, p_order_id, p_ride_id, p_reservation_id, p_rating, p_comment
  ) RETURNING id INTO v_rev_id;

  -- 3. Incrementally update the aggregate ratings on the target entity
  IF p_target_type = 'store' THEN
    SELECT s.rating_avg, s.rating_count INTO v_cur_avg, v_cur_count
      FROM public.stores s WHERE s.partner_id = p_target_id LIMIT 1 FOR UPDATE;
    IF FOUND THEN
      v_new_avg := round(((v_cur_avg * v_cur_count + p_rating)::numeric / (v_cur_count + 1)), 2);
      UPDATE public.stores
         SET rating_avg = v_new_avg, rating_count = v_cur_count + 1
       WHERE partner_id = p_target_id;
    END IF;
  ELSIF p_target_type = 'property' THEN
    SELECT p.rating_avg, p.rating_count INTO v_cur_avg, v_cur_count
      FROM public.properties p WHERE p.partner_id = p_target_id LIMIT 1 FOR UPDATE;
    IF FOUND THEN
      v_new_avg := round(((v_cur_avg * v_cur_count + p_rating)::numeric / (v_cur_count + 1)), 2);
      UPDATE public.properties
         SET rating_avg = v_new_avg, rating_count = v_cur_count + 1
       WHERE partner_id = p_target_id;
    END IF;
  ELSIF p_target_type IN ('rider', 'driver') THEN
    SELECT rd.rating_avg, rd.rating_count INTO v_cur_avg, v_cur_count
      FROM public.rider_details rd WHERE rd.partner_id = p_target_id FOR UPDATE;
    IF FOUND THEN
      v_new_avg := round(((v_cur_avg * v_cur_count + p_rating)::numeric / (v_cur_count + 1)), 2);
      UPDATE public.rider_details
         SET rating_avg = v_new_avg, rating_count = v_cur_count + 1
       WHERE partner_id = p_target_id;
    END IF;
  END IF;

  RETURN v_rev_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Zero-Hub Digital COD Cash Settlement & Admin Reconciliation RPCs
-- ---------------------------------------------------------------------------

-- In-App Digital Settlement (Called by payment gateway webhook when rider pays via eSewa/Khalti/QR)
CREATE OR REPLACE FUNCTION public.settle_rider_cod_digital(
  p_rider_partner UUID,
  p_amount_paisa BIGINT,
  p_provider TEXT,
  p_provider_txn_ref TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lines JSONB;
  v_grp UUID;
  v_cash BIGINT;
BEGIN
  IF p_amount_paisa <= 0 THEN RAISE EXCEPTION 'amount must be positive'; END IF;
  SELECT cod_cash_in_hand_paisa INTO v_cash FROM public.rider_details WHERE partner_id = p_rider_partner FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'rider not found'; END IF;

  -- Post balanced double-entry ledger group:
  -- Debits: gateway_clearing (eSewa / Khalti holds this cash owed to Elifsi)
  -- Credits: rider_cash_in_hand (extinguishes the rider's cash liability)
  v_lines := jsonb_build_array(
    jsonb_build_object('account_type', 'gateway_clearing',  'direction', 'debit',  'amount', p_amount_paisa),
    jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', p_rider_partner, 'direction', 'credit', 'amount', p_amount_paisa)
  );

  v_grp := public.post_ledger_group('cod_digital_settlement', p_rider_partner,
    'rider COD digital settlement: ' || p_provider || ' ' || p_provider_txn_ref, v_lines);

  UPDATE public.rider_details
     SET cod_cash_in_hand_paisa = GREATEST(0, cod_cash_in_hand_paisa - p_amount_paisa)
   WHERE partner_id = p_rider_partner;

  RETURN v_grp;
END;
$$;

-- Admin Manual Reconciliation (Used when a rider deposits cash at a bank or office)
CREATE OR REPLACE FUNCTION public.admin_reconcile_rider_cash(
  p_rider_partner UUID,
  p_amount_paisa BIGINT,
  p_bank_ref TEXT,
  p_reason TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lines JSONB;
  v_grp UUID;
  v_old_cash BIGINT;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only' USING ERRCODE = '42501'; END IF;
  IF p_amount_paisa <= 0 THEN RAISE EXCEPTION 'amount must be positive'; END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN RAISE EXCEPTION 'a reason is required'; END IF;

  SELECT cod_cash_in_hand_paisa INTO v_old_cash FROM public.rider_details WHERE partner_id = p_rider_partner FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'rider not found'; END IF;

  -- Post balanced double-entry ledger group:
  -- Debits: bank_clearing (cash deposited in company bank account)
  -- Credits: rider_cash_in_hand (extinguishes the rider's cash liability)
  v_lines := jsonb_build_array(
    jsonb_build_object('account_type', 'bank_clearing',     'direction', 'debit',  'amount', p_amount_paisa),
    jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', p_rider_partner, 'direction', 'credit', 'amount', p_amount_paisa)
  );

  v_grp := public.post_ledger_group('cod_manual_reconciliation', p_rider_partner,
    'admin rider COD cash reconciliation: ' || p_bank_ref, v_lines);

  UPDATE public.rider_details
     SET cod_cash_in_hand_paisa = GREATEST(0, cod_cash_in_hand_paisa - p_amount_paisa)
   WHERE partner_id = p_rider_partner;

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, previous_state, new_state, reason)
  VALUES (
    auth.uid(),
    'RIDER_COD_RECONCILED',
    'partner:' || p_rider_partner,
    jsonb_build_object('cod_cash_in_hand_paisa', v_old_cash),
    jsonb_build_object('cod_cash_in_hand_paisa', GREATEST(0, v_old_cash - p_amount_paisa), 'reconciled_paisa', p_amount_paisa, 'ref', p_bank_ref),
    p_reason
  );

  RETURN v_grp;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Social Chat Message Delivery Receipts
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_messages_delivered(p_chat UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_chat_member(p_chat) THEN RAISE EXCEPTION 'not a member' USING ERRCODE = '42501'; END IF;
  UPDATE public.messages SET status = 'delivered'
   WHERE chat_id = p_chat AND sender_id <> auth.uid() AND status = 'sent';
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. Privileges & RLS Policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY reviews_select ON public.reviews FOR SELECT USING (true);
CREATE POLICY reviews_insert ON public.reviews FOR INSERT
  WITH CHECK (user_id = auth.uid() AND public.is_account_active());

REVOKE ALL ON FUNCTION public.settle_rider_cod_digital(UUID, BIGINT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_reconcile_rider_cash(UUID, BIGINT, TEXT, TEXT) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.settle_rider_cod_digital(UUID, BIGINT, TEXT, TEXT) TO service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.submit_review(TEXT, UUID, SMALLINT, TEXT, UUID, UUID, UUID) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.mark_messages_delivered(UUID) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.admin_reconcile_rider_cash(UUID, BIGINT, TEXT, TEXT) TO authenticated;
  END IF;
END $$;
