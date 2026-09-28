# supabase/migrations/ — Database Schema & Migration Guide

This directory contains version-controlled, forward-only SQL migrations for the centralized Supabase backend powering all **evryy** clients (Android, iOS, Web), developed by **Elifsi Technologies Private Limited**.

## Status

🔮 **Awaiting Open-Source Contributor / Developer Implementation.**
This guide serves as the technical specification for developers implementing the initial SQL migrations.

---

## Technical Specifications for Schema Contributors

When implementing migrations, organize them into logical, timestamped files using the Supabase CLI:

```bash
supabase migration new initial_auth_profiles
supabase migration new partners_and_rbac
supabase migration new catalog_and_services
supabase migration new orders_and_fulfillment
supabase migration new mobility_and_rides
supabase migration new payments_and_ledger
supabase migration new partner_payouts
supabase migration new social_chat_and_snaps
supabase migration new ai_memory_and_audit
```

---

### Domain Breakdown & Table Specifications

#### 1. Identity, Auth & Profiles
* **`public.profiles`**:
  * `id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
  * `username TEXT UNIQUE NOT NULL`
  * `full_name TEXT`, `phone TEXT`, `avatar_url TEXT`
  * `public_key_jwk JSONB` & `signing_key_jwk JSONB` (for E2EE direct messages)
  * `is_creator BOOLEAN DEFAULT FALSE`, `creator_bio TEXT`, `creator_category TEXT`
  * `created_at TIMESTAMPTZ DEFAULT NOW()`, `updated_at TIMESTAMPTZ DEFAULT NOW()`
* **`public.user_preferences`**:
  * `user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE`, `key TEXT NOT NULL`, `value TEXT NOT NULL`
  * `PRIMARY KEY (user_id, key)`

#### 2. Partners & Role-Based Access Control (RBAC)
* **`public.partners`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  * `business_name TEXT NOT NULL`, `slug TEXT UNIQUE NOT NULL`
  * `business_type TEXT NOT NULL` (`restaurant`, `grocery`, `retail`, `hotel`, `mobility`, `service`)
  * `rating NUMERIC(3,2) DEFAULT 5.0`, `rating_count INTEGER DEFAULT 0`
  * `address TEXT`, `area TEXT`, `latitude NUMERIC(10,8)`, `longitude NUMERIC(11,8)`
  * `metadata JSONB` (cuisines, star rating, amenities, price for two, gradient colors)
  * `status TEXT DEFAULT 'active'` (`pending`, `active`, `suspended`)
* **`public.partner_members`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  * `partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE`
  * `user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE`
  * `role TEXT NOT NULL` (`owner`, `manager`, `staff`, `cashier`, `driver`)
  * `UNIQUE (partner_id, user_id)`

#### 3. Service Catalog & Products
* **`public.categories`**:
  * `id TEXT PRIMARY KEY` (`food`, `grocery`, `electronics`, `fashion`, `hotels`, `rides`, `services`)
  * `label TEXT NOT NULL`, `icon TEXT`
* **`public.catalog_items`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  * `partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE`
  * `category_id TEXT REFERENCES public.categories(id)`
  * `title TEXT NOT NULL`, `subtitle TEXT`
  * `price_in_paisa INTEGER NOT NULL`, `mrp_in_paisa INTEGER`
  * `currency TEXT DEFAULT 'NPR'`
  * `is_available BOOLEAN DEFAULT TRUE`, `veg BOOLEAN`
  * `menu_section TEXT`, `is_bestseller BOOLEAN DEFAULT FALSE`
  * `weight_volume TEXT`, `attributes JSONB`, `image_url TEXT`

#### 4. Orders & Shopping Cart
* **`public.orders`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `order_number TEXT UNIQUE NOT NULL`
  * `user_id UUID REFERENCES auth.users(id)`
  * `partner_id UUID REFERENCES public.partners(id)`
  * `order_type TEXT NOT NULL` (`ORDER`, `BOOKING`, `RIDE`)
  * `status TEXT NOT NULL DEFAULT 'draft'` (`draft`, `pending_authorization`, `pending_vendor`, `confirmed`, `in_progress`, `completed`, `cancelled`)
  * `subtotal_in_paisa INTEGER NOT NULL`, `delivery_fee_in_paisa INTEGER DEFAULT 0`
  * `platform_fee_in_paisa INTEGER DEFAULT 0`, `tax_in_paisa INTEGER DEFAULT 0`, `total_in_paisa INTEGER NOT NULL`
  * `delivery_address JSONB`, `eta_minutes INTEGER`, `placed_by TEXT DEFAULT 'USER'` (`USER`, `AI_AGENT`)
* **`public.order_items`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE`
  * `catalog_item_id UUID REFERENCES public.catalog_items(id)`
  * `title TEXT NOT NULL`, `unit_price_in_paisa INTEGER NOT NULL`, `quantity INTEGER NOT NULL`, `total_in_paisa INTEGER NOT NULL`
