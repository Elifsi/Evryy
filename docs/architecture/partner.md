# Partner Architecture

The Partner application enables merchants, restaurants, service providers, and gig operators to manage their business, catalog, orders, and finances on the **evrry** Super App platform, developed by **Elifsi Technologies Private Limited**.

---

## 1. Platform Clients

| Client | Directory | Technology | Build / Package |
|---|---|---|---|
| **Android** | `apps/partner/android/` | Kotlin, Jetpack Compose, Foreground Services | Gradle |
| **iOS** | `apps/partner/ios/` | Swift, SwiftUI, Critical Alerts | Xcode |
| **Web Portal** | `apps/web/partner/` | Next.js, React, Tailwind, Data Tables, Charts | npm |

---

## 2. Role-Based Partner Architecture

Because the Consumer experience in evrry is multi-vertical (Food, Rides, Grocery, Hotels, Services), the **Partner Application is fundamentally Role-Based and Domain-Adaptive**. 

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

---

## 5. Hybrid Operational Architecture: Manual Control Dashboard + AI Co-Pilot

A core platform principle is **"AI-Assisted, Human-Controlled"**:
- **Never a Black Box**: AI is an accelerator, **not a replacement for partner control**.
- **100% Full Manual Control**: Every single feature, price, order status, room availability, and setting has a robust, intuitive manual dashboard (buttons, forms, toggles, tables). Small or quick tasks can be done manually in seconds without touching AI.
- **AI as a Co-Pilot**: AI assists busy partners (e.g. scanning a 100-item paper menu with a photo, hands-free voice commands while driving or cooking). All AI actions present a preview for human confirmation before publishing.

### A. Manual Controls vs. AI Co-Pilot Feature Matrix

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               HYBRID PARTNER OPERATIONAL MATRIX                                       │
├─────────────────────┬───────────────────────────────────────────┬─────────────────────────────────────┤
│ Domain / Task       │ 🛠️ Full Manual Dashboard (Always Available)│ 🤖 AI Co-Pilot Accelerator (Optional)│
├─────────────────────┼───────────────────────────────────────────┼─────────────────────────────────────┤
│ Menu & Inventory    │ • Form-based item creation & edit         │ • Photo-to-Menu OCR & Digitizer     │
│                     │ • Manual price changes & stock counters   │   (snaps physical menu, auto-fills) │
│                     │ • Image upload & tag selectors            │ • Nepali voice toggle: "Momo sakiyo"│
│                     │ • Out-of-stock toggle switches            │   (instantly toggles availability)  │
├─────────────────────┼───────────────────────────────────────────┼─────────────────────────────────────┤
│ Live Order & KDS    │ • KDS board with Accept / Reject buttons  │ • Voice order status updates        │
│                     │ • Custom prep time selector (10m, 20m)    │ • Automated print ticket triggers   │
│                     │ • Manual handoff code input               │ • Kitchen audio chime on new orders │
├─────────────────────┼───────────────────────────────────────────┼─────────────────────────────────────┤
│ Rooms & Stays       │ • Visual calendar with drag-to-book       │ • 3-bullet listing generator        │
│                     │ • Manual room rates & blackout dates      │ • AI Draft FAQ auto-responder for   │
│                     │ • Form inputs for amenities & house rules │   amenity/parking questions on chat │
├─────────────────────┼───────────────────────────────────────────┼─────────────────────────────────────┤
│ Rides & Drivers     │ • Interactive map with Accept / Bid slider│ • Hands-free voice HUD while driving│
│                     │ • Manual 4-digit start OTP keypad         │ • Audio route & pickup advisories   │
│                     │ • One-tap "Arrived" / "Completed" buttons │ • "Customer lai call gara" command  │
├─────────────────────┼───────────────────────────────────────────┼─────────────────────────────────────┤
│ Financials & COD    │ • Daily ledger balance & settlement tables│ • Plain-Nepali morning audio/text   │
│                     │ • Bank account entry & invoice downloads  │   briefing (sales, high-demand tips,│
│                     │ • In-app "Settle Cash" via eSewa/Khalti   │   customer review sentiment summary)│
└─────────────────────┴───────────────────────────────────────────┴─────────────────────────────────────┘
```

### B. Human-in-the-Loop Safeguards
1. **Catalog Previews**: When an AI scans a paper menu photo, it populates a draft form in the manual dashboard. The merchant reviews the names, prices, and tags, makes any quick edits, and clicks **"Save & Publish"**.
2. **Chat Auto-Response Approval**: AI drafts replies to guest inquiries based on verified property amenities. The host can either tap **"Send"**, edit the text, or toggle full auto-reply on/off at will.
3. **Manual Fallback**: If the device is offline or the user prefers manual operation, 100% of workflows operate independently of AI services.
