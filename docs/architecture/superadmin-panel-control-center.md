# EVRRY Superadmin Operations & Control Center Specification
## Zero-SQL Administrative Governance Platform

> **Platform**: EVRRY Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Application Target**: `apps/web/admin` (Next.js 15 App Router, TypeScript, TanStack Table v8, Tremor, Tailwind CSS)  
> **Backend Integration**: Supabase Postgres, RPCs, Row Level Security, Edge Functions  
> **Core Principle**: **Zero SQL for Admins** — Operations, finance, support, and marketing teams can configure, manage, and monitor all platform parameters dynamically through intuitive UI controls without touching code or database consoles.

---

## 1. Executive Summary & Zero-SQL Architecture

In high-growth on-demand super apps, business rules change frequently: platform fees fluctuate during festivals, delivery fees adjust for monsoon rain, commission contracts are negotiated with anchor merchants, and marketing launches targeted discount codes. 

Requiring engineering intervention or manual SQL commands for these updates introduces deployment risk, human error, and latency.

### The EVRRY Zero-SQL Paradigm
```
┌─────────────────────────────────────────────────────────────┐
│             Superadmin UI (apps/web/admin)                  │
│   Sliders • Toggles • Currency Inputs • Date/Time Pickers   │
└──────────────────────────────┬──────────────────────────────┘
                               │ Authenticated Server Action (MFA Verified)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          Postgres RPCs & Platform Settings Table            │
│   • public.platform_settings                                │
│   • public.partner_profiles (commission_bps)                │
│   • public.vouchers & user_vouchers                         │
│   • public.admin_audit_logs (Immutable Record)              │
└──────────────────────────────┬──────────────────────────────┘
                               │ Zero-Downtime Cache Invalidation
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          Consumer & Partner Apps (Android, iOS, Web)        │
│   Instantly reflects updated fees, vouchers, and rates      │
└─────────────────────────────────────────────────────────────┘
```

Every parameter in EVRRY is stored in structured database tables with real-time reactive hooks:
1. **No Code Deployments**: Modifying a fee or commission takes effect across mobile and web clients within seconds.
2. **Immutable Audit Trail (`public.admin_audit_logs`)**: Every admin modification logs `admin_id`, `action_type`, `previous_state`, `new_state`, `reason`, and `ip_address`.
3. **Role-Based Access Control (RBAC)**: Fine-grained permissions (Superadmin, Finance Manager, KYC Compliance Officer, Customer Support Lead).

---

## 2. Dynamic Fee & Pricing Control Matrix

### A. Platform Fee Management
Located at: `/admin/pricing/platform-fees`

| Setting | Default Value | Database Key | UI Control | Impact |
|---|---|---|---|---|
| **Standard Order Platform Fee** | **Rs 10.00** (`1000` paisa) | `platform_fee_paisa` | Currency Number Input | Charged to customer on Food, Mart, and Parcel checkout. |
| **Promotional Fee Waiver** | `false` (Active) | `platform_fee_waiver` | 1-Click Toggle Switch | Instantly waives the Rs 10 fee platform-wide (e.g., during Dashain / Tihar promotions). |
| **Ride Booking Fee (Optional)** | `0` (Disabled) | `ride_platform_fee_paisa` | Number Input + Toggle | If enabled, adds a flat Rs 5 or Rs 10 platform fee to passenger cab/bike rides. |
| **Stay Guest Service Fee** | `5.0%` (`500` bps) | `stay_service_fee_bps` | Percentage Slider (0%–15%) | Guest-side booking fee on hotel rooms and homestays. |

### B. Vertical Delivery Fee & Distance Band Rules
Located at: `/admin/pricing/delivery-fees`

The admin panel allows configuring base delivery rates, free delivery thresholds, distance tiers, and driver payouts dynamically:

#### 1. Core Delivery & Distance Rules
- **Free Delivery Basket Threshold**: **Rs 1,000** (`100,000` paisa). Orders exceeding Rs 1,000 get FREE delivery (delivery fee = Rs 0).
- **Base Delivery Radius**: **3 km** (`3,000` meters).
- **Base Customer Delivery Fee**: **Rs 50** (`5,000` paisa) for orders under Rs 1,000 within 3 km.
- **Extra Distance Fee**: **Rs 15 per km** (`1,500` paisa) for delivery distances exceeding 3 km.

