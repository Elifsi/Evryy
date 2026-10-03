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

## Core Domain Models (Planned)

1. **Authentication & Identity**:
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
