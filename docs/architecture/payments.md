# Payment Gateway Architecture

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  

**evryy** implements a streamlined, zero-liability **Payment Service** architecture. To eliminate the heavy regulatory burdens of operating a stored-value customer wallet under Nepal Rastra Bank (NRB) guidelines, **the in-app customer wallet has been completely removed**. Instead, all payments are initiated directly through trusted payment aggregators (**Fonepay**, **eSewa**, **Khalti**), card rails (**Visa, Mastercard, SCT** facilitated by eSewa & Khalti), and **Cash on Delivery (COD)**.

---

## 1. Supported Customer Payment Methods

```
┌────────────────────────────────────────────────────────────────────────┐
│                        evryy CHECKOUT MODAL                            │
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
  2. `remarks`: System-generated immutable invoice reference (e.g. `EVRYY-ORD-10492`).
  3. `expires_at`: 5 to 10 minute auto-expiration timestamp.
- **Screenshot & Friend Sharing**: Customers can take a screenshot of the QR and send it via WhatsApp or Viber to friends or family. The recipient opens their bank app, taps **"Scan from Gallery"**, and authorizes the exact amount with their MPIN/biometrics.
- **Blurring & Auto-Processing**:
  - While awaiting payment confirmation, the QR screen displays an animated progress overlay (*"Processing payment... Please do not close"*).
  - The millisecond the bank approves the transfer, Fonepay fires an encrypted server-to-server webhook (IPN).
  - The server verifies the HMAC signature, updates `orders.status = 'paid'`, and emits a Supabase Realtime broadcast.
  - The customer's screen instantly triggers a success checkmark and auto-advances to the order tracking/receipt view without requiring any manual button click.

### B. Hosted Redirect Flow (eSewa, Khalti, Fonepay Direct)
- **Zero-Credential Security**: **evryy NEVER collects, sees, or handles customer passwords, PINs, or SMS OTPs.**
- **Redirection & Deep-Linking**:
  1. The user selects **eSewa**, **Khalti**, or **Fonepay Direct**.
  2. The server requests a payment session and returns a secured URL or custom scheme (`esewa://`, `khalti://`, `fonepay://`).
  3. The mobile app opens the provider's official hosted sheet via Chrome Custom Tabs or Safari View Controller.
  4. The customer logs in and enters their SMS OTP on the **gateway's official server page**.
  5. Upon authorization, the gateway redirects back to evryy via deep-link callback:
     `evryy://checkout/callback?status=success&pidx=...`
  6. Simultaneously, the gateway fires an asynchronous server webhook to confirm transaction settlement.

### C. Cards via Khalti & eSewa (3D-Secure Hosted Gateway)
- Rather than maintaining custom card storage or foreign payment gateways, **evryy** leverages the built-in card processing rails of **Khalti** and **eSewa**:
  - Supports **Visa**, **Mastercard**, **SCT (Smart Choice Technologies)**, and domestic UnionPay cards.
  - Hosted directly within the certified PCI-DSS Level 1 gateway sheets of Khalti and eSewa.
  - Bank 3D-Secure OTP verification occurs entirely on the issuer bank's portal.
  - Zero raw cardholder data (PAN, CVV, expiry dates) is ever stored or transmitted through evryy servers.

### D. Cash on Delivery (COD)
- Available for physical goods delivery (Food, Grocery, Retail).
- **Order Placement**: Order transitions immediately to `confirmed` with `payment_method = 'cod'` and `payment_status = 'pending_delivery'`.
- **Fulfillment**: The delivery rider collects physical cash upon arrival.
- **Handshake Verification**: The customer provides a 4-digit delivery OTP to the rider; the rider inputs the OTP in the Rider HUD to confirm handoff and cash collection.
- **Midnight Rider Cash Reconciliation**: The rider's platform cash account is debited for the collected order total and platform commission during the midnight settlement cycle.

---

## 3. End-to-End Architecture Flowchart

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CUSTOMER CHECKOUT IN evryy                            │
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
│ Webhook (/payments/callback)│ │ evryy://checkout/success│            │
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

- **No NRB Stored-Value Wallet Burden**: Because evryy does not hold customer funds in in-app wallets, it operates as a standard technology marketplace platform under Nepal Rastra Bank e-commerce regulations.
- **Credential Isolation**: Customer bank passwords, PINs, and OTPs never touch evryy servers or client apps.
- **Cryptographic Signature Verification**: Every webhook payload from eSewa, Khalti, and Fonepay is verified against provider public certificates and HMAC-SHA256 secret keys stored in Supabase secrets.
