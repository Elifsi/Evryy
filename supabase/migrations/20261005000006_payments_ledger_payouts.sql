-- =============================================================================
-- 0006 — Payments, immutable double-entry ledger & settlement payouts
--
-- No customer wallet exists (NRB PSP licensing). Money moves through direct
-- rails (Fonepay QR / eSewa / Khalti / cards) or COD, and every rupee is
-- tracked in an append-only, always-balanced ledger.
-- Gateway-facing functions are executable by service_role ONLY (Edge Functions).
-- =============================================================================

-- v1 scope: rides are settled in cash. Prepaid rides can be enabled later by
-- dropping this constraint and adding a ride branch to confirm_payment().
ALTER TABLE public.rides
  ADD CONSTRAINT rides_cod_only_v1 CHECK (payment_method = 'cod');

-- ---------------------------------------------------------------------------
-- payments
-- ---------------------------------------------------------------------------
CREATE TABLE public.payments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES public.profiles(id),
  reference_type    TEXT NOT NULL CHECK (reference_type IN ('order', 'reservation')),
  reference_id      UUID NOT NULL,
  method            public.payment_method NOT NULL,
  provider          TEXT NOT NULL,                     -- 'fonepay' | 'esewa' | 'khalti' | 'cod'
  provider_txn_ref  TEXT NOT NULL,                     -- gateway transaction id (idempotency key)
  amount_paisa      BIGINT NOT NULL CHECK (amount_paisa > 0),
  refunded_paisa    BIGINT NOT NULL DEFAULT 0 CHECK (refunded_paisa >= 0),
  status            public.payment_status NOT NULL DEFAULT 'succeeded',
  raw_payload       JSONB,                             -- verified webhook body, for disputes
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_txn_ref),
  CONSTRAINT refund_not_above_amount CHECK (refunded_paisa <= amount_paisa)
);
CREATE INDEX payments_user_idx ON public.payments (user_id, created_at DESC);
CREATE INDEX payments_ref_idx  ON public.payments (reference_type, reference_id);

-- ---------------------------------------------------------------------------
-- platform_ledger — append-only, double-entry
--   account_type examples:
--     gateway_clearing   (platform)  money held by gateways owed to us
--     merchant_payable   (partner)   owed to restaurants / stores
--     rider_payable      (partner)   owed to riders / drivers
--     host_payable       (partner)   owed to hotels
--     rider_cash_in_hand (partner)   COD cash riders owe the platform (debit-normal)
--     platform_revenue   (platform)  commission + fees earned
--     vat_payable        (platform)  VAT collected, owed to IRD
--     marketing_expense  (platform)  platform-funded discounts
--     refund_expense     (platform)  refunds absorbed by the platform
--     bank_clearing      (platform)  cash leaving via connectIPS / Khalti payouts
-- ---------------------------------------------------------------------------
CREATE TABLE public.platform_ledger (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  txn_group     UUID NOT NULL,
  account_type  TEXT NOT NULL CHECK (account_type IN (
                  'gateway_clearing', 'merchant_payable', 'rider_payable', 'host_payable',
                  'rider_cash_in_hand', 'platform_revenue', 'vat_payable',
                  'marketing_expense', 'refund_expense', 'bank_clearing')),
  account_id    UUID REFERENCES public.partner_profiles(id),   -- NULL for platform-owned accounts
  direction     TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
  amount_paisa  BIGINT NOT NULL CHECK (amount_paisa > 0),
  ref_type      TEXT NOT NULL,
  ref_id        UUID,
  memo          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT partner_accounts_need_id CHECK (
    (account_type IN ('merchant_payable', 'rider_payable', 'host_payable', 'rider_cash_in_hand')) = (account_id IS NOT NULL)
  )
);
CREATE INDEX ledger_group_idx   ON public.platform_ledger (txn_group);
CREATE INDEX ledger_account_idx ON public.platform_ledger (account_type, account_id);
CREATE INDEX ledger_ref_idx     ON public.platform_ledger (ref_type, ref_id);

CREATE TRIGGER platform_ledger_immutable BEFORE UPDATE OR DELETE ON public.platform_ledger
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

