-- =============================================================================
-- 0004 — Catalog, inventory, orders & fulfilment (food + grocery quick-commerce)
-- Money is ALWAYS stored as integer paisa (1 NPR = 100 paisa). The client never
-- decides a total: place_order() prices everything server-side.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Platform settings (admin-tunable pricing knobs)
-- ---------------------------------------------------------------------------
CREATE TABLE public.platform_settings (
  key         TEXT PRIMARY KEY,
  value_int   BIGINT NOT NULL,
  description TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER platform_settings_updated_at BEFORE UPDATE ON public.platform_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO public.platform_settings (key, value_int, description) VALUES
  ('delivery_base_fee_paisa',   4000, 'Flat delivery fee for the first km'),
  ('delivery_per_km_fee_paisa', 1500, 'Additional delivery fee per started km after the first'),
  ('platform_fee_paisa',         500, 'Per-order platform/service fee charged to the customer'),
  ('vat_bps',                   1300, 'VAT in basis points (13%) applied to goods + fees'),
  ('max_delivery_radius_m',    12000, 'Orders beyond this distance from the store are rejected');

-- ---------------------------------------------------------------------------
-- Stores (a partner may run several outlets)
-- ---------------------------------------------------------------------------
CREATE TABLE public.stores (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id       UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  category         public.store_category NOT NULL,
  name             TEXT NOT NULL,
  name_ne          TEXT,
  description      TEXT,
  cover_path       TEXT,
  local_level_id   SMALLINT NOT NULL REFERENCES public.local_levels(id),
  ward_no          SMALLINT CHECK (ward_no BETWEEN 1 AND 35),
  address_text     TEXT,
  location         extensions.geography(Point, 4326) NOT NULL,
  opening_hours    JSONB NOT NULL DEFAULT '{}'::jsonb,   -- {"mon":[["09:00","21:00"]], ...}
  is_open          BOOLEAN NOT NULL DEFAULT TRUE,        -- manual open/close toggle
  min_order_paisa  BIGINT NOT NULL DEFAULT 0 CHECK (min_order_paisa >= 0),
  rating_avg       NUMERIC(3,2) NOT NULL DEFAULT 0,
  rating_count     INTEGER NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX stores_partner_idx ON public.stores (partner_id);
CREATE INDEX stores_geo_idx     ON public.stores USING gist (location);
CREATE INDEX stores_name_trgm   ON public.stores USING gin (name extensions.gin_trgm_ops);
CREATE TRIGGER stores_updated_at BEFORE UPDATE ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A store can only be created for a partner of a matching, product-selling type.
CREATE OR REPLACE FUNCTION public.check_store_partner()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE v_type public.partner_type;
BEGIN
  SELECT type INTO v_type FROM public.partner_profiles WHERE id = NEW.partner_id;
  IF v_type IS NULL OR v_type NOT IN ('restaurant', 'grocery') THEN
    RAISE EXCEPTION 'stores can only belong to restaurant or grocery partners';
  END IF;
  IF (v_type = 'restaurant' AND NEW.category <> 'food')
     OR (v_type = 'grocery' AND NEW.category <> 'grocery') THEN
    RAISE EXCEPTION 'store category does not match partner type';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER stores_check_partner BEFORE INSERT OR UPDATE OF partner_id, category ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.check_store_partner();

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
CREATE TABLE public.catalog_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  section       TEXT,                              -- menu section / grocery aisle
  name          TEXT NOT NULL,
  name_ne       TEXT,
  description   TEXT,
  price_paisa   BIGINT NOT NULL CHECK (price_paisa >= 0),
  image_path    TEXT,
  tags          TEXT[] NOT NULL DEFAULT '{}',      -- 'veg','spicy','halal','peanut'...
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  search_tsv    tsvector GENERATED ALWAYS AS (
                  to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(name_ne, '') || ' ' || coalesce(description, ''))
                ) STORED,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX catalog_items_store_idx ON public.catalog_items (store_id);
CREATE INDEX catalog_items_tsv_idx   ON public.catalog_items USING gin (search_tsv);
CREATE INDEX catalog_items_trgm_idx  ON public.catalog_items USING gin (name extensions.gin_trgm_ops);
CREATE TRIGGER catalog_items_updated_at BEFORE UPDATE ON public.catalog_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Optional per-item stock tracking (grocery). No row = untracked / unlimited (restaurants).
CREATE TABLE public.inventory_items (
  item_id        UUID PRIMARY KEY REFERENCES public.catalog_items(id) ON DELETE CASCADE,
  stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER inventory_items_updated_at BEFORE UPDATE ON public.inventory_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------
CREATE TABLE public.orders (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no             BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 10000) UNIQUE,
  consumer_id          UUID NOT NULL REFERENCES public.profiles(id),
  store_id             UUID NOT NULL REFERENCES public.stores(id),
  rider_partner_id     UUID REFERENCES public.partner_profiles(id),
  status               public.order_status NOT NULL DEFAULT 'draft',
  payment_method       public.payment_method NOT NULL,
  subtotal_paisa       BIGINT NOT NULL CHECK (subtotal_paisa >= 0),
  delivery_fee_paisa   BIGINT NOT NULL CHECK (delivery_fee_paisa >= 0),
  platform_fee_paisa   BIGINT NOT NULL CHECK (platform_fee_paisa >= 0),
  tax_paisa            BIGINT NOT NULL CHECK (tax_paisa >= 0),
  discount_paisa       BIGINT NOT NULL DEFAULT 0 CHECK (discount_paisa >= 0),
  total_paisa          BIGINT NOT NULL CHECK (total_paisa >= 0),
  commission_bps       INTEGER NOT NULL,                       -- snapshot at order time
  delivery_address     JSONB NOT NULL,                         -- snapshot (address edits don't rewrite history)
  delivery_location    extensions.geography(Point, 4326) NOT NULL,
  delivery_distance_m  INTEGER NOT NULL,
  customer_note        TEXT,
  cancel_reason        TEXT,
  placed_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at         TIMESTAMPTZ,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT orders_total_consistent CHECK (
    total_paisa = subtotal_paisa + delivery_fee_paisa + platform_fee_paisa + tax_paisa - discount_paisa
  )
);
CREATE INDEX orders_consumer_idx ON public.orders (consumer_id, placed_at DESC);
CREATE INDEX orders_store_idx    ON public.orders (store_id, status);
CREATE INDEX orders_rider_idx    ON public.orders (rider_partner_id, status);
CREATE INDEX orders_open_idx     ON public.orders (status) WHERE status IN ('ready_for_pickup', 'preparing');
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Price/name snapshots so history survives menu edits.
CREATE TABLE public.order_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id         UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  item_id          UUID REFERENCES public.catalog_items(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  unit_price_paisa BIGINT NOT NULL CHECK (unit_price_paisa >= 0),
  quantity         INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 99),
  line_total_paisa BIGINT GENERATED ALWAYS AS (unit_price_paisa * quantity) STORED
);
CREATE INDEX order_items_order_idx ON public.order_items (order_id);
CREATE INDEX order_items_item_idx  ON public.order_items (item_id);   -- AI habit analytics

CREATE TABLE public.order_status_history (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id    UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  status      public.order_status NOT NULL,
  actor_id    UUID REFERENCES public.profiles(id),
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX order_status_history_order_idx ON public.order_status_history (order_id, created_at);
CREATE TRIGGER order_status_history_immutable BEFORE UPDATE OR DELETE ON public.order_status_history
  FOR EACH ROW EXECUTE FUNCTION public.reject_mutation();

-- COD / handover OTP — only the consumer can read it; riders verify via RPC.
CREATE TABLE public.order_handoff_codes (
  order_id UUID PRIMARY KEY REFERENCES public.orders(id) ON DELETE CASCADE,
  code     TEXT NOT NULL CHECK (code ~ '^[0-9]{4}$'),
  attempts SMALLINT NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------------
-- place_order — the ONLY way to create an order
-- p_items: [{"item_id": "<uuid>", "qty": 2}, ...]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order(
  p_store_id       UUID,
  p_items          JSONB,
  p_payment_method public.payment_method,
  p_address_id     UUID,
  p_note           TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_profile    public.profiles;
  v_store      public.stores;
  v_partner    public.partner_profiles;
  v_addr       public.user_addresses;
  v_line       JSONB;
  v_item       public.catalog_items;
  v_qty        INT;
  v_subtotal   BIGINT := 0;
  v_dist_m     INT;
  v_delivery   BIGINT;
  v_platform   BIGINT;
  v_tax        BIGINT;
  v_total      BIGINT;
  v_order_id   UUID;
  v_status     public.order_status;
  v_base       BIGINT; v_per_km BIGINT; v_vat BIGINT; v_radius BIGINT;
  v_seen       UUID[] := '{}';
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF NOT public.is_account_active(v_uid) THEN
    RAISE EXCEPTION 'account is not active' USING ERRCODE = '42501';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'cart is empty';
  END IF;
  IF jsonb_array_length(p_items) > 60 THEN RAISE EXCEPTION 'too many line items'; END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid;
  IF p_payment_method = 'cod' AND NOT v_profile.cod_enabled THEN
    RAISE EXCEPTION 'cash on delivery is disabled for this account' USING ERRCODE = '42501';
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

  SELECT value_int INTO v_base   FROM public.platform_settings WHERE key = 'delivery_base_fee_paisa';
  SELECT value_int INTO v_per_km FROM public.platform_settings WHERE key = 'delivery_per_km_fee_paisa';
  SELECT value_int INTO v_platform FROM public.platform_settings WHERE key = 'platform_fee_paisa';
  SELECT value_int INTO v_vat    FROM public.platform_settings WHERE key = 'vat_bps';
  SELECT value_int INTO v_radius FROM public.platform_settings WHERE key = 'max_delivery_radius_m';

  v_dist_m := round(ST_Distance(v_store.location, v_addr.location))::int;
  IF v_dist_m > v_radius THEN RAISE EXCEPTION 'address is outside the delivery radius'; END IF;
  v_delivery := v_base + GREATEST(0, ceil(v_dist_m / 1000.0)::int - 1) * v_per_km;

  -- Insert the order shell first (totals patched after pricing) so order_items can reference it.
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

    -- Atomic stock deduction (row lock via UPDATE ... WHERE stock >= qty)
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

  v_tax   := round((v_subtotal + v_delivery + v_platform) * v_vat / 10000.0);
  v_total := v_subtotal + v_delivery + v_platform + v_tax;
  -- COD is confirmed immediately; prepaid orders stay `draft` until the
  -- gateway webhook verifies payment (see confirm_order_payment in 0006).
  v_status := CASE WHEN p_payment_method = 'cod' THEN 'acknowledged' ELSE 'draft' END;

  UPDATE public.orders
     SET subtotal_paisa = v_subtotal, tax_paisa = v_tax, total_paisa = v_total, status = v_status
   WHERE id = v_order_id;

  INSERT INTO public.order_status_history (order_id, status, actor_id, note)
  VALUES (v_order_id, v_status, v_uid, 'order placed');

  INSERT INTO public.order_handoff_codes (order_id, code)
  VALUES (v_order_id, lpad((floor(random() * 10000))::int::text, 4, '0'));

  RETURN v_order_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- advance_order_status — validated state machine (clients have no UPDATE on orders)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.advance_order_status(
  p_order UUID, p_new public.order_status, p_note TEXT DEFAULT NULL, p_otp TEXT DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_o     public.orders;
  v_store public.stores;
  v_code  public.order_handoff_codes;
  v_is_store BOOLEAN; v_is_rider BOOLEAN; v_is_consumer BOOLEAN; v_is_admin BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;

  SELECT * INTO v_o FROM public.orders WHERE id = p_order FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'order not found'; END IF;
  SELECT * INTO v_store FROM public.stores WHERE id = v_o.store_id;

  v_is_admin    := public.is_admin();
  v_is_consumer := v_o.consumer_id = v_uid;
  v_is_store    := public.is_partner_member(v_store.partner_id, ARRAY['owner', 'manager', 'cashier']);
  v_is_rider    := v_o.rider_partner_id IS NOT NULL AND public.is_partner_member(v_o.rider_partner_id);

  IF v_o.status = p_new THEN RETURN; END IF;     -- idempotent

  IF NOT (
       (v_is_admin)
    OR (v_is_store    AND ((v_o.status = 'acknowledged'     AND p_new IN ('preparing', 'rejected'))
                        OR (v_o.status = 'preparing'        AND p_new IN ('ready_for_pickup', 'rejected'))))
    OR (v_is_rider    AND ((v_o.status = 'ready_for_pickup' AND p_new = 'dispatched')
                        OR (v_o.status = 'dispatched'       AND p_new = 'delivered')))
    OR (v_is_consumer AND  v_o.status IN ('draft', 'acknowledged') AND p_new = 'cancelled')
  ) THEN
    RAISE EXCEPTION 'transition % -> % is not permitted for this user', v_o.status, p_new USING ERRCODE = '42501';
  END IF;

  IF p_new = 'delivered' AND NOT v_is_admin THEN
    -- Every delivery requires the 4-digit handoff code (COD and prepaid alike).
    SELECT * INTO v_code FROM public.order_handoff_codes WHERE order_id = p_order FOR UPDATE;
    IF v_code.attempts >= 5 THEN RAISE EXCEPTION 'too many incorrect codes; contact support'; END IF;
    IF p_otp IS NULL OR p_otp <> v_code.code THEN
      UPDATE public.order_handoff_codes SET attempts = attempts + 1 WHERE order_id = p_order;
      RAISE EXCEPTION 'incorrect handoff code';
    END IF;
  END IF;

  -- Return stock when an order dies before it is cooked/dispatched.
  IF p_new IN ('cancelled', 'rejected') THEN
    UPDATE public.inventory_items inv
       SET stock_quantity = inv.stock_quantity + oi.quantity
      FROM public.order_items oi
     WHERE oi.order_id = p_order AND oi.item_id = inv.item_id;
  END IF;

  UPDATE public.orders
     SET status = p_new,
         cancel_reason = CASE WHEN p_new IN ('cancelled', 'rejected') THEN p_note ELSE cancel_reason END,
         delivered_at = CASE WHEN p_new = 'delivered' THEN now() ELSE delivered_at END
   WHERE id = p_order;

  INSERT INTO public.order_status_history (order_id, status, actor_id, note)
  VALUES (p_order, p_new, v_uid, p_note);
END;
$$;

-- Riders claim an unassigned order that the kitchen is preparing / has ready.
CREATE OR REPLACE FUNCTION public.claim_order(p_order UUID, p_rider_partner UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_rows INT;
BEGIN
  IF NOT public.is_partner_member(p_rider_partner, ARRAY['owner']) THEN
    RAISE EXCEPTION 'not your rider profile' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.partner_profiles WHERE id = p_rider_partner AND type = 'rider' AND status = 'active') THEN
    RAISE EXCEPTION 'rider is not verified';
  END IF;
  UPDATE public.orders SET rider_partner_id = p_rider_partner
   WHERE id = p_order AND rider_partner_id IS NULL AND status IN ('preparing', 'ready_for_pickup');
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN RAISE EXCEPTION 'order is no longer available'; END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.platform_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_handoff_codes   ENABLE ROW LEVEL SECURITY;

CREATE POLICY settings_read  ON public.platform_settings FOR SELECT USING (true);
CREATE POLICY settings_admin ON public.platform_settings FOR UPDATE
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Stores/catalog are public only while their partner is ACTIVE.
CREATE POLICY stores_select ON public.stores FOR SELECT
  USING (public.is_active_partner(partner_id) OR public.is_partner_member(partner_id) OR public.is_admin());
CREATE POLICY stores_write ON public.stores FOR ALL
  USING (public.is_partner_member(partner_id, ARRAY['owner', 'manager']))
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner', 'manager']));

CREATE POLICY catalog_select ON public.catalog_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.stores s
                 WHERE s.id = store_id
                   AND (public.is_active_partner(s.partner_id) OR public.is_partner_member(s.partner_id) OR public.is_admin())));
CREATE POLICY catalog_write ON public.catalog_items FOR ALL
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_id AND public.is_partner_member(s.partner_id, ARRAY['owner', 'manager'])))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_id AND public.is_partner_member(s.partner_id, ARRAY['owner', 'manager'])));

