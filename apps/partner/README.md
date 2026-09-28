# apps/partner/ — Partner Applications

The **Partner Application** is designed for businesses, service providers, and gig operators participating in the **evryy** Super App platform, developed by **Elifsi Technologies Private Limited**.

> **Important**: Partner applications are distinct products from consumer applications. They are designed around specific business roles, workflows, and operational needs rather than customer shopping flows.

---

## Role-Based & Domain-Adaptive Architecture

Because the Consumer app offers multiple verticals, the Partner application is built around **Dynamic Role-Based Workflows**:

1. **Rider / Driver Role** (Mobility):
   - Interactive turn-by-turn map navigation, live trip acceptance, passenger OTP verification, and GPS broadcasting.
2. **Restaurant / Kitchen Role** (Dining):
   - Kitchen Display System (KDS), preparation timers, 86'ing out-of-stock items, and ESC/POS thermal ticket printing.
3. **Grocery / Store Clerk Role** (Retail):
   - Pick-and-pack order checklists, barcode scanner, and inventory count updates.
4. **Hospitality Front-Desk Role** (Hotels):
   - Room reservation calendar, check-in / check-out desk, and room inventory management.
5. **Field Technician Role** (Services):
   - Appointment calendar, dispatch address routing, and job completion signoff.

### Staff Permission Tiers (RBAC)
Within each business partner, access is partitioned:
* `owner`: Full banking, payout disbursement, tax, and team control.
* `manager`: Catalog pricing, opening hours, active orders.
* `kitchen_staff` / `cashier`: Order fulfillment only (zero financial access).
* `driver`: Active trip navigation only.

---

## Core Architectural Capabilities

1. **Onboarding & Verification**:
   - Business registration, KYC/legal document upload, tax/VAT details, bank account verification.
   - Multi-stage onboarding status (pending review, verified, suspended, active).

2. **Catalog & Inventory Management**:
   - Product/service catalog creation, categorization, multi-variant options, and modifier groups.
   - Dynamic pricing rules, discount schedules, and real-time item availability toggling.
   - Stock level tracking and low-inventory alerts where applicable.

3. **Order Fulfillment Workflow**:
   - Real-time incoming order sound/push alerts.
   - Accept, reject (with structured reason codes), and estimated preparation time setting.
   - Order lifecycle progression: `acknowledged` → `preparing` → `ready_for_pickup` → `dispatched` → `delivered`.
   - Customer and delivery partner handoff coordination.

4. **Earnings, Settlement & Payouts**:
   - Granular gross revenue, net earnings, platform commission deductions, and adjustments ledger.
   - Scheduled bank settlement and automated payout status tracking.
   - Downloadable financial statements and tax summaries.

5. **Analytics & Operations**:
   - Real-time sales dashboard, top-performing items, peak order hours, customer ratings/feedback.

6. **Team & Staff Access Control**:
   - Role-based access control (RBAC): Owner, Store Manager, Kitchen Staff, Cashier, Driver.
   - Scoped permissions preventing unauthorized access to financial and bank payout records.

---

## Platforms

- **Android**: [`apps/partner/android/`](./android/) (Kotlin + Jetpack Compose)
- **iOS**: [`apps/partner/ios/`](./ios/) (Swift + SwiftUI)
- **Web Dashboard**: [`apps/web/partner/`](../web/partner/) (Next.js + React)