#### 2. Driver / Rider Delivery Earnings Model
- **Base Driver Payout (0–3 km)**: **Rs 40** (`4,000` paisa) per delivery.
- **Extra Distance Share (>3 km)**: **80%** (`8,000` bps) of the extra delivery fee charged to the customer.
  - *Example*: At 5 km (2 km extra @ Rs 15 = Rs 30 extra fee), driver earns:
    $$\text{Driver Payout} = \text{Rs } 40 + (80\% \times \text{Rs } 30) = \text{Rs } 40 + \text{Rs } 24 = \text{Rs } 64$$
  - Platform retains remaining 20% (Rs 6) + Rs 10 base delivery margin = Rs 16.
- **Free Delivery Subsidy**: When an order exceeds Rs 1,000 and the customer gets free delivery, the platform subsidizes the driver's payout (`marketing_expense`), ensuring the driver is always fully paid their Rs 40 + extra share.

#### 3. Surcharges & Multipliers
- **Late-Night Surcharge**: Toggleable flat fee (e.g., +Rs 20) or multiplier (1.2x) between 10:00 PM and 6:00 AM.
- **Monsoon / Severe Weather Surge**: 1-click slider (1.0x to 2.0x) applied to rider delivery payouts and customer delivery fees during heavy rainfall.


---

## 3. Dynamic Commission & Take-Rate Engine

Located at: `/admin/pricing/commissions`

### A. Global Default Vertical Commissions
Admins configure standard take-rates using interactive visual sliders:

```
Food & Restaurants:       [────────●────────] 15.0% (1,500 bps)
Grocery & Kirana Stores:  [────●────────────]  8.0%   (800 bps)
Bike-Taxi Rides:          [─────●───────────] 10.0% (1,000 bps)
Cab / Car Taxi Rides:     [──────●──────────] 12.0% (1,200 bps)
Hotels & Resorts:         [─────●───────────] 10.0% (1,000 bps)
Room Rentals (Long-term): [──●──────────────]  5.0%   (500 bps)
```

### B. Partner-Specific Negotiated Contracts (Custom Overrides)
For high-volume anchor merchants (e.g., Bhatbhateni Supermarket, big restaurant franchises) or special driver fleets:
1. Admin searches the partner by name, PAN, or phone number.
2. Clicks **"Edit Commercial Contract"**.
3. Enters custom commission (e.g., 5.0% for an anchor grocery chain instead of default 8.0%).
4. System displays an instant **Earnings Simulation**:
   - Projected Monthly GMV: NPR 2,500,000
   - Platform Revenue at 5%: NPR 125,000
   - Merchant Payout: NPR 2,375,000
5. Admin enters an approval note (*"Contract signed by VP Partnerships, Agreement #2026-BB-04"*) and clicks **"Save & Apply"**.
6. The update immediately modifies `partner_profiles.commission_bps` for that partner and logs the audit event.

---

## 4. Voucher & Marketing Promotional Engine

Located at: `/admin/marketing/vouchers`

The Voucher Engine enables marketing and growth teams to launch targeted campaigns with zero technical overhead.

