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

---

## 6. Single Adaptive Partner App vs. Fragmented Apps & Onboarding Lifecycle

### A. Why a Single Adaptive App is Strictly Superior
Instead of maintaining 5 separate apps ("EVRRY Driver", "EVRRY Restaurant", "EVRRY Hotel", "EVRRY Grocery", "EVRRY Landlord"), **evrry uses ONE unified Partner Application** (`apps/partner` on mobile, `apps/web/partner` on desktop/web):

1. **Zero Clutter via Dynamic HUD**: A bike rider never sees restaurant kitchen buttons; a hotel manager never sees bike-taxi maps. The app detects the partner's verified `partner_profiles.type` and renders **only** the relevant operational interface.
2. **Single Codebase & Shared Infra**: One app to test, publish, and maintain. Authentication (SMS OTP), KYC uploaders, Bank Account management, and Ledger Payouts are 100% shared.
3. **Multi-Role Switching for Nepali Business Owners**: Many individuals in Nepal operate multiple ventures (e.g. a restaurant owner who also rents out a flat upstairs on EVRRY Stays). A profile switcher in the app bar allows instant 1-tap switching without logging in and out.
4. **Desktop/Web vs. Mobile Optimization**:
   - **Riders & Drivers**: Onboard and operate 100% on **Mobile** (`apps/partner/android`).
   - **Restaurants, Supermarkets & Hotels**: Onboard and operate primarily on **Desktop Web** (`apps/web/partner`) for large KDS screens, physical barcode scanners, and thermal receipt printing.

### B. End-to-End Partner Onboarding Workflow

```mermaid
sequenceDiagram
    autonumber
    actor P as Partner (Phone/Web)
    participant App as EVRRY Partner App
    participant DB as Supabase DB & Storage
    actor Admin as Elifsi Superadmin Console

    P->>App: 1. Sign in with Phone Number (SMS OTP)
    App->>DB: Resolves/creates auth profile

    P->>App: 2. Selects Business Vertical: [Restaurant | Grocery | Rider | Driver | Hotel | Landlord]

    P->>App: 3. Enters Business Profile (Trade Name, Legal Name, Palika, Ward, Address, GPS)
    App->>DB: INSERT into partner_profiles (status = 'draft', type = chosen_type)

    P->>App: 4. Uploads KYC Documents (Citizenship, License, Bluebook, PAN/VAT, or Lalpurja)
    App->>DB: Uploads to private 'kyc' bucket; INSERT partner_kyc_documents (status = 'pending')

    P->>App: 5. Inputs Bank Account for Midnight Payouts (Bank Code, Account Name & Number)
    App->>DB: INSERT partner_bank_accounts (is_verified = false)

    P->>App: 6. Clicks "Submit for Verification"
    App->>DB: UPDATE partner_profiles SET status = 'pending_verification'

    Note over Admin,DB: Instant notification in Superadmin Console (apps/web/admin)
    Admin->>DB: 7. Inspects documents in split-screen viewer & verifies IRD PAN / Bluebook stamp
    Admin->>DB: Calls admin_review_partner(p_partner, p_approve, p_reason)

    alt Approved
        DB-->>App: partner_profiles.status = 'active'
        App-->>P: Push Notification / SMS: "Welcome to EVRRY! Your store/vehicle is now LIVE!"
        Note over P,App: Dynamic HUD unlocks! Restaurant sees KDS; Rider sees Map HUD.
    else Rejected
        DB-->>App: partner_profiles.status = 'rejected' (rejection_reason = "Bluebook tax stamp unclear")
        App-->>P: Notification: "Action required: Please re-upload your Bluebook document."
    end
```

---

## 7. Kitchen Voice Wake-Word & Zero-Leak Audio Architecture

Streaming continuous 24/7 kitchen audio to cloud LLMs would bankrupt the platform, record private chatter, and cause hallucinations. 

evrry enforces a **3-Layer Local Audio Filter** so cloud AI is asleep 99.9% of the day:

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                   3-LAYER ZERO-LEAK KITCHEN AUDIO ARCHITECTURE                       │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ 1. 100% OFFLINE LOCAL WAKE-WORD (Device CPU - Zero Cloud Cost, Zero Data Sent)       │
│    • Tiny open-source model (Porcupine / Vosk WebAssembly) runs locally in browser.  │
│    • Listens ONLY for the exact wake phrase: "Hey Evrry" or "Namaste Evrry".         │
│    • All background chatter (cricket, music, customer conversations) is 100% ignored.│
├──────────────────────────────────────────────────────────────────────────────────────┤
│ 2. VISUAL CHIME & 4-SECOND LISTENING WINDOW                                          │
│    • Screen flashes a bright green ring & plays a pleasant "Ting" chime.             │
│    • Opens a strict 4-second listening window.                                       │
│    • Local VAD (Voice Activity Detection) detects silence and closes mic in 1 sec.   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│ 3. 2-SECOND AUDIO SNIPPET DISPATCH & PHYSICAL ALTERNATIVES                           │
│    • Only the 2-second command audio is sent to the cloud STT API (< NPR 0.05 cost).  │
│    • Physical Alternatives for Loud Kitchens:                                        │
│      - Big On-Screen Tap Button (wrist/elbow tap).                                    │
│      - Bluetooth Kitchen Foot Pedal (step to talk, release to send).                 │
└──────────────────────────────────────────────────────────────────────────────────────┘
```