-- Every transaction group must balance (debits = credits), checked at COMMIT.
CREATE OR REPLACE FUNCTION public.assert_ledger_group_balanced()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE v_diff BIGINT;
BEGIN
  SELECT COALESCE(SUM(CASE direction WHEN 'debit' THEN amount_paisa ELSE -amount_paisa END), 0)
    INTO v_diff FROM public.platform_ledger WHERE txn_group = NEW.txn_group;
  IF v_diff <> 0 THEN
    RAISE EXCEPTION 'ledger group % is unbalanced by % paisa', NEW.txn_group, v_diff USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER platform_ledger_balanced
  AFTER INSERT ON public.platform_ledger
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.assert_ledger_group_balanced();

-- Internal helper (not exposed): write one balanced posting.
-- p_lines: [{"account_type":"..","account_id":"uuid|null","direction":"debit|credit","amount":123}]
CREATE OR REPLACE FUNCTION public.post_ledger_group(
  p_ref_type TEXT, p_ref_id UUID, p_memo TEXT, p_lines JSONB
) RETURNS UUID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE v_group UUID := gen_random_uuid(); v_line JSONB;
BEGIN
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    IF (v_line ->> 'amount')::bigint > 0 THEN
      INSERT INTO public.platform_ledger (txn_group, account_type, account_id, direction, amount_paisa, ref_type, ref_id, memo)
      VALUES (v_group, v_line ->> 'account_type', NULLIF(v_line ->> 'account_id', '')::uuid,
              v_line ->> 'direction', (v_line ->> 'amount')::bigint, p_ref_type, p_ref_id, p_memo);
    END IF;
  END LOOP;
  RETURN v_group;
END;
$$;
REVOKE ALL ON FUNCTION public.post_ledger_group(TEXT, UUID, TEXT, JSONB) FROM PUBLIC;

-- Balance helper: credit-normal accounts report (credits - debits).
CREATE OR REPLACE VIEW public.partner_ledger_balances
WITH (security_invoker = true) AS
SELECT account_type, account_id,
       SUM(CASE direction WHEN 'credit' THEN amount_paisa ELSE -amount_paisa END) AS credit_balance_paisa
FROM public.platform_ledger
WHERE account_id IS NOT NULL
GROUP BY account_type, account_id;