### A. Voucher Creation Wizard Fields

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CREATE NEW VOUCHER                              │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Basic Details                                                       │
│    • Voucher Code:        [ EVRRYNEW100                           ]    │
│    • Public Title:        [ Welcome to EVRRY! Flat Rs 100 Off     ]    │
│    • Description:         [ Valid on your first food or mart order]    │
│                                                                        │
│ 2. Discount Rules                                                      │
│    • Discount Type:       (o) Flat NPR Amount  ( ) Percentage (%)      │
│    • Discount Value:      [ Rs 100.00                             ]    │
│    • Min Order Value:     [ Rs 300.00                             ]    │
│    • Max Discount Cap:    [ Rs 100.00                             ]    │
│                                                                        │
│ 3. Usage & Budget Limits                                               │
│    • Per-User Limit:      [ 1    ] uses per account                    │
│    • Total Redemptions:   [ 5000 ] total claims available              │
│    • Marketing Budget:    [ Rs 500,000 ] total allocated spend         │
│                                                                        │
│ 4. Targeting & Eligibility                                             │
│    • Vertical:            [ Food Delivery, Grocery & Mart       ▼ ]    │
│    • Audience:            (o) All Users  ( ) New Users Only            │
│    • Geographic Scope:    [ Nationwide (All Nepal)              ▼ ]    │
│                                                                        │
│ 5. Validity Period                                                     │
│    • Start Date/Time:     [ 2026-10-10  00:00 NPT                 ]    │
│    • Expiry Date/Time:    [ 2026-11-15  23:59 NPT                 ]    │
│                                                                        │
│                       [ Save & Publish Voucher ]                       │
└────────────────────────────────────────────────────────────────────────┘
```

### B. Live Voucher Performance & Budget Tracker
Table columns in the admin console:
- **Code & Title**: `DASHAIN50` (50% off up to Rs 150).
- **Status Badge**: `Active` (Green) | `Paused` (Yellow) | `Exhausted` (Gray) | `Expired` (Red).
- **Redemption Progress Bar**: e.g. `3,420 / 5,000 redeemed` (68.4%).
- **Financial Burn**: `NPR 412,500` burned of `NPR 500,000` budget.
- **Controls**:
  - `⏸ Pause`: Temporarily stops new redemptions while active orders complete.
  - `⚡ Extend Budget`: Increase total claim cap (e.g. from 5,000 to 10,000).
  - `🗑 Revoke`: Immediately invalidates the voucher platform-wide.

---

## 5. Partner KYC Document Verification Queue

Located at: `/admin/compliance/kyc`

A split-screen verification interface optimized for rapid processing of partner documents:

```
┌──────────────────────────────────────┬──────────────────────────────────────┐
│       SUBMITTED DOCUMENTS (ZOOM)      │          VERIFICATION FORM           │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ [Driving License Front & Back]       │ Partner: Ram Bahadur Shrestha        │
│ [Vehicle Blue Book Tax Stamp]        │ Type: Bike Rider (Kathmandu)         │
│ [Citizenship Card / Nagarikta]       │ Phone: +977 9841234567               │
│                                      │ Vehicle: Ba 85 Pa 4921 (Pulsar 150)  │
│ High-resolution Pan/Zoom viewer with │ License No: 01-06-00294812           │
│ contrast and brightness adjustment   │ License Expiry: 2029-08-14 (Valid)   │
│ for low-light smartphone uploads.    │ Blue Book Tax Paid Until: 2027       │
├──────────────────────────────────────┴──────────────────────────────────────┤
│ Quick Action:                                                               │
│   [🟢 APPROVE & ACTIVATE]   [🔴 REJECT WITH REASON]   [⚠️ REQUEST RE-UPLOAD] │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Pre-configured Rejection Reasons:
- `"Blue Book tax clearance stamp is expired or unreadable."`
- `"Driving license photo is blurry or cropped."`
- `"Vehicle number plate photo does not match registration document."`
- `"PAN/VAT registration certificate name does not match bank account name."`

When an admin clicks **Approve** or **Reject**, the system automatically:
1. Updates `partner_profiles.status = 'active'` (or `'rejected'`).
2. Fires an automated SMS via `supabase/functions/send-sms` to the partner's Nepali phone.
3. Sends a push notification to their mobile partner app.

---

## 6. Financial Settlement & Payout Oversight

Located at: `/admin/finance/payouts`

