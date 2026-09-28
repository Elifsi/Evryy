# supabase/migrations/ — Database Schema & Migration Specification

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  
> **Database Engine**: PostgreSQL 15+ with PostGIS, `pgcrypto`, `btree_gist`, and `pgvector`  

---

## 1. Core Database Extensions & Administrative Spine

### A. Required PostgreSQL Extensions
All initial migrations must install the requisite extensions:
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
```

### B. Administrative Spine of Nepal (`bibekoli/local-levels-of-nepal-dataset`)
The administrative foundation forms the foreign-key relational anchor for all addresses, stores, properties, rooms, and search boundaries across Nepal:

```sql
-- 7 Provinces
CREATE TABLE public.provinces (
  id SMALLINT PRIMARY KEY,
  name_en TEXT NOT NULL,
  name_ne TEXT NOT NULL
);

-- 77 Districts
CREATE TABLE public.districts (
  id SMALLINT PRIMARY KEY,
  province_id SMALLINT NOT NULL REFERENCES public.provinces(id),
  name_en TEXT NOT NULL,
  name_ne TEXT NOT NULL
);

-- 753 Local Levels (Metros, Sub-Metros, Municipalities, Rural Palikas)
CREATE TABLE public.local_levels (
  id INT PRIMARY KEY,
  district_id SMALLINT NOT NULL REFERENCES public.districts(id),
  name_en TEXT NOT NULL,
  name_ne TEXT NOT NULL,
  type TEXT NOT NULL, -- 'Metropolitan City', 'Sub-Metropolitan City', 'Municipality', 'Rural Municipality'
  wards_count SMALLINT NOT NULL DEFAULT 1,
  boundary GEOMETRY(MultiPolygon, 4326)
);

CREATE INDEX idx_local_levels_district ON public.local_levels(district_id);
CREATE INDEX idx_local_levels_boundary ON public.local_levels USING GIST(boundary);
```

---

## 2. Shared Horizontal Engine (Identity, Roles & Payment Ingestion)

### A. Typed Role Enum & Unified Profiles
```sql
CREATE TYPE public.user_role AS ENUM (
  'consumer', 'rider', 'driver', 'merchant', 'landlord', 'host', 'admin'
);

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL DEFAULT 'consumer',
  username TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  public_key_jwk JSONB,
  signing_key_jwk JSONB,
  local_level_id INT REFERENCES public.local_levels(id),
  ward_number SMALLINT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### B. Direct Payment Transactions & Platform Accounting Ledger
*(Note: In-app customer wallets are eliminated to remove NRB stored-value PSP licensing liabilities. All checkouts flow directly through payment gateways, cards, or Cash on Delivery).*

```sql
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  provider TEXT NOT NULL CHECK (provider IN (
    'fonepay_qr', 'fonepay_direct', 'esewa', 'khalti', 'card', 'cod'
  )),
  provider_reference_id TEXT, -- Fonepay trace ID, Khalti pidx, eSewa transaction_uuid
  qr_payload TEXT,            -- Dynamic EMVCo QR string (for Fonepay Dynamic QR)
  amount_in_paisa BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'completed', 'failed', 'refunded', 'pending_cod_collection'
  )),
  remarks TEXT NOT NULL,      -- System-generated immutable remark (e.g. 'EVRYY-ORD-10492')
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_order_id ON public.payments(order_id);
CREATE INDEX idx_payments_provider_ref ON public.payments(provider_reference_id);

CREATE TABLE public.platform_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID,
  payment_id UUID REFERENCES public.payments(id),
  entry_type TEXT NOT NULL CHECK (entry_type IN ('CREDIT', 'DEBIT')),
  amount_in_paisa BIGINT NOT NULL,
  source_type TEXT NOT NULL CHECK (source_type IN (
    'ONLINE_COLLECTION', 'RIDER_COD_COLLECTED', 'MERCHANT_DISBURSEMENT', 
    'RIDER_PAYOUT', 'PLATFORM_COMMISSION', 'GATEWAY_REFUND'
  )),
  account_id UUID NOT NULL, -- references partner_id, rider user_id, or platform master account
  reference_number TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_platform_ledger_account ON public.platform_ledger(account_id);
```