CREATE POLICY inventory_select ON public.inventory_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.catalog_items c JOIN public.stores s ON s.id = c.store_id
                 WHERE c.id = item_id AND (public.is_partner_member(s.partner_id) OR public.is_admin())));
CREATE POLICY inventory_write ON public.inventory_items FOR ALL
  USING (EXISTS (SELECT 1 FROM public.catalog_items c JOIN public.stores s ON s.id = c.store_id
                 WHERE c.id = item_id AND public.is_partner_member(s.partner_id, ARRAY['owner', 'manager'])))
  WITH CHECK (EXISTS (SELECT 1 FROM public.catalog_items c JOIN public.stores s ON s.id = c.store_id
                 WHERE c.id = item_id AND public.is_partner_member(s.partner_id, ARRAY['owner', 'manager'])));

-- Orders: read-only for clients (all mutation goes through the RPCs above).
CREATE POLICY orders_select ON public.orders FOR SELECT
  USING (
    consumer_id = auth.uid()
    OR public.is_admin()
    OR (rider_partner_id IS NOT NULL AND public.is_partner_member(rider_partner_id))
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_id AND public.is_partner_member(s.partner_id))
    -- Unclaimed, cookable orders are visible to verified riders so they can claim them.
    OR (rider_partner_id IS NULL AND status IN ('preparing', 'ready_for_pickup')
        AND EXISTS (SELECT 1 FROM public.partner_members pm JOIN public.partner_profiles pp ON pp.id = pm.partner_id
                    WHERE pm.user_id = auth.uid() AND pp.type = 'rider' AND pp.status = 'active'))
  );

CREATE POLICY order_items_select ON public.order_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id));   -- inherits orders RLS

CREATE POLICY order_history_select ON public.order_status_history FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id));

CREATE POLICY handoff_consumer_only ON public.order_handoff_codes FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND o.consumer_id = auth.uid()));
