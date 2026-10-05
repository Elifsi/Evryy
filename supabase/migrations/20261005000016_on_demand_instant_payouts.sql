-- ============================================================================
-- Migration 0016: On-Demand Instant Payouts & Multi-Rail Disbursements
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Features:
-- 1. On-Demand Cash Out: Partners can withdraw earnings 24/7 (ConnectIPS or eSewa/Khalti).
-- 2. Zero-Hub COD Lock: Formula Withdrawable = MAX(0, Payable - Rider Cash-in-Hand).
-- 3. Instant Convenience Fee: Configurable platform fee (default NPR 15) posted to platform_revenue.
-- 4. Rate Limiting: Max 2 instant withdrawals per 24 hours (anti-theft safety cap).
-- ============================================================================

-- Alter public.payouts to support on-demand single disbursements
ALTER TABLE public.payouts ALTER COLUMN batch_id DROP NOT NULL;
ALTER TABLE public.payouts ALTER COLUMN bank_account_id DROP NOT NULL;

ALTER TABLE public.payouts ADD COLUMN IF NOT EXISTS payout_type TEXT NOT NULL DEFAULT 'scheduled_batch' 
  CHECK (payout_type IN ('scheduled_batch', 'on_demand'));

ALTER TABLE public.payouts ADD COLUMN IF NOT EXISTS destination_type TEXT NOT NULL DEFAULT 'bank' 
  CHECK (destination_type IN ('bank', 'esewa', 'khalti'));

ALTER TABLE public.payouts ADD COLUMN IF NOT EXISTS destination_wallet TEXT; -- Phone number if eSewa/Khalti

ALTER TABLE public.payouts ADD COLUMN IF NOT EXISTS instant_fee_paisa BIGINT NOT NULL DEFAULT 0 
  CHECK (instant_fee_paisa >= 0);

