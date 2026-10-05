# Payment Gateway Architecture

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

**evrry** implements a streamlined, zero-liability **Payment Service** architecture. To eliminate the heavy regulatory burdens of operating a stored-value customer wallet under Nepal Rastra Bank (NRB) guidelines, **the in-app customer wallet has been completely removed**. Instead, all payments are initiated directly through trusted payment aggregators (**Fonepay**, **eSewa**, **Khalti**), card rails (**Visa, Mastercard, SCT** facilitated by eSewa & Khalti), and **Cash on Delivery (COD)**.

---

## 1. Supported Customer Payment Methods

```
┌────────────────────────────────────────────────────────────────────────┐
│                        evrry CHECKOUT MODAL                            │
│                                                                        │
│   [ 🟢 Pay via QR (Fonepay Dynamic QR) ]   ← RECOMMENDED (Any Bank)    │
│   • Displays instant dynamic QR (amount & system remark locked)        │
│   • Scan from any Nepali bank app, or screenshot & share to friends    │
│   • Screen blurs on scan, auto-advances upon payment (like IMS POS)    │
│                                                                        │
│   ── OR PAY VIA WALLET / DIRECT APP REDIRECT ───────────────────────── │
│   [ 🔴 eSewa ]       → Redirects to eSewa hosted login & SMS OTP       │
│   [ 🟣 Khalti ]      → Redirects to Khalti hosted login & SMS OTP      │
│   [ 🔵 Fonepay ]     → Redirects to Fonepay direct authorization       │
│                                                                        │
│   ── OR PAY VIA CARD ───────────────────────────────────────────────── │
│   [ 💳 Cards (Visa / Mastercard / SCT) ]                               │
│   • Hosted 3D-Secure card sheet powered directly via Khalti / eSewa    │
│                                                                        │
│   ── OR PAY UPON DELIVERY ──────────────────────────────────────────── │
│   [ 💵 Cash on Delivery (COD) ]                                        │
│   • Pay cash directly to the delivery rider upon physical arrival      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Payment Rails Breakdown

### A. Fonepay Dynamic QR (Supermarket IMS Billing Model)
- **Zero Customer Friction**: Customers do not need an eSewa or Khalti account; any of Nepal's 50+ commercial and development bank apps (Global Smart Plus, NIC Asia MoBank, Nabil SmartBank, Prabhu, Sanima, Everest, etc.) can scan and pay.
- **Dynamic Lock**: The server invokes Fonepay's Merchant API to generate a dynamic EMVCo QR with:
  1. `total_amount`: Exact payable total locked down to the paisa (e.g. `NPR 1,250.00`).
  2. `remarks`: System-generated immutable invoice reference (e.g. `EVRRY-ORD-10492`).
  3. `expires_at`: 5 to 10 minute auto-expiration timestamp.
- **Screenshot & Friend Sharing**: Customers can take a screenshot of the QR and send it via WhatsApp or Viber to friends or family. The recipient opens their bank app, taps **"Scan from Gallery"**, and authorizes the exact amount with their MPIN/biometrics.
- **Blurring & Auto-Processing**:
  - While awaiting payment confirmation, the QR screen displays an animated progress overlay (*"Processing payment... Please do not close"*).
  - The millisecond the bank approves the transfer, Fonepay fires an encrypted server-to-server webhook (IPN).
  - The server verifies the HMAC signature, updates `orders.status = 'paid'`, and emits a Supabase Realtime broadcast.
  - The customer's screen instantly triggers a success checkmark and auto-advances to the order tracking/receipt view without requiring any manual button click.

### B. Hosted Redirect Flow (eSewa, Khalti, Fonepay Direct)
- **Zero-Credential Security**: **evrry NEVER collects, sees, or handles customer passwords, PINs, or SMS OTPs.**
- **Redirection & Deep-Linking**:
  1. The user selects **eSewa**, **Khalti**, or **Fonepay Direct**.
  2. The server requests a payment session and returns a secured URL or custom scheme (`esewa://`, `khalti://`, `fonepay://`).
  3. The mobile app opens the provider's official hosted sheet via Chrome Custom Tabs or Safari View Controller.
  4. The customer logs in and enters their SMS OTP on the **gateway's official server page**.
  5. Upon authorization, the gateway redirects back to evrry via deep-link callback:
     `evrry://checkout/callback?status=success&pidx=...`
  6. Simultaneously, the gateway fires an asynchronous server webhook to confirm transaction settlement.

### C. Cards via Khalti & eSewa (3D-Secure Hosted Gateway)
- Rather than maintaining custom card storage or foreign payment gateways, **evrry** leverages the built-in card processing rails of **Khalti** and **eSewa**:
  - Supports **Visa**, **Mastercard**, **SCT (Smart Choice Technologies)**, and domestic UnionPay cards.
  - Hosted directly within the certified PCI-DSS Level 1 gateway sheets of Khalti and eSewa.
  - Bank 3D-Secure OTP verification occurs entirely on the issuer bank's portal.
  - Zero raw cardholder data (PAN, CVV, expiry dates) is ever stored or transmitted through evrry servers.

