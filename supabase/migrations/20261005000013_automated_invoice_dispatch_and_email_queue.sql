-- ============================================================================
-- Migration 0013: Automated Invoice Dispatch and Outbox Email Queue
-- evrry Super App — Elifsi Technologies Private Limited
--
-- Guarantees:
-- 1. Zero Client Keys: Mobile APKs/IPAs never touch Resend API keys.
-- 2. Enterprise Outbox Pattern: Invoices are queued automatically upon order delivery.
-- 3. Idempotent Delivery: Unique constraint prevents duplicate invoice dispatch per order.
-- 4. Full Audit Trail: Admins can inspect email delivery status and failures in Operations Console.
-- ============================================================================

-- Outbox Email Dispatch Queue
CREATE TABLE public.email_dispatch_queue (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email  TEXT NOT NULL CHECK (recipient_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  action           TEXT NOT NULL CHECK (action IN ('order_invoice', 'verification_otp', 'partner_kyc_status', 'payout_statement', 'custom')),
  reference_id     UUID,                                      -- order_id, partner_id, or payout_batch_id
  payload          JSONB NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  attempts         INTEGER NOT NULL DEFAULT 0,
  max_attempts     INTEGER NOT NULL DEFAULT 3,
  last_error       TEXT,
  resend_id        TEXT,
  sent_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_email_order_invoice UNIQUE (reference_id, action)
);

CREATE INDEX email_queue_status_idx ON public.email_dispatch_queue (status, created_at) WHERE status IN ('pending', 'failed');
CREATE INDEX email_queue_ref_idx    ON public.email_dispatch_queue (reference_id, action);

CREATE TRIGGER email_queue_updated_at BEFORE UPDATE ON public.email_dispatch_queue
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS: Only Superadmins can view the email dispatch queue; no consumer or partner direct write
ALTER TABLE public.email_dispatch_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY email_queue_admin_read ON public.email_dispatch_queue
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'superadmin'));

CREATE POLICY email_queue_admin_manage ON public.email_dispatch_queue
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'superadmin'))
  WITH CHECK (public.has_role(auth.uid(), 'superadmin'));

-- Trigger Function: Automatically queue digital tax invoice when order is delivered
CREATE OR REPLACE FUNCTION public.trigger_queue_delivered_order_invoice()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_consumer_email    TEXT;
  v_consumer_name     TEXT;
  v_consumer_phone    TEXT;
  v_store_name        TEXT;
  v_store_address     TEXT;
  v_store_pan         TEXT;
  v_items_json        JSONB;
  v_invoice_payload   JSONB;
BEGIN
  -- Only fire when status transitions to 'delivered'
  IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered') THEN
    -- 1. Fetch Consumer Info
    SELECT
      p.email,
      COALESCE(p.full_name, 'Valued Customer'),
      p.phone
    INTO
      v_consumer_email,
      v_consumer_name,
      v_consumer_phone
    FROM public.profiles p
    WHERE p.id = NEW.consumer_id;

    -- If no email is associated with consumer, skip email dispatch
    IF v_consumer_email IS NULL OR v_consumer_email = '' THEN
      RETURN NEW;
    END IF;

    -- 2. Fetch Store / Merchant Details
    SELECT
      s.name,
      COALESCE(s.address, ''),
      pp.pan_number
    INTO
      v_store_name,
      v_store_address,
      v_store_pan
    FROM public.stores s
    JOIN public.partner_profiles pp ON pp.id = s.partner_id
    WHERE s.id = NEW.store_id;

    -- 3. Fetch Items Line Details
    SELECT jsonb_agg(
      jsonb_build_object(
        'name', oi.name,
        'quantity', oi.quantity,
        'unitPricePaisa', oi.unit_price_paisa
      )
    )
    INTO v_items_json
    FROM public.order_items oi
    WHERE oi.order_id = NEW.id;

    -- 4. Assemble Invoice Payload
    v_invoice_payload := jsonb_build_object(
      'orderNo', NEW.order_no,
      'placedAt', NEW.placed_at,
      'customerName', v_consumer_name,
      'customerEmail', v_consumer_email,
      'customerPhone', v_consumer_phone,
      'deliveryAddress', COALESCE(NEW.delivery_address->>'formatted_address', 'Kathmandu Valley, Nepal'),
      'merchantName', COALESCE(v_store_name, 'evrry Merchant'),
      'merchantAddress', v_store_address,
      'merchantPan', v_store_pan,
      'paymentMethod', NEW.payment_method::text,
      'items', COALESCE(v_items_json, '[]'::jsonb),
      'subtotalPaisa', NEW.subtotal_paisa,
      'deliveryFeePaisa', NEW.delivery_fee_paisa,
      'platformFeePaisa', NEW.platform_fee_paisa,
      'taxPaisa', NEW.tax_paisa,
      'discountPaisa', NEW.discount_paisa,
      'totalPaisa', NEW.total_paisa
    );

    -- 5. Insert into Outbox Email Queue (ON CONFLICT DO NOTHING guarantees idempotency)
    INSERT INTO public.email_dispatch_queue (
      recipient_email,
      action,
      reference_id,
      payload,
      status
    )
    VALUES (
      v_consumer_email,
      'order_invoice',
      NEW.id,
      jsonb_build_object('invoiceData', v_invoice_payload),
      'pending'
    )
    ON CONFLICT (reference_id, action) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_queue_order_delivered_invoice ON public.orders;
CREATE TRIGGER trg_queue_order_delivered_invoice
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_queue_delivered_order_invoice();

COMMENT ON TABLE public.email_dispatch_queue IS
  'Resilient outbox queue for transactional emails (Invoices, OTPs, KYC notices, Settlement statements) sent via Resend API.';