-- ---------------------------------------------------------------------------
-- Gateway confirmation (service_role only — called from verified webhook Edge Fn)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_payment(
  p_reference_type TEXT, p_reference_id UUID,
  p_method public.payment_method, p_provider TEXT, p_provider_txn_ref TEXT,
  p_amount_paisa BIGINT, p_raw JSONB DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id UUID; v_user UUID; v_total BIGINT; v_status TEXT;
BEGIN
  -- Idempotent: a replayed webhook returns the original payment.
  SELECT id INTO v_payment_id FROM public.payments
   WHERE provider = p_provider AND provider_txn_ref = p_provider_txn_ref;
  IF FOUND THEN RETURN v_payment_id; END IF;

  IF p_reference_type = 'order' THEN
    SELECT consumer_id, total_paisa, status::text INTO v_user, v_total, v_status
      FROM public.orders WHERE id = p_reference_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'order not found'; END IF;
    IF v_status <> 'draft' THEN RAISE EXCEPTION 'order is not awaiting payment (status %)', v_status; END IF;
  ELSIF p_reference_type = 'reservation' THEN
    SELECT guest_id, total_paisa, status::text INTO v_user, v_total, v_status
      FROM public.room_reservations WHERE id = p_reference_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'reservation not found'; END IF;
    IF v_status <> 'pending' THEN RAISE EXCEPTION 'reservation is not awaiting payment (status %)', v_status; END IF;
  ELSE
    RAISE EXCEPTION 'unsupported reference type';
  END IF;

  IF p_amount_paisa <> v_total THEN
    RAISE EXCEPTION 'paid amount % does not match payable %', p_amount_paisa, v_total;
  END IF;

  INSERT INTO public.payments (user_id, reference_type, reference_id, method, provider, provider_txn_ref, amount_paisa, raw_payload)
  VALUES (v_user, p_reference_type, p_reference_id, p_method, p_provider, p_provider_txn_ref, p_amount_paisa, p_raw)
  RETURNING id INTO v_payment_id;

  IF p_reference_type = 'order' THEN
    UPDATE public.orders SET status = 'acknowledged' WHERE id = p_reference_id;
    INSERT INTO public.order_status_history (order_id, status, actor_id, note)
    VALUES (p_reference_id, 'acknowledged', NULL, 'payment verified: ' || p_provider);
  ELSE
    UPDATE public.room_reservations SET status = 'confirmed' WHERE id = p_reference_id;
  END IF;
  RETURN v_payment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_payment_refund(p_payment UUID, p_amount_paisa BIGINT, p_reason TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_p public.payments;
BEGIN
  SELECT * INTO v_p FROM public.payments WHERE id = p_payment FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payment not found'; END IF;
  IF v_p.refunded_paisa + p_amount_paisa > v_p.amount_paisa THEN RAISE EXCEPTION 'refund exceeds paid amount'; END IF;

  UPDATE public.payments
     SET refunded_paisa = refunded_paisa + p_amount_paisa,
         status = CASE WHEN refunded_paisa + p_amount_paisa = amount_paisa THEN 'refunded'::public.payment_status
                       ELSE 'partially_refunded'::public.payment_status END
   WHERE id = p_payment;

  PERFORM public.post_ledger_group('refund', p_payment, p_reason, jsonb_build_array(
    jsonb_build_object('account_type', 'refund_expense',    'direction', 'debit',  'amount', p_amount_paisa),
    jsonb_build_object('account_type', 'gateway_clearing',  'direction', 'credit', 'amount', p_amount_paisa)));
END;
$$;

-- ---------------------------------------------------------------------------
-- Settlement postings on completion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_order_settlement()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store public.stores; v_commission BIGINT; v_lines JSONB;
BEGIN
  IF NEW.status <> 'delivered' OR OLD.status = 'delivered' THEN RETURN NEW; END IF;
  SELECT * INTO v_store FROM public.stores WHERE id = NEW.store_id;
  v_commission := round(NEW.subtotal_paisa * NEW.commission_bps / 10000.0);

  v_lines := jsonb_build_array(
    -- money in: COD cash sits with the rider; prepaid is at the gateway
    CASE WHEN NEW.payment_method = 'cod'
      THEN jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', NEW.rider_partner_id, 'direction', 'debit', 'amount', NEW.total_paisa)
      ELSE jsonb_build_object('account_type', 'gateway_clearing', 'direction', 'debit', 'amount', NEW.total_paisa) END,
    jsonb_build_object('account_type', 'marketing_expense', 'direction', 'debit',  'amount', NEW.discount_paisa),
    jsonb_build_object('account_type', 'merchant_payable', 'account_id', v_store.partner_id, 'direction', 'credit', 'amount', NEW.subtotal_paisa - v_commission),
    jsonb_build_object('account_type', 'rider_payable', 'account_id', NEW.rider_partner_id, 'direction', 'credit', 'amount', NEW.delivery_fee_paisa),
    jsonb_build_object('account_type', 'platform_revenue', 'direction', 'credit', 'amount', v_commission + NEW.platform_fee_paisa),
    jsonb_build_object('account_type', 'vat_payable',      'direction', 'credit', 'amount', NEW.tax_paisa));

  IF NEW.rider_partner_id IS NULL THEN
    RAISE EXCEPTION 'cannot settle an order that has no rider';
  END IF;

  PERFORM public.post_ledger_group('order', NEW.id, 'order #' || NEW.order_no || ' delivered', v_lines);

  IF NEW.payment_method = 'cod' THEN
    UPDATE public.rider_details SET cod_cash_in_hand_paisa = cod_cash_in_hand_paisa + NEW.total_paisa
     WHERE partner_id = NEW.rider_partner_id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER orders_post_settlement AFTER UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.post_order_settlement();

CREATE OR REPLACE FUNCTION public.post_ride_settlement()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_commission BIGINT;
BEGIN
  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN RETURN NEW; END IF;
  v_commission := round(NEW.final_fare_paisa * NEW.commission_bps / 10000.0);
  PERFORM public.post_ledger_group('ride', NEW.id, 'ride completed', jsonb_build_array(
    jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', NEW.driver_partner_id, 'direction', 'debit',  'amount', NEW.final_fare_paisa),
    jsonb_build_object('account_type', 'rider_payable',      'account_id', NEW.driver_partner_id, 'direction', 'credit', 'amount', NEW.final_fare_paisa - v_commission),
    jsonb_build_object('account_type', 'platform_revenue',   'direction', 'credit', 'amount', v_commission)));
  UPDATE public.rider_details SET cod_cash_in_hand_paisa = cod_cash_in_hand_paisa + NEW.final_fare_paisa
   WHERE partner_id = NEW.driver_partner_id;
  RETURN NEW;
END;
$$;
CREATE TRIGGER rides_post_settlement AFTER UPDATE OF status ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.post_ride_settlement();

CREATE OR REPLACE FUNCTION public.post_reservation_settlement()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_commission BIGINT; v_partner UUID;
BEGIN
  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN RETURN NEW; END IF;
  SELECT p.partner_id INTO v_partner FROM public.rooms r JOIN public.properties p ON p.id = r.property_id WHERE r.id = NEW.room_id;
  v_commission := round(NEW.subtotal_paisa * NEW.commission_bps / 10000.0);
  PERFORM public.post_ledger_group('reservation', NEW.id, 'stay completed', jsonb_build_array(
    jsonb_build_object('account_type', 'gateway_clearing', 'direction', 'debit',  'amount', NEW.total_paisa),
    jsonb_build_object('account_type', 'host_payable', 'account_id', v_partner, 'direction', 'credit', 'amount', NEW.subtotal_paisa - v_commission),
    jsonb_build_object('account_type', 'platform_revenue', 'direction', 'credit', 'amount', v_commission + NEW.service_fee_paisa)));
  RETURN NEW;
END;
$$;
CREATE TRIGGER reservations_post_settlement AFTER UPDATE OF status ON public.room_reservations
  FOR EACH ROW EXECUTE FUNCTION public.post_reservation_settlement();

-- Host / guest reservation lifecycle (clients have no UPDATE on reservations).
CREATE OR REPLACE FUNCTION public.advance_reservation_status(p_res UUID, p_new public.reservation_status)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_r public.room_reservations; v_partner UUID; v_host BOOLEAN; v_guest BOOLEAN;
BEGIN
  SELECT * INTO v_r FROM public.room_reservations WHERE id = p_res FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'reservation not found'; END IF;
  SELECT p.partner_id INTO v_partner FROM public.rooms r JOIN public.properties p ON p.id = r.property_id WHERE r.id = v_r.room_id;
  v_host  := public.is_partner_member(v_partner, ARRAY['owner', 'manager']);
  v_guest := v_r.guest_id = auth.uid();
  IF v_r.status = p_new THEN RETURN; END IF;
  IF NOT (
       public.is_admin()
    OR (v_host  AND ((v_r.status = 'confirmed'  AND p_new = 'checked_in')
                  OR (v_r.status = 'checked_in' AND p_new = 'completed')
                  OR (v_r.status IN ('pending', 'confirmed') AND p_new = 'cancelled')))
    OR (v_guest AND v_r.status IN ('pending', 'confirmed') AND p_new = 'cancelled')
  ) THEN
    RAISE EXCEPTION 'transition % -> % is not permitted', v_r.status, p_new USING ERRCODE = '42501';
  END IF;
  UPDATE public.room_reservations SET status = p_new WHERE id = p_res;
END;
$$;

-- Release unpaid holds so abandoned checkouts never lock stock or dates.
-- Scheduled every minute by pg_cron in migration 0009 (when the extension exists).
CREATE OR REPLACE FUNCTION public.expire_unpaid_holds()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_count INT := 0; v_o RECORD;
BEGIN
  FOR v_o IN SELECT id FROM public.orders
              WHERE status = 'draft' AND payment_method <> 'cod' AND placed_at < now() - interval '15 minutes'
              FOR UPDATE SKIP LOCKED LOOP
    UPDATE public.inventory_items inv SET stock_quantity = inv.stock_quantity + oi.quantity
      FROM public.order_items oi WHERE oi.order_id = v_o.id AND oi.item_id = inv.item_id;
    UPDATE public.orders SET status = 'cancelled', cancel_reason = 'payment timeout' WHERE id = v_o.id;
    INSERT INTO public.order_status_history (order_id, status, note) VALUES (v_o.id, 'cancelled', 'payment timeout');
    v_count := v_count + 1;
  END LOOP;

  UPDATE public.room_reservations SET status = 'cancelled'
   WHERE status = 'pending' AND created_at < now() - interval '15 minutes';
  RETURN v_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- Payout batches (midnight connectIPS / Khalti disbursement)
-- ---------------------------------------------------------------------------
CREATE TABLE public.settlement_batches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_date    DATE NOT NULL UNIQUE,
  status        TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'executing', 'completed', 'cancelled')),
  total_paisa   BIGINT NOT NULL DEFAULT 0,
  approved_by   UUID REFERENCES public.profiles(id),
  approved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.payouts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id         UUID NOT NULL REFERENCES public.settlement_batches(id) ON DELETE CASCADE,
  partner_id       UUID NOT NULL REFERENCES public.partner_profiles(id),
  bank_account_id  UUID NOT NULL REFERENCES public.partner_bank_accounts(id),
  payable_paisa    BIGINT NOT NULL CHECK (payable_paisa > 0),   -- credit balance being settled
  cod_offset_paisa BIGINT NOT NULL DEFAULT 0 CHECK (cod_offset_paisa >= 0),
  net_paisa        BIGINT NOT NULL CHECK (net_paisa > 0),
  payable_account  TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed')),
  provider_ref     TEXT,
  failure_reason   TEXT,
  paid_at          TIMESTAMPTZ,
  UNIQUE (batch_id, partner_id, payable_account)
);
CREATE INDEX payouts_partner_idx ON public.payouts (partner_id);