* **`public.order_status_logs`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE`
  * `status TEXT NOT NULL`, `note TEXT`, `created_at TIMESTAMPTZ DEFAULT NOW()`

#### 5. Mobility & Ride Booking
* **`public.rides`**:
  * `id UUID PRIMARY KEY REFERENCES public.orders(id) ON DELETE CASCADE`
  * `user_id UUID REFERENCES auth.users(id)`, `driver_id UUID REFERENCES auth.users(id)`
  * `ride_type TEXT NOT NULL` (`standard`, `comfort`, `electric`, `bike`, `xl`)
  * `phase TEXT NOT NULL` (`searching`, `driver_assigned`, `en_route_to_pickup`, `driver_arrived`, `in_progress`, `completed`, `cancelled`)
  * `pickup_name TEXT NOT NULL`, `drop_name TEXT NOT NULL`
  * `pickup_lat NUMERIC(10,8)`, `pickup_lng NUMERIC(11,8)`, `drop_lat NUMERIC(10,8)`, `drop_lng NUMERIC(11,8)`
  * `distance_km NUMERIC(5,2)`, `fare_in_paisa INTEGER NOT NULL`, `otp TEXT`

#### 6. Payments & Financial Ledger
* **`public.payments`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `order_id UUID REFERENCES public.orders(id)`
  * `user_id UUID REFERENCES auth.users(id)`, `provider TEXT NOT NULL` (`esewa`, `khalti`, `fonepay`, `card`)
  * `provider_transaction_id TEXT`, `amount_in_paisa INTEGER NOT NULL`, `status TEXT NOT NULL` (`pending`, `completed`, `failed`, `refunded`)
* **`public.transactions`**:
  * Immutable double-entry ledger table. `account_type TEXT`, `entry_type TEXT` (`DEBIT`/`CREDIT`), `amount_in_paisa INTEGER`.
* **`public.refunds`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `payment_id UUID REFERENCES public.payments(id)`, `amount_in_paisa INTEGER`, `status TEXT`.

#### 7. Partner Settlements & Payouts
* **`public.partner_earnings`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `partner_id UUID REFERENCES public.partners(id)`, `order_id UUID REFERENCES public.orders(id)`
  * `gross_amount_in_paisa INTEGER NOT NULL`, `platform_fee_in_paisa INTEGER NOT NULL`, `tax_withheld_in_paisa INTEGER NOT NULL`, `net_payable_in_paisa INTEGER NOT NULL`
* **`public.settlements`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `partner_id UUID REFERENCES public.partners(id)`
  * `cycle_start TIMESTAMPTZ`, `cycle_end TIMESTAMPTZ`, `net_payout_in_paisa INTEGER NOT NULL`, `status TEXT NOT NULL`
* **`public.payouts`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `settlement_id UUID REFERENCES public.settlements(id)`
  * `amount_in_paisa INTEGER NOT NULL`, `payout_method TEXT NOT NULL`, `bank_reference_number TEXT`, `status TEXT NOT NULL`

#### 8. Social, Chat & Ephemeral Stories
* **`public.contacts`**:
  * `user_id UUID REFERENCES auth.users(id)`, `contact_user_id UUID REFERENCES auth.users(id)`, `PRIMARY KEY (user_id, contact_user_id)`
* **`public.messages`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `sender_id UUID REFERENCES auth.users(id)`, `recipient_id UUID REFERENCES auth.users(id)`
  * `encrypted_payload TEXT NOT NULL`, `status TEXT DEFAULT 'sent'` (`sent`, `delivered`, `read`)
* **`public.stories`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id UUID REFERENCES auth.users(id)`
  * `media_url TEXT NOT NULL`, `expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')`
* **`public.notes`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id UUID REFERENCES auth.users(id)`
  * `text TEXT NOT NULL`, `emoji TEXT`, `color TEXT`, `expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')`

#### 9. AI Memory & Audit Logs
* **`public.user_memories`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id UUID REFERENCES auth.users(id)`
  * `fact TEXT NOT NULL`, `confidence NUMERIC(3,2)`, `provenance TEXT` (`explicit`, `inferred`)
* **`public.ai_audit_logs`**:
  * `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id UUID REFERENCES auth.users(id)`
  * `actor_type TEXT NOT NULL`, `action TEXT NOT NULL`, `policy_decision TEXT NOT NULL`, `detail TEXT`

---

## Mandatory Row Level Security (RLS) Rules

Every table **must** enable RLS and enforce tenant isolation:
```sql
ALTER TABLE public.<table_name> ENABLE ROW LEVEL SECURITY;
```
* **Consumers**: Only access records where `user_id = auth.uid()`.
* **Partners**: Only access records where `partner_id IN (SELECT partner_id FROM public.partner_members WHERE user_id = auth.uid())`.
* **Public Read**: Catalog items and categories can be read by all authenticated or anonymous users (`auth.role() IN ('authenticated', 'anon')`).
