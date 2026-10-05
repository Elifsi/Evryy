-- =============================================================================
-- 0005 — Stays (hotels), long-term room rentals & ride-hailing (bidding model)
-- Vehicle-fleet rentals are intentionally NOT modelled here (deferred to Phase 2).
-- =============================================================================

INSERT INTO public.platform_settings (key, value_int, description) VALUES
  ('ride_min_fare_paisa',        5000, 'Floor for any offered ride fare'),
  ('ride_min_per_km_paisa',      1200, 'Minimum offered fare per km (anti-undercut guard)'),
  ('stay_service_fee_bps',        500, 'Guest-side booking fee on stays (5%)'),
  ('driver_nearby_radius_m',     5000, 'Drivers see ride requests inside this radius');

-- ===========================================================================
-- HOTELS & HOMESTAYS
-- ===========================================================================
CREATE TABLE public.properties (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id      UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  kind            TEXT NOT NULL CHECK (kind IN ('hotel', 'homestay', 'resort', 'guesthouse')),
  name            TEXT NOT NULL,
  description     TEXT,
  amenities       TEXT[] NOT NULL DEFAULT '{}',
  photos          TEXT[] NOT NULL DEFAULT '{}',
  local_level_id  SMALLINT NOT NULL REFERENCES public.local_levels(id),
  ward_no         SMALLINT CHECK (ward_no BETWEEN 1 AND 35),
  address_text    TEXT,
  location        extensions.geography(Point, 4326) NOT NULL,
  check_in_time   TIME NOT NULL DEFAULT '14:00',
  check_out_time  TIME NOT NULL DEFAULT '11:00',
  rating_avg      NUMERIC(3,2) NOT NULL DEFAULT 0,
  rating_count    INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX properties_partner_idx ON public.properties (partner_id);
CREATE INDEX properties_geo_idx     ON public.properties USING gist (location);
CREATE TRIGGER properties_updated_at BEFORE UPDATE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.check_property_partner()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.partner_profiles WHERE id = NEW.partner_id AND type = 'hotel') THEN
    RAISE EXCEPTION 'properties can only belong to hotel partners';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER properties_check_partner BEFORE INSERT OR UPDATE OF partner_id ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.check_property_partner();