-- Build the draft batch: one payout per verified partner whose settled-nets are positive.
CREATE OR REPLACE FUNCTION public.admin_build_settlement_batch(p_date DATE)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch UUID; v_row RECORD; v_cash BIGINT; v_net BIGINT; v_bank UUID;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.settlement_batches (batch_date) VALUES (p_date) RETURNING id INTO v_batch;

  FOR v_row IN
    SELECT account_type, account_id, credit_balance_paisa AS payable
      FROM public.partner_ledger_balances
     WHERE account_type IN ('merchant_payable', 'rider_payable', 'host_payable') AND credit_balance_paisa > 0
  LOOP
    SELECT id INTO v_bank FROM public.partner_bank_accounts
     WHERE partner_id = v_row.account_id AND is_verified AND is_primary;
    CONTINUE WHEN v_bank IS NULL;                                  -- no verified bank: carry forward

    v_cash := 0;
    IF v_row.account_type = 'rider_payable' THEN
      -- COD cash the rider is holding is offset against what we owe them.
      SELECT COALESCE(-credit_balance_paisa, 0) INTO v_cash FROM public.partner_ledger_balances
       WHERE account_type = 'rider_cash_in_hand' AND account_id = v_row.account_id;
      v_cash := GREATEST(COALESCE(v_cash, 0), 0);
    END IF;
    v_net := v_row.payable - LEAST(v_cash, v_row.payable);
    CONTINUE WHEN v_net <= 0;                                      -- rider still owes cash: carry forward

    INSERT INTO public.payouts (batch_id, partner_id, bank_account_id, payable_paisa, cod_offset_paisa, net_paisa, payable_account)
    VALUES (v_batch, v_row.account_id, v_bank, v_row.payable, LEAST(v_cash, v_row.payable), v_net, v_row.account_type);
  END LOOP;

  UPDATE public.settlement_batches SET total_paisa = COALESCE((SELECT SUM(net_paisa) FROM public.payouts WHERE batch_id = v_batch), 0)
   WHERE id = v_batch;
  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, new_state, reason)
  VALUES (auth.uid(), 'SETTLEMENT_BATCH_BUILT', 'batch:' || v_batch, jsonb_build_object('date', p_date), 'daily settlement build');
  RETURN v_batch;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_approve_settlement_batch(p_batch UUID, p_reason TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only' USING ERRCODE = '42501'; END IF;
  UPDATE public.settlement_batches SET status = 'approved', approved_by = auth.uid(), approved_at = now()
   WHERE id = p_batch AND status = 'draft';
  IF NOT FOUND THEN RAISE EXCEPTION 'batch is not in draft'; END IF;
  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_entity, new_state, reason)
  VALUES (auth.uid(), 'SETTLEMENT_BATCH_APPROVED', 'batch:' || p_batch, jsonb_build_object('status', 'approved'), p_reason);
