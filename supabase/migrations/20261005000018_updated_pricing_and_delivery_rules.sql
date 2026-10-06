-- =============================================================================
-- 0018 — Updated Free Delivery Threshold, Distance Bands, Driver Payout Share & Platform Fee
-- Elifsi Technologies Private Limited
--
-- Pricing Rules:
-- 1. Free Delivery Threshold: Orders >= NPR 1,000 (100,000 paisa) get FREE delivery.
-- 2. Base Delivery Fee: NPR 50 (5,000 paisa) within 3 km radius (3,000 meters).
-- 3. Extra Distance Fee: NPR 15 (1,500 paisa) per km for distance exceeding 3 km.
-- 4. Driver Delivery Payout:
--    - Up to 3 km: Driver earns NPR 40 (4,000 paisa).
--    - Beyond 3 km: Driver earns NPR 40 + 80% (8,000 bps) of the extra delivery fee.
-- 5. Platform Fee: NPR 10 (1,000 paisa) per order.
-- =============================================================================

-- Update platform settings with new defaults
INSERT INTO public.platform_settings (key, value_int, description) VALUES
  ('delivery_free_threshold_paisa', 100000, 'Minimum order subtotal for free delivery (NPR 1,000)'),
  ('delivery_base_radius_m',        3000,   'Base delivery radius in meters (3 km)'),
  ('driver_base_payout_paisa',      4000,   'Driver base payout per delivery within 3 km (NPR 40)'),
  ('driver_extra_share_bps',        8000,   'Driver share of extra distance delivery fee (80%)')
ON CONFLICT (key) DO UPDATE
  SET value_int = EXCLUDED.value_int, description = EXCLUDED.description;

UPDATE public.platform_settings
   SET value_int = 1000, description = 'Per-order platform fee charged to customer (NPR 10)'
 WHERE key = 'platform_fee_paisa';

UPDATE public.platform_settings
   SET value_int = 5000, description = 'Base delivery fee charged to customer up to 3 km (NPR 50)'
 WHERE key = 'delivery_base_fee_paisa';

UPDATE public.platform_settings
   SET value_int = 1500, description = 'Delivery fee charged per extra km above 3 km (NPR 15/km)'
 WHERE key = 'delivery_per_km_fee_paisa';

