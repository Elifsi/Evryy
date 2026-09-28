# Partner Architecture

The Partner application enables merchants, restaurants, service providers, and gig operators to manage their business, catalog, orders, and finances on the **evryy** Super App platform, developed by **Elifsi Technologies Private Limited**.

---

## 1. Platform Clients

| Client | Directory | Technology | Build / Package |
|---|---|---|---|
| **Android** | `apps/partner/android/` | Kotlin, Jetpack Compose, Foreground Services | Gradle |
| **iOS** | `apps/partner/ios/` | Swift, SwiftUI, Critical Alerts | Xcode |
| **Web Portal** | `apps/web/partner/` | Next.js, React, Tailwind, Data Tables, Charts | npm |

---

## 2. Role-Based Partner Architecture

Because the Consumer experience in evryy is multi-vertical (Food, Rides, Grocery, Hotels, Services), the **Partner Application is fundamentally Role-Based and Domain-Adaptive**. 

The system operates across **two distinct role dimensions**:

### Dimension 1: Vertical / Business Domain Roles (What business is being operated?)
The Partner UI dynamically reconfigures its core views based on the partner's registered vertical:

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                      PARTNER VERTICAL ROLE MAPPING                            │
├───────────────────┬───────────────────────────────────────────────────────────┤
│ Consumer Feature  │ Corresponding Partner Role & Operational Interface        │
├───────────────────┼───────────────────────────────────────────────────────────┤
│ 🚗 Rides / Cabs   │ RIDER / DRIVER ROLE:                                      │
│                   │ • Full-screen interactive map & turn-by-turn routing      │
│                   │ • Live trip requests, accept/decline HUD                  │
│                   │ • Passenger pickup & dropoff OTP verification             │
│                   │ • Live GPS broadcasting to Supabase Realtime              │
├───────────────────┼───────────────────────────────────────────────────────────┤
│ 🍔 Food & Dining  │ RESTAURANT / KITCHEN ROLE:                                │
│                   │ • Kitchen Display System (KDS) order queue & prep timers  │
│                   │ • Accept with estimated prep time (15m, 30m) or reject    │
│                   │ • Instant menu item 86'ing (marking out of stock)         │
│                   │ • ESC/POS thermal receipt & Kitchen Order Ticket (KOT)    │
├───────────────────┼───────────────────────────────────────────────────────────┤
│ 🛒 Grocery & Mart │ GROCERY / STORE CLERK ROLE:                               │
│                   │ • Order pick-and-pack checklist                           │
│                   │ • Barcode scanner / SKU lookup                            │
│                   │ • Real-time stock counts and customer substitution alerts │
├───────────────────┼───────────────────────────────────────────────────────────┤
│ 🏨 Hotels         │ HOSPITALITY FRONT-DESK ROLE:                              │
│                   │ • Room reservation calendar & check-in / check-out desk   │
│                   │ • Room availability, bed configurations, rate management  │
├───────────────────┼───────────────────────────────────────────────────────────┤
│ 🔧 Services       │ FIELD TECHNICIAN / SERVICE PROVIDER ROLE:                 │
│                   │ • Daily appointment calendar & customer location dispatch │
│                   │ • Job proof photo upload & customer signature sign-off    │
└───────────────────┴───────────────────────────────────────────────────────────┘
```

### Dimension 2: Staff Permission Roles (Who is using the app?)
Within any partner entity, staff accounts are restricted via PostgreSQL Row Level Security:

* **`owner`**: Complete authority. Bank account setup, payout requests, revenue reports, tax/VAT documents, and staff member management.
* **`manager`**: Operational control. Menu/catalog pricing, operating hours, active order dispatch, and customer dispute resolution.
* **`kitchen_staff` / `counter_cashier`**: Order fulfillment only. View incoming order tickets, mark food as "ready for pickup", and print receipts. **Strictly blocked from viewing bank accounts, gross revenues, or payout triggers.**
* **`driver` / `rider`**: Mobility execution only. View assigned trip details, passenger phone proxy, and GPS navigation.

---

## 3. Core Functional Capabilities

### A. Partner Onboarding & Business Profile
- Submission of business details, trade licenses, VAT/PAN certificates, bank accounts.
- Multi-step verification state machine: `submitted` → `under_review` → `verified` / `rejected` → `active`.
- Store hours, operating days, holiday schedules, and temporary "busy" or "closed" toggles.

### B. Catalog, Menu & Inventory Control
- Hierarchical category and product creation.
- Support for complex product variants (sizes, colors) and modifier groups (toppings, add-ons, required vs. optional selections).
- Stock level tracking with automated out-of-stock toggling.

### C. Live Order Dispatch & Kitchen Display
- High-priority real-time order arrival via WebSocket subscriptions (Supabase Realtime) and device push notifications.
- Order review actions:
  - **Accept**: Sets estimated prep time (e.g., 15 mins).
  - **Reject**: Requires a structured reason (out of ingredients, store overloaded).
- Status advancement: `acknowledged` → `preparing` → `ready_for_pickup` → `dispatched` → `delivered`.
- Bluetooth / LAN ESC/POS thermal receipt and kitchen order ticket (KOT) printing.

### D. Financials, Earnings & Ledger
- Per-order earnings breakdown:
  - Gross Order Value
  - Platform Commission / Fee
  - Taxes / VAT withheld
  - Net Partner Earning
- Financial balance ledger and settlement history.
- Bank payout status tracking and downloadable tax invoices.

### E. Team & Staff Role-Based Access Control (RBAC)
- Staff invitation by email/phone.
- Granular permission levels:
  - **Owner**: Full access including bank details, staff management, and business settings.
  - **Manager**: Menu pricing, operating hours, order management, performance analytics.
  - **Kitchen / Cashier**: Active order view, order state transitions, receipt printing (no financial access).
  - **Driver / Courier**: Assigned order details, customer contact, and delivery completion.

---

## 4. Multi-Tenant Data Isolation

- Partner isolation is enforced via database policies using `partner_id` foreign keys.
- Authenticated requests resolve the caller's authorized partners via `partner_members`.
- Under no circumstances can Partner A read orders, customer details, or financials of Partner B.