END;
$$;

-- Called by the payout Edge Function after the bank/Khalti confirms the transfer.
CREATE OR REPLACE FUNCTION public.mark_payout_paid(p_payout UUID, p_provider_ref TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_p public.payouts; v_status TEXT; v_lines JSONB;
BEGIN
  SELECT * INTO v_p FROM public.payouts WHERE id = p_payout FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payout not found'; END IF;
  IF v_p.status = 'paid' THEN RETURN; END IF;
  SELECT status INTO v_status FROM public.settlement_batches WHERE id = v_p.batch_id;
  IF v_status NOT IN ('approved', 'executing') THEN RAISE EXCEPTION 'batch is not approved'; END IF;

  v_lines := jsonb_build_array(
    jsonb_build_object('account_type', v_p.payable_account, 'account_id', v_p.partner_id, 'direction', 'debit', 'amount', v_p.payable_paisa),
    jsonb_build_object('account_type', 'bank_clearing', 'direction', 'credit', 'amount', v_p.net_paisa),
    jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', CASE WHEN v_p.cod_offset_paisa > 0 THEN v_p.partner_id END,
                       'direction', 'credit', 'amount', v_p.cod_offset_paisa));
  PERFORM public.post_ledger_group('payout', p_payout, 'payout ' || p_provider_ref, v_lines);

  IF v_p.cod_offset_paisa > 0 THEN
    UPDATE public.rider_details SET cod_cash_in_hand_paisa = GREATEST(cod_cash_in_hand_paisa - v_p.cod_offset_paisa, 0)
     WHERE partner_id = v_p.partner_id;
  END IF;
  UPDATE public.payouts SET status = 'paid', provider_ref = p_provider_ref, paid_at = now() WHERE id = p_payout;
  UPDATE public.settlement_batches SET status = 'completed'
   WHERE id = v_p.batch_id AND NOT EXISTS (SELECT 1 FROM public.payouts WHERE batch_id = v_p.batch_id AND status <> 'paid');
