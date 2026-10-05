# apps/web/partner — evrry Merchant & Host Web Operations Dashboard

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Platform Role: Merchants & Hosts Only (No Driving/Riding on Web)

The **Partner Web Portal** is specifically engineered for **Venue, Store, and Property Operators** who work at physical counters, desks, or kitchens using desktop PCs, laptops, and tablets:

| Vertical | Primary Operational Device | Web Portal Experience |
| :--- | :--- | :--- |
| 🍔 **Restaurants & Cafes** | Desktop PC / Kitchen Tablet | Kitchen Display System (KDS), Menu Builder, KOT Thermal Printing |
| 🛒 **Grocery Stores & Kirana** | Counter Billing PC / Tablet | Bulk Inventory Table, Barcode Scanners, Pick-and-Pack Checklist |
| 🏨 **Hotels & Homestays** | Front Desk Laptop / PC | Room Booking Calendar (`daterange`), Check-in / Check-out Desk |
| 🏠 **Room Rental Landlords** | Desktop / Laptop / Tablet | Property Listing Creator, Photo Manager, Tenant Enquiries |
| 🛵 **Delivery Riders & Drivers** | **Smartphones ONLY (`apps/partner/android`)** | **No driving on web**. If a driver logs in, they see a link to download the Android app + read-only tax/payout statements. |

---

## 2. Technology Stack & Key Libraries

- **Framework**: Next.js 15+ (App Router with Server Actions & React Server Components).
- **Language**: TypeScript (Strict Mode).
- **UI & Styling**: React, Tailwind CSS, Radix UI, TanStack Table (v8), Tremor / Recharts for analytics.
- **Backend SDK**: `@supabase/ssr` (cookie-based session validation) and `@supabase/supabase-js`.
- **Mapping**: Mapbox GL / Leaflet for geofencing, delivery radiuses, and store coordinate picking.
- **Hardware Integration**: WebUSB / Web Serial / LAN for ESC/POS thermal receipt printers and barcode scanners.

---

## 3. Core Functional Workflows

1. **Kitchen Display System (KDS) & Menu Builder**:
   - Real-time order tickets with audible chimes.
   - Accept with prep time (10m, 20m) or reject with reason.
   - Menu section editor with packaging units (`1 kg`, `500 ml`) and dish modifier options (e.g. Cheese, Spice level).
   - AI Menu Photo Scanner: uploads physical paper menu photo to pre-fill draft catalog for review and one-click publishing.
2. **Hotel Room Booking Calendar & Landlord Hub**:
   - Visual multi-room booking calendar powered by PostgreSQL `btree_gist` exclusion constraints (zero double-booking).
   - Rate management per night and seasonal pricing.
   - Landlord listing creator with photo upload to private `catalog` storage bucket.
3. **Financials & Midnight Settlement Oversight**:
   - Live ledger balance, pending vs settled funds.
   - Midnight payout batch history with connectIPS / Khalti disbursement references.
   - Downloadable tax invoices and commission reports.
4. **Role-Based Access Control (RBAC)**:
   - Owner (full financial and team control).
   - Manager (catalog, pricing, opening hours).
   - Cashier / Kitchen Staff (order fulfillment only, zero financial view).

---

## 4. Security Directives

- All partner mutations strictly governed by PostgreSQL RLS using `public.partner_members`.
- `SUPABASE_SERVICE_ROLE_KEY` is strictly prohibited in web client bundles or client-exposed environment variables.