-- Update mark_payout_paid to support both scheduled batches AND on-demand instant payouts
CREATE OR REPLACE FUNCTION public.mark_payout_paid(p_payout UUID, p_provider_ref TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE 
  v_p public.payouts; 
  v_status TEXT; 
  v_lines JSONB;
BEGIN
  SELECT * INTO v_p FROM public.payouts WHERE id = p_payout FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payout not found'; END IF;
  IF v_p.status = 'paid' THEN RETURN; END IF;

  -- If this is a scheduled batch payout, verify batch is approved
  IF v_p.batch_id IS NOT NULL THEN
    SELECT status INTO v_status FROM public.settlement_batches WHERE id = v_p.batch_id;
    IF v_status NOT IN ('approved', 'executing') THEN RAISE EXCEPTION 'batch is not approved'; END IF;
  END IF;

  -- Build balanced double-entry ledger lines
  -- 1. Debit Partner Payable (settling what platform owes)
  -- 2. Credit Bank Clearing (cash leaving via ConnectIPS or wallet)
  -- 3. Credit Rider Cash-in-Hand (if COD offset was applied)
  -- 4. Credit Platform Revenue (if instant convenience fee was charged)
  v_lines := jsonb_build_array(
    jsonb_build_object(
      'account_type', v_p.payable_account, 
      'account_id', v_p.partner_id, 
      'direction', 'debit', 
      'amount', v_p.payable_paisa
    ),
    jsonb_build_object(
      'account_type', 'bank_clearing', 
      'direction', 'credit', 
      'amount', v_p.net_paisa
    ),
    jsonb_build_object(
      'account_type', 'rider_cash_in_hand', 
      'account_id', CASE WHEN v_p.cod_offset_paisa > 0 THEN v_p.partner_id END,
      'direction', 'credit', 
      'amount', v_p.cod_offset_paisa
    ),
    jsonb_build_object(
      'account_type', 'platform_revenue',
      'direction', 'credit',
      'amount', v_p.instant_fee_paisa
    )
  );

  PERFORM public.post_ledger_group('payout', p_payout, 'payout ' || p_provider_ref, v_lines);

  IF v_p.cod_offset_paisa > 0 THEN
    UPDATE public.rider_details 
    SET cod_cash_in_hand_paisa = GREATEST(cod_cash_in_hand_paisa - v_p.cod_offset_paisa, 0)
    WHERE partner_id = v_p.partner_id;
  END IF;

  UPDATE public.payouts 
  SET status = 'paid', provider_ref = p_provider_ref, paid_at = now() 
  WHERE id = p_payout;

  -- If tied to a batch, check if batch is completed
  IF v_p.batch_id IS NOT NULL THEN
    UPDATE public.settlement_batches SET status = 'completed'
    WHERE id = v_p.batch_id 
      AND NOT EXISTS (SELECT 1 FROM public.payouts WHERE batch_id = v_p.batch_id AND status <> 'paid');
  END IF;
END;
$$;

-- Partner RPC: Request On-Demand Instant Payout
-- Checks:
-- 1. Owner authorization
-- 2. Minimum withdrawable: NPR 200 (20,000 paisa)
-- 3. Anti-theft cap: Max 2 instant withdrawals in rolling 24 hours
-- 4. Zero-Hub COD Lock: Net withdrawable = credit_balance - rider_cash_in_hand
-- 5. Deducts instant convenience fee (e.g. NPR 15 / 1,500 paisa)
CREATE OR REPLACE FUNCTION public.request_on_demand_payout(
  p_partner_id UUID,
  p_amount_paisa BIGINT,
  p_destination_type TEXT DEFAULT 'bank',
  p_wallet_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_account_type TEXT;
  v_credit_balance BIGINT := 0;
  v_cash_in_hand BIGINT := 0;
  v_withdrawable BIGINT := 0;
  v_recent_payouts INT := 0;
  v_bank_id UUID := NULL;
  v_fee_paisa BIGINT := 1500; -- NPR 15 flat convenience fee
  v_net_paisa BIGINT := 0;
  v_payout_id UUID;
BEGIN
  -- 1. Authorization: caller must be owner of the partner profile
  IF NOT public.is_partner_member(p_partner_id, ARRAY['owner']) THEN
    RAISE EXCEPTION 'Only the verified partner owner can request payouts' USING ERRCODE = '42501';
  END IF;

  -- 2. Minimum withdrawal check (NPR 200 / 20,000 paisa)
  IF p_amount_paisa < 20000 THEN
    RAISE EXCEPTION 'Minimum on-demand withdrawal is NPR 200.00' USING ERRCODE = '22000';
  END IF;

  -- 3. Rate limiting: Max 2 on-demand withdrawals per 24 hours
  SELECT COUNT(*) INTO v_recent_payouts
  FROM public.payouts
  WHERE partner_id = p_partner_id
    AND payout_type = 'on_demand'
    AND created_at > now() - interval '24 hours'
    AND status IN ('pending', 'paid');

  IF v_recent_payouts >= 2 THEN
    RAISE EXCEPTION 'Daily on-demand withdrawal limit reached (maximum 2 per 24 hours). Next automated settlement runs at midnight.'
      USING ERRCODE = '22000';
  END IF;

  -- 4. Determine payable account type based on partner profile
  SELECT
    CASE 
      WHEN type IN ('restaurant', 'store') THEN 'merchant_payable'
      WHEN type IN ('rider', 'driver') THEN 'rider_payable'
      WHEN type IN ('hotel', 'host') THEN 'host_payable'
      ELSE 'merchant_payable'
    END
  INTO v_account_type
  FROM public.partner_profiles
  WHERE id = p_partner_id;

  -- 5. Calculate available balance from platform ledger
  SELECT COALESCE(credit_balance_paisa, 0) INTO v_credit_balance
  FROM public.partner_ledger_balances
  WHERE account_type = v_account_type AND account_id = p_partner_id;

  -- 6. Apply Zero-Hub COD Lock for riders/drivers
  IF v_account_type = 'rider_payable' THEN
    SELECT COALESCE(-credit_balance_paisa, 0) INTO v_cash_in_hand
    FROM public.partner_ledger_balances
    WHERE account_type = 'rider_cash_in_hand' AND account_id = p_partner_id;
    v_cash_in_hand := GREATEST(v_cash_in_hand, 0);
  END IF;

  v_withdrawable := v_credit_balance - v_cash_in_hand;

  IF v_withdrawable < p_amount_paisa THEN
    RAISE EXCEPTION 'Insufficient withdrawable balance. Available: NPR %, Requested: NPR % (Rider cash offset: NPR %)',
      (v_withdrawable / 100.0)::numeric(10,2),
      (p_amount_paisa / 100.0)::numeric(10,2),
      (v_cash_in_hand / 100.0)::numeric(10,2)
      USING ERRCODE = '22000';
  END IF;

  -- 7. Validate Destination
  IF p_destination_type = 'bank' THEN
    SELECT id INTO v_bank_id
    FROM public.partner_bank_accounts
    WHERE partner_id = p_partner_id AND is_verified AND is_primary;

    IF v_bank_id IS NULL THEN
      RAISE EXCEPTION 'No verified primary bank account found. Please link and verify your bank account first.'
        USING ERRCODE = '22000';
    END IF;
  ELSIF p_destination_type IN ('esewa', 'khalti') THEN
    IF p_wallet_phone IS NULL OR p_wallet_phone = '' THEN
      RAISE EXCEPTION 'Wallet mobile number is required for % payout' , p_destination_type
        USING ERRCODE = '22000';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported destination rail: %', p_destination_type USING ERRCODE = '22000';
  END IF;

  -- Net paid to partner is amount minus instant convenience fee
  v_net_paisa := p_amount_paisa - v_fee_paisa;
  IF v_net_paisa <= 0 THEN
    RAISE EXCEPTION 'Withdrawal amount must be greater than the NPR 15 instant fee.' USING ERRCODE = '22000';
  END IF;

  -- 8. Insert on-demand payout record
  INSERT INTO public.payouts (
    batch_id,
    partner_id,
    bank_account_id,
    payable_paisa,
    cod_offset_paisa,
    net_paisa,
    payable_account,
    payout_type,
    destination_type,
    destination_wallet,
    instant_fee_paisa,
    status
  )
  VALUES (
    NULL, -- No scheduled batch
    p_partner_id,
    v_bank_id,
    p_amount_paisa,
    0, -- Cash offset already checked in withdrawable math
    v_net_paisa,
    v_account_type,
    'on_demand',
    p_destination_type,
    p_wallet_phone,
    v_fee_paisa,
    'pending'
  )
  RETURNING id INTO v_payout_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'payout_id', v_payout_id,
    'requested_npr', (p_amount_paisa / 100.0)::numeric(10,2),
    'instant_fee_npr', (v_fee_paisa / 100.0)::numeric(10,2),
    'net_payout_npr', (v_net_paisa / 100.0)::numeric(10,2),
    'destination_type', p_destination_type,
    'status', 'pending',
    'message', 'On-demand withdrawal submitted. Processing instant transfer via domestic rail.'
  );
END;
$$;

-- Allow authenticated partner owners to execute request_on_demand_payout
GRANT EXECUTE ON FUNCTION public.request_on_demand_payout(UUID, BIGINT, TEXT, TEXT) TO authenticated;