---

## 3. Multi-Vertical Domain Schemas & Concurrency Contracts

### A. Quick-Commerce Grocery (`Aakash901/BlinkitClone`)
Atomic inventory reservation with row-level locking to prevent overselling:
```sql
CREATE TABLE public.inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.partners(id),
  title TEXT NOT NULL,
  sku TEXT UNIQUE NOT NULL,
  stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  price_in_paisa INT NOT NULL,
  mrp_in_paisa INT,
  is_available BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Atomic Inventory Deduction Stored Procedure
CREATE OR REPLACE FUNCTION public.deduct_grocery_stock(p_item_id UUID, p_quantity INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_current_stock INT;
BEGIN
  SELECT stock_quantity INTO v_current_stock
  FROM public.inventory_items
  WHERE id = p_item_id
  FOR UPDATE;

  IF v_current_stock IS NULL OR v_current_stock < p_quantity THEN
    RETURN FALSE;
  END IF;

  UPDATE public.inventory_items
  SET stock_quantity = stock_quantity - p_quantity,
      updated_at = NOW()
  WHERE id = p_item_id;

  RETURN TRUE;
END;
$$;
```

### B. Hotel Stays & Calendar Engine (`aumsoni2002/Airbnb-Clone` & `OthmaneNissoukin`)
PostgreSQL `daterange` with `btree_gist` exclusion constraint to prevent double-booking:
```sql
CREATE TABLE public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  room_number TEXT NOT NULL,
  room_type TEXT NOT NULL, -- Deluxe, Suite, Standard
  max_guests INT NOT NULL DEFAULT 2,
  price_per_night_in_paisa INT NOT NULL
);

CREATE TABLE public.room_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  reservation_period DATERANGE NOT NULL,
  total_in_paisa INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'checked_in', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT no_double_booking EXCLUDE USING gist (room_id WITH =, reservation_period WITH &&)
);
```

### C. Vehicle Rentals (`vikasrana07/luxeride` & `arman-dogru/car-rental`)
PostgreSQL `tsrange` (timestamp range) exclusion constraint to prevent overlapping reservations:
```sql
CREATE TABLE public.rental_vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID NOT NULL REFERENCES public.partners(id),
  model_name TEXT NOT NULL,
  vehicle_category TEXT NOT NULL, -- 'motorcycle', 'scooter', 'sedan', 'suv'
  license_plate TEXT UNIQUE NOT NULL,
  hourly_rate_in_paisa INT NOT NULL,
  daily_rate_in_paisa INT NOT NULL,
  deposit_amount_in_paisa INT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL
);

CREATE INDEX idx_rental_vehicles_geo ON public.rental_vehicles USING GIST(location);

CREATE TABLE public.vehicle_rentals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES public.rental_vehicles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  rental_period TSRANGE NOT NULL,
  total_in_paisa INT NOT NULL,
  deposit_status TEXT NOT NULL DEFAULT 'held' CHECK (deposit_status IN ('held', 'refunded', 'forfeited')),
  status TEXT NOT NULL DEFAULT 'booked' CHECK (status IN ('booked', 'active', 'completed', 'cancelled')),
  CONSTRAINT no_vehicle_overlap EXCLUDE USING gist (vehicle_id WITH =, rental_period WITH &&)
);
```