CREATE TABLE public.rooms (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id            UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  name                   TEXT NOT NULL,
  capacity_adults        SMALLINT NOT NULL DEFAULT 2 CHECK (capacity_adults BETWEEN 1 AND 20),
  capacity_children      SMALLINT NOT NULL DEFAULT 0 CHECK (capacity_children BETWEEN 0 AND 20),
  price_per_night_paisa  BIGINT NOT NULL CHECK (price_per_night_paisa > 0),
  amenities              TEXT[] NOT NULL DEFAULT '{}',
  photos                 TEXT[] NOT NULL DEFAULT '{}',
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX rooms_property_idx ON public.rooms (property_id);

CREATE TABLE public.room_reservations (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id             UUID NOT NULL REFERENCES public.rooms(id),
  guest_id            UUID NOT NULL REFERENCES public.profiles(id),
  reservation_period  daterange NOT NULL,                       -- [check_in, check_out)
  adults              SMALLINT NOT NULL CHECK (adults >= 1),
  children            SMALLINT NOT NULL DEFAULT 0 CHECK (children >= 0),
  status              public.reservation_status NOT NULL DEFAULT 'pending',
  nightly_rate_paisa  BIGINT NOT NULL,
  subtotal_paisa      BIGINT NOT NULL,
  service_fee_paisa   BIGINT NOT NULL,
  total_paisa         BIGINT NOT NULL,
  commission_bps      INTEGER NOT NULL,
  guest_note          TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT reservation_period_valid CHECK (
    NOT isempty(reservation_period)
    AND lower_inc(reservation_period) AND NOT upper_inc(reservation_period)
    AND upper(reservation_period) - lower(reservation_period) BETWEEN 1 AND 60
  ),
  -- The database itself makes double-booking impossible, even under concurrency.
  CONSTRAINT no_double_booking EXCLUDE USING gist (
    room_id WITH =, reservation_period WITH &&
  ) WHERE (status IN ('pending', 'confirmed', 'checked_in'))
);
CREATE INDEX room_reservations_guest_idx ON public.room_reservations (guest_id, created_at DESC);
CREATE TRIGGER room_reservations_updated_at BEFORE UPDATE ON public.room_reservations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.book_room(
  p_room UUID, p_check_in DATE, p_check_out DATE,
  p_adults SMALLINT, p_children SMALLINT DEFAULT 0, p_note TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_room public.rooms;
  v_prop public.properties;
  v_partner public.partner_profiles;
  v_nights INT := p_check_out - p_check_in;
  v_sub BIGINT; v_fee BIGINT; v_fee_bps BIGINT; v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF NOT public.is_account_active(v_uid) THEN RAISE EXCEPTION 'account is not active' USING ERRCODE = '42501'; END IF;
  IF p_check_in < current_date THEN RAISE EXCEPTION 'check-in date is in the past'; END IF;
  IF v_nights < 1 OR v_nights > 60 THEN RAISE EXCEPTION 'stay must be between 1 and 60 nights'; END IF;

  SELECT * INTO v_room FROM public.rooms WHERE id = p_room AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'room not available'; END IF;
  SELECT * INTO v_prop FROM public.properties WHERE id = v_room.property_id;
  SELECT * INTO v_partner FROM public.partner_profiles WHERE id = v_prop.partner_id;
  IF v_partner.status <> 'active' THEN RAISE EXCEPTION 'property is not accepting bookings'; END IF;
  IF public.is_service_blocked(v_prop.local_level_id, v_prop.ward_no, 'stays') THEN
    RAISE EXCEPTION 'service is temporarily unavailable in this area';
  END IF;
  IF p_adults > v_room.capacity_adults OR p_children > v_room.capacity_children THEN
    RAISE EXCEPTION 'room capacity exceeded';
  END IF;

  SELECT value_int INTO v_fee_bps FROM public.platform_settings WHERE key = 'stay_service_fee_bps';
  v_sub := v_room.price_per_night_paisa * v_nights;
  v_fee := round(v_sub * v_fee_bps / 10000.0);

  BEGIN
    INSERT INTO public.room_reservations (
      room_id, guest_id, reservation_period, adults, children,
      nightly_rate_paisa, subtotal_paisa, service_fee_paisa, total_paisa, commission_bps, guest_note
    ) VALUES (
      p_room, v_uid, daterange(p_check_in, p_check_out, '[)'), p_adults, p_children,
      v_room.price_per_night_paisa, v_sub, v_fee, v_sub + v_fee, v_partner.commission_bps, p_note
    ) RETURNING id INTO v_id;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'room is already booked for those dates' USING ERRCODE = '23P01';
  END;
  RETURN v_id;
END;
$$;

-- ===========================================================================
-- LONG-TERM ROOM / FLAT RENTALS  (gharbeti listings; lead-gen model)
-- ===========================================================================
CREATE TABLE public.room_listings (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_partner_id   UUID NOT NULL REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  description           TEXT,
  layout                TEXT NOT NULL CHECK (layout IN ('single_room', '1rk', '1bhk', '2bhk', '3bhk', 'flat', 'house')),
  rent_per_month_paisa  BIGINT NOT NULL CHECK (rent_per_month_paisa > 0),
  deposit_paisa         BIGINT NOT NULL DEFAULT 0 CHECK (deposit_paisa >= 0),
  tenant_preference     TEXT[] NOT NULL DEFAULT '{}',   -- 'family','bachelor','student','female_only'
  utilities             TEXT[] NOT NULL DEFAULT '{}',   -- 'water','parking','wifi','electricity_included'
  photos                TEXT[] NOT NULL DEFAULT '{}',
  local_level_id        SMALLINT NOT NULL REFERENCES public.local_levels(id),
  ward_no               SMALLINT CHECK (ward_no BETWEEN 1 AND 35),
  address_text          TEXT,
  location              extensions.geography(Point, 4326) NOT NULL,
  is_available          BOOLEAN NOT NULL DEFAULT TRUE,
  available_from        DATE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX room_listings_landlord_idx ON public.room_listings (landlord_partner_id);
CREATE INDEX room_listings_geo_idx      ON public.room_listings USING gist (location);
CREATE INDEX room_listings_browse_idx   ON public.room_listings (local_level_id, ward_no) WHERE is_available;
CREATE TRIGGER room_listings_updated_at BEFORE UPDATE ON public.room_listings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.check_listing_partner()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.partner_profiles WHERE id = NEW.landlord_partner_id AND type = 'landlord') THEN
    RAISE EXCEPTION 'listings can only belong to landlord partners';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER room_listings_check_partner BEFORE INSERT OR UPDATE OF landlord_partner_id ON public.room_listings
  FOR EACH ROW EXECUTE FUNCTION public.check_listing_partner();

-- A tenant enquiry opens a chat with the landlord (chat itself lives in 0007).
CREATE TABLE public.room_enquiries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id  UUID NOT NULL REFERENCES public.room_listings(id) ON DELETE CASCADE,
  tenant_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message     TEXT,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'viewing_scheduled', 'closed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (listing_id, tenant_id)
);

-- ===========================================================================
-- RIDES (bike / scooter / car) with inDrive-style fare bidding
-- ===========================================================================
CREATE TABLE public.driver_locations (
  partner_id  UUID PRIMARY KEY REFERENCES public.partner_profiles(id) ON DELETE CASCADE,
  location    extensions.geography(Point, 4326) NOT NULL,
  bearing     SMALLINT CHECK (bearing BETWEEN 0 AND 359),
  speed_kmh   SMALLINT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX driver_locations_geo_idx ON public.driver_locations USING gist (location);

CREATE TABLE public.rides (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id         UUID NOT NULL REFERENCES public.profiles(id),
  driver_partner_id    UUID REFERENCES public.partner_profiles(id),
  vehicle_type         public.vehicle_type NOT NULL,
  status               public.ride_status NOT NULL DEFAULT 'bidding',
  pickup_location      extensions.geography(Point, 4326) NOT NULL,
  pickup_label         TEXT,
  dropoff_location     extensions.geography(Point, 4326) NOT NULL,
  dropoff_label        TEXT,
  distance_m           INTEGER NOT NULL CHECK (distance_m > 0),
  route_polyline       TEXT,                               -- OSRM encoded polyline
  offered_fare_paisa   BIGINT NOT NULL CHECK (offered_fare_paisa > 0),
  final_fare_paisa     BIGINT CHECK (final_fare_paisa > 0),
  commission_bps       INTEGER,
  payment_method       public.payment_method NOT NULL DEFAULT 'cod',
  start_otp            TEXT CHECK (start_otp ~ '^[0-9]{4}$'),
  cancel_reason        TEXT,
  requested_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at          TIMESTAMPTZ,
  started_at           TIMESTAMPTZ,
  completed_at         TIMESTAMPTZ,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX rides_passenger_idx ON public.rides (passenger_id, requested_at DESC);
CREATE INDEX rides_driver_idx    ON public.rides (driver_partner_id, status);
CREATE INDEX rides_open_geo_idx  ON public.rides USING gist (pickup_location) WHERE status = 'bidding';
CREATE TRIGGER rides_updated_at BEFORE UPDATE ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.ride_bids (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id              UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  driver_partner_id    UUID NOT NULL REFERENCES public.partner_profiles(id),
  counter_fare_paisa   BIGINT NOT NULL CHECK (counter_fare_paisa > 0),
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'withdrawn')),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (ride_id, driver_partner_id)
);
CREATE INDEX ride_bids_ride_idx ON public.ride_bids (ride_id, status);

CREATE OR REPLACE FUNCTION public.request_ride(
  p_vehicle public.vehicle_type,
  p_pickup_lat DOUBLE PRECISION, p_pickup_lng DOUBLE PRECISION, p_pickup_label TEXT,
  p_drop_lat DOUBLE PRECISION,   p_drop_lng DOUBLE PRECISION,   p_drop_label TEXT,
  p_distance_m INTEGER, p_polyline TEXT, p_offered_fare_paisa BIGINT,
  p_payment_method public.payment_method DEFAULT 'cod'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_floor BIGINT; v_per_km BIGINT; v_min BIGINT; v_id UUID;
  v_pick extensions.geography; v_drop extensions.geography;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  IF NOT public.is_account_active(v_uid) THEN RAISE EXCEPTION 'account is not active' USING ERRCODE = '42501'; END IF;
  IF p_payment_method = 'cod' AND NOT (SELECT cod_enabled FROM public.profiles WHERE id = v_uid) THEN
    RAISE EXCEPTION 'cash payment is disabled for this account' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM public.rides WHERE passenger_id = v_uid AND status IN ('requested', 'bidding', 'accepted', 'arrived', 'in_progress')) THEN
    RAISE EXCEPTION 'you already have an active ride';
  END IF;

  v_pick := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  v_drop := ST_SetSRID(ST_MakePoint(p_drop_lng, p_drop_lat), 4326)::geography;

  -- Never trust a client-supplied distance blindly: it must be at least the straight-line distance
  -- and not absurdly larger (road distance is rarely >3x crow-flies in Nepal's cities).
  IF p_distance_m < ST_Distance(v_pick, v_drop) * 0.95 OR p_distance_m > GREATEST(ST_Distance(v_pick, v_drop) * 3, 1500) THEN
    RAISE EXCEPTION 'implausible route distance';
  END IF;

  SELECT value_int INTO v_floor  FROM public.platform_settings WHERE key = 'ride_min_fare_paisa';
  SELECT value_int INTO v_per_km FROM public.platform_settings WHERE key = 'ride_min_per_km_paisa';
  v_min := GREATEST(v_floor, round(p_distance_m / 1000.0 * v_per_km));
  IF p_offered_fare_paisa < v_min THEN
    RAISE EXCEPTION 'offered fare is below the minimum of NPR %', (v_min / 100.0);
  END IF;

  INSERT INTO public.rides (
    passenger_id, vehicle_type, pickup_location, pickup_label, dropoff_location, dropoff_label,
    distance_m, route_polyline, offered_fare_paisa, payment_method, start_otp
  ) VALUES (
    v_uid, p_vehicle, v_pick, p_pickup_label, v_drop, p_drop_label,
    p_distance_m, p_polyline, p_offered_fare_paisa, p_payment_method,
    lpad((floor(random() * 10000))::int::text, 4, '0')
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.place_ride_bid(p_ride UUID, p_driver_partner UUID, p_fare_paisa BIGINT)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_ride public.rides; v_id UUID; v_radius BIGINT; v_rd public.rider_details;
BEGIN
  IF NOT public.is_partner_member(p_driver_partner, ARRAY['owner']) THEN
    RAISE EXCEPTION 'not your driver profile' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.partner_profiles WHERE id = p_driver_partner AND type IN ('driver', 'rider') AND status = 'active') THEN
    RAISE EXCEPTION 'driver is not verified';
  END IF;
  SELECT * INTO v_rd FROM public.rider_details WHERE partner_id = p_driver_partner;
  IF NOT FOUND OR NOT v_rd.is_online THEN RAISE EXCEPTION 'go online before bidding'; END IF;
  IF v_rd.license_expiry < current_date THEN RAISE EXCEPTION 'driving licence has expired'; END IF;

  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride;
  IF NOT FOUND OR v_ride.status <> 'bidding' THEN RAISE EXCEPTION 'ride is no longer open'; END IF;
  IF v_ride.vehicle_type <> v_rd.vehicle_type THEN RAISE EXCEPTION 'vehicle type does not match this ride'; END IF;

  SELECT value_int INTO v_radius FROM public.platform_settings WHERE key = 'driver_nearby_radius_m';
  IF NOT EXISTS (SELECT 1 FROM public.driver_locations dl
                 WHERE dl.partner_id = p_driver_partner
                   AND ST_DWithin(dl.location, v_ride.pickup_location, v_radius)
                   AND dl.updated_at > now() - interval '2 minutes') THEN
    RAISE EXCEPTION 'you are too far from the pickup point';
  END IF;

  INSERT INTO public.ride_bids (ride_id, driver_partner_id, counter_fare_paisa)
  VALUES (p_ride, p_driver_partner, p_fare_paisa)
  ON CONFLICT (ride_id, driver_partner_id)
    DO UPDATE SET counter_fare_paisa = EXCLUDED.counter_fare_paisa, status = 'pending'
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_ride_bid(p_bid UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bid public.ride_bids; v_ride public.rides; v_partner public.partner_profiles;
BEGIN
  SELECT * INTO v_bid FROM public.ride_bids WHERE id = p_bid;
  IF NOT FOUND THEN RAISE EXCEPTION 'bid not found'; END IF;

  SELECT * INTO v_ride FROM public.rides WHERE id = v_bid.ride_id FOR UPDATE;
  IF v_ride.passenger_id <> auth.uid() THEN RAISE EXCEPTION 'not your ride' USING ERRCODE = '42501'; END IF;
  IF v_ride.status <> 'bidding' OR v_bid.status <> 'pending' THEN RAISE EXCEPTION 'bid is no longer valid'; END IF;

  SELECT * INTO v_partner FROM public.partner_profiles WHERE id = v_bid.driver_partner_id;
  IF v_partner.status <> 'active' THEN RAISE EXCEPTION 'driver is not active'; END IF;
  IF EXISTS (SELECT 1 FROM public.rides WHERE driver_partner_id = v_bid.driver_partner_id
             AND status IN ('accepted', 'arrived', 'in_progress')) THEN
    RAISE EXCEPTION 'driver was just assigned another ride';
  END IF;

  UPDATE public.ride_bids SET status = CASE WHEN id = p_bid THEN 'accepted' ELSE 'rejected' END
   WHERE ride_id = v_ride.id AND status = 'pending';
  UPDATE public.rides
     SET status = 'accepted', driver_partner_id = v_bid.driver_partner_id,
         final_fare_paisa = v_bid.counter_fare_paisa, commission_bps = v_partner.commission_bps,
         accepted_at = now()
   WHERE id = v_ride.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.advance_ride_status(p_ride UUID, p_new public.ride_status, p_otp TEXT DEFAULT NULL, p_note TEXT DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid(); v_r public.rides;
  v_is_driver BOOLEAN; v_is_pax BOOLEAN;
BEGIN
  SELECT * INTO v_r FROM public.rides WHERE id = p_ride FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ride not found'; END IF;
  v_is_pax := v_r.passenger_id = v_uid;
  v_is_driver := v_r.driver_partner_id IS NOT NULL AND public.is_partner_member(v_r.driver_partner_id, ARRAY['owner']);
  IF v_r.status = p_new THEN RETURN; END IF;

  IF NOT (
       public.is_admin()
    OR (v_is_driver AND ((v_r.status = 'accepted'    AND p_new = 'arrived')
                      OR (v_r.status = 'arrived'     AND p_new = 'in_progress')
                      OR (v_r.status = 'in_progress' AND p_new = 'completed')))
    OR (v_is_driver AND v_r.status IN ('accepted', 'arrived') AND p_new = 'cancelled')
    OR (v_is_pax    AND v_r.status IN ('requested', 'bidding', 'accepted', 'arrived') AND p_new = 'cancelled')
  ) THEN
    RAISE EXCEPTION 'transition % -> % is not permitted', v_r.status, p_new USING ERRCODE = '42501';
  END IF;

  IF p_new = 'in_progress' AND NOT public.is_admin() THEN
    IF p_otp IS NULL OR p_otp <> v_r.start_otp THEN RAISE EXCEPTION 'incorrect start code'; END IF;
  END IF;

  UPDATE public.rides SET
    status = p_new,
    started_at   = CASE WHEN p_new = 'in_progress' THEN now() ELSE started_at END,
    completed_at = CASE WHEN p_new = 'completed'   THEN now() ELSE completed_at END,
    cancel_reason = CASE WHEN p_new = 'cancelled' THEN p_note ELSE cancel_reason END
  WHERE id = p_ride;

  IF p_new = 'cancelled' THEN
    UPDATE public.ride_bids SET status = 'expired' WHERE ride_id = p_ride AND status = 'pending';
  END IF;
END;
$$;

-- ===========================================================================
-- RLS
-- ===========================================================================
ALTER TABLE public.properties         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_reservations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_listings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_enquiries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_bids          ENABLE ROW LEVEL SECURITY;

CREATE POLICY properties_select ON public.properties FOR SELECT
  USING (public.is_active_partner(partner_id) OR public.is_partner_member(partner_id) OR public.is_admin());
CREATE POLICY properties_write ON public.properties FOR ALL
  USING (public.is_partner_member(partner_id, ARRAY['owner', 'manager']))
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner', 'manager']));

CREATE POLICY rooms_select ON public.rooms FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id
                 AND (public.is_active_partner(p.partner_id) OR public.is_partner_member(p.partner_id) OR public.is_admin())));
CREATE POLICY rooms_write ON public.rooms FOR ALL
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_partner_member(p.partner_id, ARRAY['owner', 'manager'])))
  WITH CHECK (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_partner_member(p.partner_id, ARRAY['owner', 'manager'])));