### D. Cash on Delivery (COD) & Zero-Hub Digital Settlement
- **Order Placement**: Order transitions immediately to `acknowledged` with `payment_method = 'cod'`.
- **Fulfillment & Handshake**: The delivery rider collects physical cash upon arrival. The customer provides a 4-digit delivery OTP to the rider (`order_handoff_codes`); the rider inputs the OTP in the Rider HUD to confirm handoff and cash collection.
- **Zero Physical Hubs & Zero Bank Queues**:
  1. **Automatic Earnings Offset**: A rider earns delivery fees from completed orders. The platform automatically offsets what the rider owes in COD cash against their earned delivery fees during midnight settlement. If earnings exceed cash, the difference is paid out. No physical cash needs to be transferred.
  2. **In-App Digital Settlement (`settle_rider_cod_digital`)**: If a rider accumulates more cash than their earnings, they tap **"Settle Cash"** in the rider app and pay Elifsi directly from their phone via **eSewa**, **Khalti**, or by scanning Elifsi's **Fonepay Dynamic QR**. The system verifies the digital transaction instantly and extinguishes their cash liability (`rider_details.cod_cash_in_hand_paisa`).
  3. **COD Safety Limit (`rider_cod_limit_paisa`)**: Configured in `platform_settings` (default: NPR 5,000 / 500,000 paisa). If a rider's cash in hand exceeds this threshold, COD order dispatches are paused until they settle digitally. Prepaid orders remain fully active.
  4. **Admin Manual Reconciliation (`admin_reconcile_rider_cash`)**: For rare situations where cash is handed over in an office or deposited directly to a corporate bank account, an admin can manually reconcile the rider's cash balance with full audit logging in `admin_audit_logs`.

### E. Tax & VAT Architecture (Pre-Registration 0% Default)
- **Current Status**: Elifsi Technologies is pre-VAT registration with the Inland Revenue Department (IRD).
- **Dynamic Configuration (`vat_bps`)**: Governed by `public.platform_settings.key = 'vat_bps'`.
- **Default**: Set to `0` basis points (**0% VAT**). The platform charges zero tax across all orders.
- **Future Scale**: When business turnover crosses the IRD statutory threshold (NPR 50 Lakhs for goods / NPR 20 Lakhs for services), Superadmin updates `vat_bps = 1300` (13%) in `platform_settings`. The database immediately starts computing 13% VAT with zero code changes or app updates.

---

## 3. End-to-End Architecture Flowchart

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CUSTOMER CHECKOUT IN evrry                            │
└──────────────┬─────────────────────────┬─────────────────────────┬──────────────┘
               │                         │                         │
     [ Fonepay Dynamic QR ]    [ eSewa / Khalti Redirect ]      [ Cash on Delivery ]
               │                         │                         │
               ▼                         ▼                         ▼
┌─────────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────┐
│ 1. Server generates QR with │ │ 1. Server creates pidx/ │ │ 1. Order marked as  │
│    locked amount & remark   │ │    session URL          │ │    COD confirmed    │
│ 2. User scans or shares     │ │ 2. User redirected to   │ │ 2. Kitchen prepares │
│    screenshot via gallery   │ │    eSewa/Khalti hosted  │ │    food / order     │
│ 3. Bank app authorizes PIN  │ │    page for Login & OTP │ │ 3. Rider dispatched │
└──────────────┬──────────────┘ └────────────┬────────────┘ └──────────┬──────────┘
               │                             │                         │
               ▼                             ▼                         │
┌─────────────────────────────┐ ┌─────────────────────────┐            │
│ Fonepay Instant Server IPN  │ │ Gateway Redirects to    │            │
│ Webhook (/payments/callback)│ │ evrry://checkout/success│            │
└──────────────┬──────────────┘ └────────────┬────────────┘            │
               │                             │                         │
               ▼                             ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      POSTGRESQL ORDERS & PAYMENTS UPDATE                        │
│                                                                                 │
│   • Set `orders.status = 'paid'` (or `'cash_pending_delivery'` for COD)        │
│   • Realtime WebSocket broadcasts event to mobile screen                        │
│   • Screen blurs QR / dismisses sheet and displays success animation            │
│   • KDS ticket printed & rider dispatch sequence triggered                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Automated Refunds via Direct Gateway Reversals

Since the in-app stored wallet is removed, refunds are executed directly back to the original source instrument:

1. **Khalti Orders**: The backend invokes Khalti's automated refund endpoint:
   - `POST /api/v2/payment/refund/`
   - Payload: `{ "pidx": "<original_pidx>", "amount": <amount_in_paisa>, "remarks": "Order cancelled" }`
   - Funds are instantly credited back to the customer's Khalti wallet or card.
2. **eSewa & Fonepay Orders**: Automated reversal API / merchant dispute settlement credit applied directly to the originating bank transaction reference.
3. **Cash on Delivery (COD)**: If cancelled before dispatch, no monetary movement occurs. If returned post-delivery, the partner or rider handles physical cash return or store credit voucher.

---

## 5. Security & Regulatory Compliance

- **No NRB Stored-Value Wallet Burden**: Because evrry does not hold customer funds in in-app wallets, it operates as a standard technology marketplace platform under Nepal Rastra Bank e-commerce regulations.
- **Credential Isolation**: Customer bank passwords, PINs, and OTPs never touch evrry servers or client apps.
- **Cryptographic Signature Verification**: Every webhook payload from eSewa, Khalti, and Fonepay is verified against provider public certificates and HMAC-SHA256 secret keys stored in Supabase secrets.
