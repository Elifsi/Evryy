# Nepal Payment Gateway Architecture: Direct Rails (eSewa, Khalti, Fonepay)
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Regulatory Context & Core Principles

Under Nepal Rastra Bank (NRB) Payment Systems Department regulations, super apps and marketplaces cannot hold open-loop customer digital wallets without acquiring a Payment Service Provider (PSP) license.

Therefore, the **evrry Super App** operates on a **100% Direct Rail & Zero-Hub COD Architecture**:
1. **Zero Customer Wallet**: Customers pay directly via bank accounts or digital wallets (**Fonepay QR**, **eSewa**, **Khalti**, **SCT/Visa/MasterCard**).
2. **Server-Side Pricing Authority**: Mobile APKs and web clients **never** specify or pass payable amounts to gateways. The backend (`payment-initiate`) retrieves authoritative totals from the database (`orders.total_paisa`) to prevent price tampering.
3. **Double-Entry Ledger Integrity**: Successful payments invoke `public.confirm_payment()`, updating order state to `'acknowledged'` and posting balancing entries to `public.platform_ledger`.

---

## 2. Supported Direct Rails

```
[ Customer selects Payment Method on Android / iOS / Web ]
                            │
                            ▼
      [ Supabase Edge Function: payment-initiate ]
      • Queries orders.total_paisa server-side
      • Generates secure gateway payload
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
 [ eSewa ePay v2 ]   [ Khalti v2 ]      [ Fonepay QR ]
 • Computes HMAC-    • Calls /epayment/  • Generates dynamic
   SHA256 signature    initiate/           EMVCo QR string
 • Returns form data • Returns pidx +    • Displays QR in app
   for webview         checkout URL
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
              [ User Completes Payment ]
                            │
                            ▼
      [ Supabase Edge Function: payment-verify ]
      • eSewa: Calls status query API (?product_code=...&transaction_uuid=...)
      • Khalti: Calls /epayment/lookup/ with pidx
      • Fonepay: Validates server callback hash
                            │
                            ▼
      [ Database RPC: public.confirm_payment() ]
      • Validates paid amount == payable total
      • Updates order status: 'draft' -> 'acknowledged'
      • Inserts into public.payments (idempotent unique key)
      • Posts balanced double-entry ledger entries
```

---

## 3. Gateway Technical Specifications

### A. eSewa ePay v2
- **Protocol**: Form POST redirect or WebView load.
- **HMAC-SHA256 Signature**:
  - Signed string: `total_amount=${totalNpr},transaction_uuid=${uuid},product_code=${code}`
  - Standard Sandbox Test Secret: `8gBm/:&EnhH.1/q`
  - Sandbox Product Code: `EPAYTEST`
  - Sandbox Endpoint: `https://rc-epay.esewa.com.np/api/epay/main/v2/form`
  - Production Endpoint: `https://epay.esewa.com.np/api/epay/main/v2/form`
- **Verification**: Edge function queries eSewa's transaction status API server-to-server (`/api/epay/transaction/status/`).

### B. Khalti ePayment v2
- **Protocol**: Direct REST API session initiation.
- **Initiate Endpoint**: `POST https://khalti.com/api/v2/epayment/initiate/` (Sandbox: `https://a.khalti.com/api/v2/epayment/initiate/`)
- **Key Header**: `Authorization: Key <secret_key>`
- **Amount Unit**: **Paisa** (Integer, e.g. NPR 150.00 = `15000`).
- **Response**: Returns unique `pidx` and `payment_url`.
- **Verification**: Edge function queries `POST /api/v2/epayment/lookup/` with `{ pidx }`. Status must equal `"Completed"`.

### C. Fonepay Dynamic Merchant QR
- **Protocol**: Dynamic EMVCo QR code string generated per order.
- **Payload**: Contains merchant code, PRN (Product Reference Number), and total amount.
- **Customer UX**: Customer scans QR using any Nepal bank mobile banking app (NIC Asia, Nabil, Global IME, etc.) or Fonepay app.

---

## 4. How to Test in Development / Sandbox Mode

The backend operates in **Sandbox Mode** by default:
* **eSewa**: Pre-configured with official eSewa UAT credentials (`EPAYTEST`). You can test with test eSewa credentials.
* **Khalti**: Pre-configured with sandbox test keys. Returns active sandbox test payment sessions.
* **Fonepay**: Simulates successful QR verification for instant developer workflow.

---

## 5. How to Go Live in Production (Setting Secrets)

When merchant agreements are finalized with eSewa, Khalti, and Fonepay, set your credentials via Supabase CLI:

```bash
# 1. eSewa Production Credentials
supabase secrets set ESEWA_PRODUCT_CODE="YOUR_LIVE_PRODUCT_CODE"
supabase secrets set ESEWA_SECRET_KEY="YOUR_LIVE_HMAC_SECRET"

# 2. Khalti Production Secret Key
supabase secrets set KHALTI_SECRET_KEY="live_secret_key_..."

# 3. Fonepay Production Merchant Code
supabase secrets set FONEPAY_MERCHANT_CODE="YOUR_FONEPAY_MERCHANT_CODE"
```

The Edge Functions immediately switch from Sandbox to Live production routing with **zero code changes**.

---

## 6. Client Implementations

| Platform | Client Service | Key Methods |
|---|---|---|
| **Android (Kotlin)** | [`apps/consumer/android/.../EvrryPaymentService.kt`](file:///home/rahul/codes/Evrry/apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryPaymentService.kt) | `initiatePayment()`, `verifyPayment()` |
| **iOS (Swift)** | [`apps/consumer/ios/.../EvrryPaymentService.swift`](file:///home/rahul/codes/Evrry/apps/consumer/ios/EvrryConsumer/Services/EvrryPaymentService.swift) | `initiatePayment()`, `verifyPayment()` |
| **Web (Next.js)** | [`apps/web/common/payment.ts`](file:///home/rahul/codes/Evrry/apps/web/common/payment.ts) | `initiatePayment()`, `verifyPayment()` |