-- ---------------------------------------------------------------------------
-- Update place_order with new free threshold & 3km base distance logic
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order(
  p_store_id UUID,
  p_items JSONB,                          -- array of {item_id: uuid, qty: int}
  p_address_id UUID,
  p_payment_method public.payment_method DEFAULT 'cod',
  p_note TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid         UUID := auth.uid();
  v_store       public.stores;
  v_partner     public.partner_profiles;
  v_addr        public.user_addresses;
  v_order_id    UUID;
  v_dist_m      INTEGER;
  v_base_m      BIGINT;
  v_base_fee    BIGINT;
  v_per_km      BIGINT;
  v_platform    BIGINT;
  v_vat         BIGINT;
  v_radius      BIGINT;
  v_free_thresh BIGINT;
  v_delivery    BIGINT;
  v_extra_km    INTEGER;
  v_subtotal    BIGINT := 0;
  v_tax         BIGINT := 0;
  v_total       BIGINT := 0;
  v_status      public.order_status;
  v_line        JSONB;
  v_item        public.catalog_items;
  v_qty         INTEGER;
  v_seen        UUID[] := '{}';
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF NOT public.is_account_active(v_uid) THEN RAISE EXCEPTION 'account is not active' USING ERRCODE = '42501'; END IF;
  IF p_payment_method = 'cod' AND NOT (SELECT cod_enabled FROM public.profiles WHERE id = v_uid) THEN
    RAISE EXCEPTION 'cash payment is disabled for this account' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_store FROM public.stores WHERE id = p_store_id;
  IF NOT FOUND OR NOT v_store.is_open THEN RAISE EXCEPTION 'store is closed or unavailable'; END IF;
  SELECT * INTO v_partner FROM public.partner_profiles WHERE id = v_store.partner_id;
  IF v_partner.status <> 'active' THEN RAISE EXCEPTION 'store is not accepting orders'; END IF;

  SELECT * INTO v_addr FROM public.user_addresses WHERE id = p_address_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery address not found'; END IF;

  IF public.is_service_blocked(v_store.local_level_id, v_store.ward_no, v_store.category::text)
     OR (v_addr.local_level_id IS NOT NULL
         AND public.is_service_blocked(v_addr.local_level_id, v_addr.ward_no, v_store.category::text)) THEN
    RAISE EXCEPTION 'service is temporarily unavailable in this area';
  END IF;

  SELECT coalesce(value_int, 5000)   INTO v_base_fee    FROM public.platform_settings WHERE key = 'delivery_base_fee_paisa';
  SELECT coalesce(value_int, 3000)   INTO v_base_m      FROM public.platform_settings WHERE key = 'delivery_base_radius_m';
  SELECT coalesce(value_int, 1500)   INTO v_per_km      FROM public.platform_settings WHERE key = 'delivery_per_km_fee_paisa';
  SELECT coalesce(value_int, 1000)   INTO v_platform    FROM public.platform_settings WHERE key = 'platform_fee_paisa';
  SELECT coalesce(value_int, 0)      INTO v_vat         FROM public.platform_settings WHERE key = 'vat_bps';
  SELECT coalesce(value_int, 25000)  INTO v_radius      FROM public.platform_settings WHERE key = 'max_delivery_radius_m';
  SELECT coalesce(value_int, 100000) INTO v_free_thresh FROM public.platform_settings WHERE key = 'delivery_free_threshold_paisa';

  v_dist_m := round(ST_Distance(v_store.location, v_addr.location))::int;
  IF v_dist_m > v_radius THEN RAISE EXCEPTION 'address is outside the delivery radius'; END IF;

  -- Calculate distance-based delivery fee
  v_extra_km := GREATEST(0, ceil(v_dist_m / 1000.0)::int - ceil(v_base_m / 1000.0)::int);
  v_delivery := v_base_fee + (v_extra_km * v_per_km);

  -- Insert order shell
  INSERT INTO public.orders (
    consumer_id, store_id, status, payment_method,
    subtotal_paisa, delivery_fee_paisa, platform_fee_paisa, tax_paisa, total_paisa,
    commission_bps, delivery_address, delivery_location, delivery_distance_m, customer_note
  ) VALUES (
    v_uid, p_store_id, 'draft', p_payment_method,
    0, v_delivery, v_platform, 0, v_delivery + v_platform,
    v_partner.commission_bps,
    jsonb_build_object('label', v_addr.label, 'street', v_addr.street, 'landmark', v_addr.landmark,
                       'instructions', v_addr.instructions, 'local_level_id', v_addr.local_level_id,
                       'ward_no', v_addr.ward_no),
    v_addr.location, v_dist_m, p_note
  ) RETURNING id INTO v_order_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_line ->> 'qty')::int;
    IF v_qty IS NULL OR v_qty < 1 OR v_qty > 99 THEN RAISE EXCEPTION 'invalid quantity'; END IF;

    SELECT * INTO v_item FROM public.catalog_items
      WHERE id = (v_line ->> 'item_id')::uuid AND store_id = p_store_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item does not belong to this store'; END IF;
    IF v_item.id = ANY (v_seen) THEN RAISE EXCEPTION 'duplicate item in cart'; END IF;
    v_seen := v_seen || v_item.id;
    IF NOT v_item.is_available THEN RAISE EXCEPTION 'item "%" is unavailable', v_item.name; END IF;

    IF EXISTS (SELECT 1 FROM public.inventory_items WHERE item_id = v_item.id) THEN
      UPDATE public.inventory_items
         SET stock_quantity = stock_quantity - v_qty
       WHERE item_id = v_item.id AND stock_quantity >= v_qty;
      IF NOT FOUND THEN RAISE EXCEPTION 'insufficient stock for "%"', v_item.name; END IF;
    END IF;

    INSERT INTO public.order_items (order_id, item_id, name, unit_price_paisa, quantity)
    VALUES (v_order_id, v_item.id, v_item.name, v_item.price_paisa, v_qty);
    v_subtotal := v_subtotal + v_item.price_paisa * v_qty;
  END LOOP;

  IF v_subtotal < v_store.min_order_paisa THEN
    RAISE EXCEPTION 'minimum order value for this store is NPR %', (v_store.min_order_paisa / 100.0);
  END IF;

  -- Option A: Free delivery waives the base 3 km delivery fee (NPR 50).
  -- If distance exceeds 3 km, customer pays only the extra distance fee (NPR 15/km).
  IF v_subtotal >= v_free_thresh THEN
    v_delivery := v_extra_km * v_per_km;
  ELSE
    v_delivery := v_base_fee + (v_extra_km * v_per_km);
  END IF;

  v_tax   := round((v_subtotal + v_delivery + v_platform) * v_vat / 10000.0);
  v_total := v_subtotal + v_delivery + v_platform + v_tax;
  v_status := CASE WHEN p_payment_method = 'cod' THEN 'acknowledged' ELSE 'draft' END;

  UPDATE public.orders
     SET subtotal_paisa = v_subtotal, delivery_fee_paisa = v_delivery,
         tax_paisa = v_tax, total_paisa = v_total, status = v_status
   WHERE id = v_order_id;

  INSERT INTO public.order_status_history (order_id, status, actor_id, note)
  VALUES (v_order_id, v_status, v_uid, 'order placed');

  INSERT INTO public.order_handoff_codes (order_id, code)
  VALUES (v_order_id, lpad((floor(random() * 10000))::int::text, 4, '0'));

  RETURN v_order_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Update post_order_settlement: Option A double-entry general ledger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_order_settlement()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store              public.stores;
  v_commission         BIGINT;
  v_driver_base        BIGINT;
  v_driver_bps         BIGINT;
  v_per_km             BIGINT;
  v_free_thresh        BIGINT;
  v_extra_km           INTEGER;
  v_extra_charged      BIGINT;
  v_driver_extra       BIGINT;
  v_rider_earning      BIGINT;
  v_platform_extra     BIGINT;
  v_delivery_margin    BIGINT;
  v_lines              JSONB;