### D. Room Rental Finder (`Samizen/RoomRental`, `remediios/vista`, `EmpSwarup/roomfinder`)
Long-term flat and room leasing with Nepal ward-level anchors:
```sql
CREATE TABLE public.room_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  room_type TEXT NOT NULL CHECK (room_type IN ('Single Room', '1RK', '1BHK', '2BHK', 'Flat', 'House')),
  tenant_constraint TEXT NOT NULL CHECK (tenant_constraint IN ('any', 'family', 'bachelor', 'female_only', 'students')),
  monthly_rent_in_paisa INT NOT NULL,
  local_level_id INT NOT NULL REFERENCES public.local_levels(id),
  ward_number SMALLINT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL,
  utilities JSONB NOT NULL DEFAULT '{"water": true, "parking": false, "electricity": "separate_meter"}',
  images TEXT[] DEFAULT '{}',
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_room_listings_geo ON public.room_listings USING GIST(location);
CREATE INDEX idx_room_listings_local_level ON public.room_listings(local_level_id, ward_number);
```

### E. Ride Sharing & Real-Time Bidding (`WaqasSiddiqi/inDrive-Clone` & `amitshekhariitbhu`)
```sql
CREATE TABLE public.rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES auth.users(id),
  driver_id UUID REFERENCES auth.users(id),
  ride_type TEXT NOT NULL CHECK (ride_type IN ('bike', 'taxi_standard', 'taxi_comfort', 'electric')),
  pickup_name TEXT NOT NULL,
  drop_name TEXT NOT NULL,
  pickup_location GEOGRAPHY(Point, 4326) NOT NULL,
  drop_location GEOGRAPHY(Point, 4326) NOT NULL,
  offered_fare_in_paisa INT NOT NULL,
  final_fare_in_paisa INT,
  phase TEXT NOT NULL DEFAULT 'bidding' CHECK (phase IN (
    'bidding', 'driver_assigned', 'en_route_to_pickup', 
    'arrived_at_pickup', 'in_progress', 'completed', 'cancelled'
  )),
  otp TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.ride_bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES auth.users(id),
  counter_fare_in_paisa INT NOT NULL,
  driver_lat NUMERIC(10,8) NOT NULL,
  driver_lng NUMERIC(11,8) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### F. Realtime Messaging & Ephemeral Snaps (`Debanshu777` & `GetStream`)
```sql
CREATE TABLE public.chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('DIRECT', 'ORDER_SUPPORT', 'RIDE_COORDINATION')),
  reference_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  encrypted_payload TEXT NOT NULL,
  message_type TEXT NOT NULL DEFAULT 'TEXT' CHECK (message_type IN ('TEXT', 'IMAGE', 'VOICE_NOTE', 'LIVE_RIDE_SHARE')),
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.snaps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  recipient_id UUID NOT NULL REFERENCES auth.users(id),
  storage_path TEXT NOT NULL,
  filter_name TEXT,
  opened_at TIMESTAMPTZ,
  is_burned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ephemeral Media Auto-Burn RPC
CREATE OR REPLACE FUNCTION public.open_and_burn_snap(p_snap_id UUID, p_viewer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.snaps
  SET opened_at = NOW(),
      is_burned = TRUE
  WHERE id = p_snap_id AND recipient_id = p_viewer_id AND is_burned = FALSE;
  
  RETURN FOUND;
END;
$$;
```

---

## 4. Row Level Security (RLS) Policy Blueprint

Every table has RLS explicitly enabled:
```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_rentals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snaps ENABLE ROW LEVEL SECURITY;
```

### RLS Policies
- **Profiles**: `SELECT` is public; `UPDATE` restricted to `id = auth.uid()`.
- **Payments**: `SELECT` restricted to `user_id = auth.uid()`. Inserts/updates executed exclusively via server-side procedures/Edge Functions.
- **Platform Ledger**: Read-only access for authenticated partners where `account_id = auth.uid()`; mutations restricted strictly to backend service roles.
- **Room Listings**: Public `SELECT` where `is_available = true`; `INSERT/UPDATE/DELETE` restricted to `landlord_id = auth.uid()`.
- **Messages**: `SELECT` where `sender_id = auth.uid() OR recipient_id = auth.uid()`.
- **Snaps**: `SELECT` where `(sender_id = auth.uid() OR recipient_id = auth.uid()) AND is_burned = false`.
