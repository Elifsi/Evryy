-- =============================================================================
-- 0001 — Extensions, shared enums & utility functions
-- evrry Super App · Elifsi Technologies Private Limited
-- Forward-only. Do not edit after it has been applied to a shared environment.
-- =============================================================================

-- Supabase installs extensions into the `extensions` schema.
CREATE SCHEMA IF NOT EXISTS extensions;

CREATE EXTENSION IF NOT EXISTS postgis    WITH SCHEMA extensions;  -- geography(Point,4326), ST_DWithin
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;  -- EXCLUDE constraints on ranges
CREATE EXTENSION IF NOT EXISTS pg_trgm    WITH SCHEMA extensions;  -- fuzzy / phonetic-ish name search
CREATE EXTENSION IF NOT EXISTS pgcrypto   WITH SCHEMA extensions;  -- digest(), crypt()

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
CREATE TYPE public.user_role AS ENUM (
  'consumer', 'rider', 'driver', 'merchant', 'landlord', 'host', 'admin', 'superadmin'
);

CREATE TYPE public.account_status AS ENUM ('active', 'suspended', 'banned');

-- Partner kinds line up 1:1 with the Superadmin KYC queues
-- (merchants / riders / stays / landlords). Vehicle-fleet rentals are Phase 2.
CREATE TYPE public.partner_type AS ENUM (
  'restaurant', 'grocery', 'rider', 'driver', 'hotel', 'landlord'
);

CREATE TYPE public.partner_status AS ENUM (
  'draft', 'pending_verification', 'active', 'rejected', 'suspended'
);

CREATE TYPE public.kyc_doc_type AS ENUM (
  'citizenship', 'national_id', 'driving_license', 'vehicle_bluebook', 'vehicle_photo',
  'pan_vat_certificate', 'business_registration', 'food_hygiene_permit',
  'hotel_registration', 'property_ownership', 'bank_proof'
);

CREATE TYPE public.kyc_doc_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TYPE public.store_category AS ENUM ('food', 'grocery');

CREATE TYPE public.order_status AS ENUM (
  'draft', 'acknowledged', 'preparing', 'ready_for_pickup',
  'dispatched', 'delivered', 'cancelled', 'rejected'
);

-- No customer stored-value wallet (NRB PSP licensing). Direct rails + COD only.
CREATE TYPE public.payment_method AS ENUM (
  'fonepay_qr', 'esewa', 'khalti', 'fonepay_direct', 'card', 'cod'
);

CREATE TYPE public.payment_status AS ENUM (
  'initiated', 'pending', 'succeeded', 'failed', 'refunded', 'partially_refunded'
);

CREATE TYPE public.ride_status AS ENUM (
  'requested', 'bidding', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled'
);

CREATE TYPE public.vehicle_type AS ENUM ('bike', 'scooter', 'car');

CREATE TYPE public.reservation_status AS ENUM (
  'pending', 'confirmed', 'checked_in', 'completed', 'cancelled'
);

CREATE TYPE public.loyalty_league AS ENUM ('copper', 'bronze', 'silver', 'platinum', 'diamond');

-- ---------------------------------------------------------------------------
-- Utility: keep updated_at fresh
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
