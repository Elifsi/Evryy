# supabase/ — Centralized Shared Backend

This directory contains the version-controlled configuration, database migrations, and Edge Functions for the **shared Supabase backend** powering the entire **evrry** Super App platform, developed by **Elifsi Technologies Private Limited**.

```
Consumer Android ──────┐
Consumer iOS ──────────┤
Consumer Web ──────────┤
                       │
Partner Android ───────┤──→ Shared Supabase Backend (supabase/)
Partner iOS ───────────┤    ├── Auth (User & Partner identity)
Partner Web ───────────┤    ├── PostgreSQL Database
                       │    ├── Row Level Security (RLS)
                       │    ├── Realtime (Orders & Chats)
                       │    ├── Storage (Assets, Menus, KYC)
                       │    └── Edge Functions (Payments, Payouts, AI)
```

> **Centralized Architecture Rule**: There is one unified Supabase project for both Consumer and Partner applications. Separation of concerns and tenant isolation are enforced strictly through PostgreSQL Row Level Security (RLS) and server-side role validation.

---

## Directory Contents

| Path | Purpose |
|---|---|
| [`config.toml`](./config.toml) | Supabase CLI local development configuration |
| [`seed.sql`](./seed.sql) | Initial development and testing seed data (no production data) |
| [`migrations/`](./migrations/) | Forward-only SQL migrations for database schema & RLS policies |
| [`functions/`](./functions/) | Server-side TypeScript Edge Functions (payments, payouts, AI) |

---

## Core Domain Models (100% Implemented — 20 Migrations)

All 20 forward-only migrations are active in [`migrations/`](./migrations/):
1. **Extensions & Enums** (`0001`): PostGIS, pgcrypto, btree_gist, pgvector, role enums.
2. **Administrative Spine of Nepal** (`0002`): 7 provinces, 77 districts, 753 municipalities & wards.
3. **Identity, Partners & Multi-Store** (`0003`): 1:N multi-business profiles, bank accounts, KYC docs.
4. **Catalog, Inventory & Orders** (`0004`): Multi-vertical catalog, atomic stock deduction, order state machine.
5. **Stays, Rooms & InDrive Bidding** (`0005`): Anti-double-booking GiST exclusion, real-time ride counter-bids.
6. **Payments & Double-Entry Ledger** (`0006`): Balanced general ledger, atomic `confirm_payment` trigger.
7. **E2EE Chat & Ephemeral Snaps** (`0007`): Signal-style JWK key exchange, auto-burn snaps, 24h stories.
8. **Loyalty Leagues & Vouchers** (`0008`): Asia/Kathmandu check-in streaks, dynamic promotional discounts.
9. **AI Memory & Preferences** (`0009`): User consent context store (`get_ai_context`), 30-day auto-purge.
10. **Storage Buckets & Privileges** (`0010`): RLS for `catalog`, `kyc`, `avatars`, `snaps`, `chat-media`.
11. **Nepal Geographic Seed** (`0011`): Deterministic administrative boundaries across Nepal.
12. **Reviews & Digital COD** (`0012`): Verified customer reviews, 0% VAT default, rider digital COD settlement.
13. **Delivered Invoice Queue** (`0013`): Automated transactional tax invoice generator and outbox trigger.
14. **SMS Verification & Anti-Bombing** (`0014`): Domestic SMS logs, rate limiter RPC (max 3 per 10 mins).
15. **Device Push Tokens** (`0015`): Multi-app FCM v1 / APNs tokens with dead-token cleanup.
16. **On-Demand Instant Payouts** (`0016`): Instant cash-out for drivers/riders with COD reconciliation locks.
17. **4 AI Voice Personas** (`0017`): Eli female, Rony male, Jenny female, Suka male personas & RPCs.
18. **Updated Delivery & Ledger Pricing** (`0018`): Rs 1000 free threshold, Rs 50 3km base, Rs 15/km, Rs 40 driver payout + 80% split, Rs 10 platform fee, marketing subsidy.
19. **WhatsApp Cloud API OTP** (`0019`): Primary WhatsApp OTP dispatch with automatic domestic SMS failover.
20. **Automated pg_cron Schedules** (`0020`): Midnight ConnectIPS bank settlement & automated cleanup cron jobs.
   - `auth.users` linked to `public.profiles` (consumers) and `public.partner_profiles` (businesses).
   - `public.partner_members` mapping staff members to partner entities with RBAC roles.

2. **Catalog & Services**:
   - `public.categories`, `public.items`, `public.item_variants`, `public.item_modifiers`.
   - Partner-level ownership and availability overrides.

3. **Orders & Fulfillment**:
   - `public.orders`, `public.order_items`, `public.order_status_history`.
   - Real-time updates delivered via Supabase Realtime channels.

4. **Financial Ledger & Accounting**:
   - `public.payments` (consumer payments, provider transaction references).
   - `public.transactions` (immutable double-entry ledger entries).
   - `public.partner_earnings` (gross, platform fee/commission, net payout entitlement).
   - `public.settlements` and `public.payouts` (bank transfer batches, status tracking).

---

## Security Policy

- **`anon` key**: Publicly safe. Embedded in Consumer and Partner apps. Relies on RLS for access control.
- **`service_role` key**: **NEVER** embedded in Android, iOS, or Web apps. Used only in Edge Functions for privileged operations (e.g. initiating partner bank transfers, verifying payment webhooks).