-- Reservations are created ONLY through book_room(); guests/hosts/admins can read.
CREATE POLICY reservations_select ON public.room_reservations FOR SELECT
  USING (guest_id = auth.uid() OR public.is_admin()
         OR EXISTS (SELECT 1 FROM public.rooms r JOIN public.properties p ON p.id = r.property_id
                    WHERE r.id = room_id AND public.is_partner_member(p.partner_id)));

CREATE POLICY listings_select ON public.room_listings FOR SELECT
  USING ((is_available AND public.is_active_partner(landlord_partner_id))
         OR public.is_partner_member(landlord_partner_id) OR public.is_admin());
CREATE POLICY listings_write ON public.room_listings FOR ALL
  USING (public.is_partner_member(landlord_partner_id, ARRAY['owner']))
  WITH CHECK (public.is_partner_member(landlord_partner_id, ARRAY['owner']));

CREATE POLICY enquiries_tenant ON public.room_enquiries FOR ALL
  USING (tenant_id = auth.uid()) WITH CHECK (tenant_id = auth.uid() AND public.is_account_active());
CREATE POLICY enquiries_landlord_read ON public.room_enquiries FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.room_listings l WHERE l.id = listing_id AND public.is_partner_member(l.landlord_partner_id)));

CREATE POLICY driver_loc_owner ON public.driver_locations FOR ALL
  USING (public.is_partner_member(partner_id, ARRAY['owner']))
  WITH CHECK (public.is_partner_member(partner_id, ARRAY['owner']));
-- A passenger may see the location of the driver assigned to their ride.
CREATE POLICY driver_loc_passenger ON public.driver_locations FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.rides r WHERE r.driver_partner_id = partner_id
                 AND r.passenger_id = auth.uid() AND r.status IN ('accepted', 'arrived', 'in_progress')));

CREATE POLICY rides_select ON public.rides FOR SELECT
  USING (
    passenger_id = auth.uid() OR public.is_admin()
    OR (driver_partner_id IS NOT NULL AND public.is_partner_member(driver_partner_id))
    OR (status = 'bidding' AND EXISTS (
          SELECT 1 FROM public.driver_locations dl
          JOIN public.partner_members pm ON pm.partner_id = dl.partner_id AND pm.user_id = auth.uid()
          JOIN public.partner_profiles pp ON pp.id = dl.partner_id AND pp.status = 'active'
          WHERE ST_DWithin(dl.location, pickup_location, 5000)))
  );

CREATE POLICY bids_select ON public.ride_bids FOR SELECT
  USING (public.is_partner_member(driver_partner_id) OR public.is_admin()
         OR EXISTS (SELECT 1 FROM public.rides r WHERE r.id = ride_id AND r.passenger_id = auth.uid()));
