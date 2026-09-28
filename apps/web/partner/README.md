# apps/web/partner — evryy Production Partner Web Portal & Management Dashboard

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Technology Stack & Key Libraries

- **Framework**: Next.js 15+ (App Router with Server Actions & React Server Components).
- **Language**: TypeScript (Strict Mode).
- **UI & Styling**: React, Tailwind CSS, Radix UI, TanStack Table (v8), Tremor / Recharts for analytics.
- **Backend SDK**: `@supabase/ssr` (cookie-based session validation) and `@supabase/supabase-js`.
- **Mapping**: Mapbox GL / Leaflet for geofencing, delivery radiuses, and store coordinate picking.

---

## 2. Core Capabilities & Workflows

- **Multi-Vertical Operations Console**:
  - **Restaurants**: Live kitchen dispatch queue, menu section builder, and modifier groups.
  - **Hotels**: Room booking calendar with PostgreSQL `daterange` visualization (`aumsoni2002/Airbnb-Clone` pattern).
  - **Vehicle Fleet**: Inventory table with transmission/fuel specs, availability ranges, and deposit status (`vikasrana07/luxeride`).
  - **Room Rental Landlords**: Ward-level listing creator with photo uploads to Supabase Storage (`remediios/vista`).
- **Financial & Settlement Hub**:
  - Live ledger balance, pending vs settled funds.
  - Midnight payout batch history with connectIPS / Khalti disbursement references.
  - Downloadable tax invoices and commission reports.
- **Role-Based Access Control (RBAC)**:
  - Owner (full financial and team control).
  - Manager (catalog, pricing, opening hours).
  - Cashier (order fulfillment only, zero financial view).

---

## 3. Security Directives

- All partner mutations strictly governed by PostgreSQL RLS using `public.partner_members`.
- `SUPABASE_SERVICE_ROLE_KEY` is strictly prohibited in web client bundles or client-exposed environment variables.