BEGIN
  IF NEW.status <> 'delivered' OR OLD.status = 'delivered' THEN RETURN NEW; END IF;
  SELECT * INTO v_store FROM public.stores WHERE id = NEW.store_id;
  v_commission := round(NEW.subtotal_paisa * NEW.commission_bps / 10000.0);

  SELECT coalesce(value_int, 4000)   INTO v_driver_base FROM public.platform_settings WHERE key = 'driver_base_payout_paisa';
  SELECT coalesce(value_int, 8000)   INTO v_driver_bps  FROM public.platform_settings WHERE key = 'driver_extra_share_bps';
  SELECT coalesce(value_int, 1500)   INTO v_per_km      FROM public.platform_settings WHERE key = 'delivery_per_km_fee_paisa';
  SELECT coalesce(value_int, 100000) INTO v_free_thresh FROM public.platform_settings WHERE key = 'delivery_free_threshold_paisa';

  -- Calculate driver earnings: Rs 40 base + 80% of extra distance fee
  v_extra_km := GREATEST(0, ceil(NEW.delivery_distance_m / 1000.0)::int - 3);
  v_extra_charged := v_extra_km * v_per_km;
  v_driver_extra := round(v_extra_charged * v_driver_bps / 10000.0);
  v_rider_earning := v_driver_base + v_driver_extra;
  v_platform_extra := v_extra_charged - v_driver_extra; -- 20% of extra delivery fee

  IF NEW.rider_partner_id IS NULL THEN
    RAISE EXCEPTION 'cannot settle an order that has no rider';
  END IF;

  IF NEW.subtotal_paisa >= v_free_thresh THEN
    -- OPTION A: Orders >= Rs 1,000 have base 3km delivery waived.
    -- Platform subsidizes the base driver payout (Rs 40) as marketing expense.
    v_lines := jsonb_build_array(
      CASE WHEN NEW.payment_method = 'cod'
        THEN jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', NEW.rider_partner_id, 'direction', 'debit', 'amount', NEW.total_paisa)
        ELSE jsonb_build_object('account_type', 'gateway_clearing', 'direction', 'debit', 'amount', NEW.total_paisa) END,
      jsonb_build_object('account_type', 'marketing_expense', 'direction', 'debit',  'amount', NEW.discount_paisa + v_driver_base),
      jsonb_build_object('account_type', 'merchant_payable', 'account_id', v_store.partner_id, 'direction', 'credit', 'amount', NEW.subtotal_paisa - v_commission),
      jsonb_build_object('account_type', 'rider_payable', 'account_id', NEW.rider_partner_id, 'direction', 'credit', 'amount', v_rider_earning),
      jsonb_build_object('account_type', 'platform_revenue', 'direction', 'credit', 'amount', v_commission + NEW.platform_fee_paisa + v_platform_extra),
      jsonb_build_object('account_type', 'vat_payable',      'direction', 'credit', 'amount', NEW.tax_paisa));
  ELSE
    -- Orders < Rs 1,000: Customer paid base delivery (Rs 50) + extra fee.
    -- Platform retains Rs 10 base delivery margin + 20% extra fee share.
    v_delivery_margin := NEW.delivery_fee_paisa - v_rider_earning;
    v_lines := jsonb_build_array(
      CASE WHEN NEW.payment_method = 'cod'
        THEN jsonb_build_object('account_type', 'rider_cash_in_hand', 'account_id', NEW.rider_partner_id, 'direction', 'debit', 'amount', NEW.total_paisa)
        ELSE jsonb_build_object('account_type', 'gateway_clearing', 'direction', 'debit', 'amount', NEW.total_paisa) END,
      jsonb_build_object('account_type', 'marketing_expense', 'direction', 'debit',  'amount', NEW.discount_paisa),
      jsonb_build_object('account_type', 'merchant_payable', 'account_id', v_store.partner_id, 'direction', 'credit', 'amount', NEW.subtotal_paisa - v_commission),
      jsonb_build_object('account_type', 'rider_payable', 'account_id', NEW.rider_partner_id, 'direction', 'credit', 'amount', v_rider_earning),
      jsonb_build_object('account_type', 'platform_revenue', 'direction', 'credit', 'amount', v_commission + NEW.platform_fee_paisa + v_delivery_margin),
      jsonb_build_object('account_type', 'vat_payable',      'direction', 'credit', 'amount', NEW.tax_paisa));
  END IF;

  PERFORM public.post_ledger_group('order', NEW.id, 'order #' || NEW.order_no || ' delivered', v_lines);

  IF NEW.payment_method = 'cod' THEN
    UPDATE public.rider_details SET cod_cash_in_hand_paisa = cod_cash_in_hand_paisa + NEW.total_paisa
     WHERE partner_id = NEW.rider_partner_id;
  END IF;
  RETURN NEW;
END;
$$;