END;
$$;

-- ---------------------------------------------------------------------------
-- Privileges: gateway/payout functions are for Edge Functions (service_role) only.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.confirm_payment(TEXT, UUID, public.payment_method, TEXT, TEXT, BIGINT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_payment_refund(UUID, BIGINT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_payout_paid(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expire_unpaid_holds() FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.confirm_payment(TEXT, UUID, public.payment_method, TEXT, TEXT, BIGINT, JSONB) TO service_role;
    GRANT EXECUTE ON FUNCTION public.record_payment_refund(UUID, BIGINT, TEXT) TO service_role;
    GRANT EXECUTE ON FUNCTION public.mark_payout_paid(UUID, TEXT) TO service_role;
    GRANT EXECUTE ON FUNCTION public.expire_unpaid_holds() TO service_role;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.payments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_ledger    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlement_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts            ENABLE ROW LEVEL SECURITY;

CREATE POLICY payments_select ON public.payments FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- Partners see only their own payable / cash-in-hand rows; admins see everything.
CREATE POLICY ledger_select ON public.platform_ledger FOR SELECT
  USING (public.is_admin() OR (account_id IS NOT NULL AND public.is_partner_member(account_id, ARRAY['owner'])));

CREATE POLICY batches_admin ON public.settlement_batches FOR SELECT USING (public.is_admin());
CREATE POLICY payouts_select ON public.payouts FOR SELECT
  USING (public.is_admin() OR public.is_partner_member(partner_id, ARRAY['owner']));