Operates in tandem with [`docs/architecture/payouts.md`](file:///home/rahul/codes/Evrry/docs/architecture/payouts.md):

### A. Midnight Settlement Batch Dashboard
- Displays aggregated daily earnings across all 753 local levels.
- **Deductions Breakdown**:
  - Gross Merchant Earnings: NPR 1,840,000
  - Less Platform Commissions: -NPR 276,000
  - Net Payable to Merchants: NPR 1,564,000
  - Rider Delivery Fees: NPR 420,000
  - Less Rider Cash-in-Hand (COD Offset): -NPR 285,000
  - Net Payable to Riders: NPR 135,000
- **One-Click Execution**:
  - `[Execute eSewa & Khalti Direct API Payouts]` (automated via `payout-execute`).
  - `[Generate ConnectIPS NCHL-128 Batch File]` (for direct interbank clearing).

### B. On-Demand Instant Payout Controls
- **Daily Cash-Out Limit Slider**: Configurable from NPR 2,000 to NPR 25,000 per partner per day (default: NPR 10,000).
- **Instant Processing Fee**: Configurable flat fee (default: NPR 15.00).
- **COD Lock Threshold**: Prevents on-demand payout if rider has collected >NPR 3,000 unremitted cash.

### C. Zero-Hub Rider COD Safety Monitor
- Real-time ranking of delivery riders and taxi drivers by **Cash-in-Hand balance**.
- **Soft Warning Threshold**: NPR 3,500 (alerts rider to deposit cash via digital reverse-QR).
- **Hard Safety Lock**: NPR 5,000 (`rider_cod_limit_paisa = 500000`). When reached, the system automatically stops assigning COD orders to that rider until cash is settled.
- **Admin Manual Override**: Admin can temporarily lift the COD lock for trusted senior riders during peak festival rushes.

---

## 7. Compliance, Taxation & Emergency Governance

Located at: `/admin/settings/governance`

### A. Nepal VAT Toggle (Inland Revenue Department Compliance)
- **Pre-Registration Phase (Current)**:
  - `vat_bps = 0` (0% VAT). No VAT charged to consumers.
- **Post-Registration Activation**:
  - One-click toggle switch: `[ Enable 13% VAT ]`
  - Instantly sets `vat_bps = 1300` platform-wide.
  - Invoices automatically begin itemizing 13% VAT and generating IRD-compliant fiscal register numbers. Zero code updates required.

### B. Emergency Geospatial Kill-Switches
Integrates with the Nepal administrative spine (`provinces`, `districts`, `local_levels`, `wards`):
- **City / Ward Offline Toggle**:
  - Dropdown selector: Province > District > Municipality > Ward.
  - Status Toggle: `Active` | `Suspended (Weather / Landslide)` | `Suspended (Strike / Bandh)`.
  - When suspended, consumers in that geographic polygon see a friendly notification: *"Deliveries and rides in Lalitpur Ward 4 are temporarily paused due to heavy rainfall. Stay safe!"*

### C. SMS Anti-Bombing & Fraud Controls
- **Max Verification Requests per Phone**: Number input (default: 5 per hour).
- **Cooldown Lock Duration**: Number input (default: 15 minutes).
- **Testing Number Whitelist**: Admin can add or remove internal QA phone numbers (e.g. `9800000001`) that bypass SMS limits and receive deterministic OTPs.

---

## 8. Directory & Technology Map (`apps/web/admin`)

The Superadmin console is structured in `apps/web/admin` as follows:

```
apps/web/admin/
├── app/
│   ├── (auth)/
│   │   ├── login/page.tsx               # Supabase Auth + TOTP MFA entry
│   │   └── mfa-verify/page.tsx          # Authenticator app 6-digit challenge
│   ├── (dashboard)/
│   │   ├── layout.tsx                   # Sidebar navigation, admin avatar, role badge
│   │   ├── page.tsx                     # Real-time GMV, active rides, order ticker
│   │   ├── pricing/
│   │   │   ├── platform-fees/page.tsx   # Platform fee Rs 10, waivers, stay service fees
│   │   │   ├── delivery-fees/page.tsx   # Vertical distance tiers, basket thresholds
│   │   │   └── commissions/page.tsx     # Global vertical sliders & partner overrides
│   │   ├── marketing/
│   │   │   ├── vouchers/page.tsx        # Voucher creation wizard & budget tracker
│   │   │   └── banners/page.tsx         # Mobile home banner & carousel editor
│   │   ├── compliance/
│   │   │   ├── kyc/page.tsx             # Partner document inspection queue
│   │   │   └── audit-logs/page.tsx      # Immutable admin action history table
│   │   ├── finance/
│   │   │   ├── payouts/page.tsx         # Midnight batch release & ConnectIPS export
│   │   │   ├── on-demand/page.tsx       # Instant payout limits & fee settings
│   │   │   └── rider-cod/page.tsx       # Cash-in-hand monitor & safety locks
│   │   └── settings/
│   │       ├── governance/page.tsx      # 13% VAT toggle, invoice headers
│   │       ├── emergency/page.tsx       # Ward kill-switches, monsoon surges
│   │       └── sms-ratelimits/page.tsx  # Anti-bombing thresholds & whitelists
├── components/
│   ├── forms/                           # Reusable number, currency, and slider inputs
│   ├── tables/                          # TanStack Table v8 pagination & filters
│   ├── metrics/                         # Tremor analytics cards & GMV charts
│   └── viewer/                          # Split-screen pan/zoom document inspector
└── lib/
    ├── actions/                         # Next.js Server Actions calling Postgres RPCs
    └── supabase/                        # @supabase/ssr server-side admin client
```

---

## 9. Conclusion & Discussion Sign-off

With this specification:
1. **The engineering team never touches SQL to change operational rules**.
2. **Operations and business teams have autonomous, instant control** over fees, rates, promotions, and approvals.
3. **Every action is tracked, balanced, and secure**.

> **Status**: **Fully Documented**. Ready for architectural alignment and discussion before coding the UI screens in `apps/web/admin`.
