# supabase/functions/ — Supabase Edge Functions Developer Guide

This directory is designated for server-side TypeScript Edge Functions running on the Deno runtime for privileged operations, payment integrations, and partner payout disbursements.

## Status

✅ **Active Production Functions (100% Implemented)**:
- `send-email/`: Universal Resend email dispatch engine serving Android (Kotlin), iOS (Swift), Web (Next.js), and PostgreSQL outbox triggers.
- `send-sms/`: Universal Nepal SMS OTP engine supporting Sparrow SMS, Aakash SMS, Dev Mock Mode, and database-level anti-bombing rate limits.
- `payment-initiate/`: Direct Nepal payment session creator for eSewa ePay v2 (HMAC-SHA256), Khalti ePayment v2 (pidx), and Fonepay dynamic QR.
- `payment-verify/`: Direct payment gateway verification receiver executing atomic ledger postings via `public.confirm_payment()`.
- `payout-execute/`: Midnight settlement batch auditor, ConnectIPS NCHL exporter, and partner disbursement engine.
- `push-notify/`: High-priority FCM v1 and APNs notification engine with dead-token cleanup.
- `process-outbox/`: Resilient outbox retry worker processing pending/failed email and notification jobs.
- `ai-gateway/`: Server-side AI Concierge, Photo-to-Menu Vision OCR, and Kitchen Voice command router with user consent memory injection.

---

## 1. Payment Service Functions Specification

### Function 1: `payment-initiate/`
* **Purpose**: Creates an authenticated payment session with a selected payment provider.
* **Developer Instructions**:
  * Implement the Payment Service abstraction dispatching to provider adapters:
    * `esewa`: Generates ePay v2 signature (`total_amount`, `transaction_uuid`, `product_code`) using HMAC-SHA256.
    * `khalti`: Calls Khalti ePayment v2 `/epayment/initiate/` endpoint with public key. Facilitates card, bank, and wallet payments directly in Khalti Checkout.
    * `fonepay`: Generates dynamic merchant QR payload and interbank payment string.
    * `card`: Dispatches to dedicated card gateway adapter if one is configured, or routes through provider checkout.
  * **Critical Requirement**: Compute order total server-side from `public.order_items`. Never trust client-sent amounts.
  * Inserts a record into `public.payments` with `status = 'pending'`.
  * Returns redirect URL, QR data, or session token to client application.

### Function 2: `payment-verify/`
* **Purpose**: Webhook listener and callback receiver for payment gateway completion.
* **Developer Instructions**:
  * Verify incoming request authenticity using provider-specific cryptographic signatures:
    * Validate eSewa HMAC signature using merchant secret key.
    * Call Khalti `/epayment/lookup/` endpoint to confirm settlement status.
    * Verify Fonepay server-to-server callback hash and IP whitelisting.
  * Enforce **idempotency**: If `payments.status` is already `'completed'`, return HTTP 200 without duplicate processing.
  * Transition `payments.status = 'completed'`.
  * Advance `orders.status` to `'confirmed'`.
  * Insert double-entry ledger record into `public.transactions`.

---

## 2. Partner Payout Subsystem Specification

### Function 3: `payout-execute/`
* **Purpose**: Executes automated or admin-approved partner payout batches.
* **Developer Instructions**:
  * Query unsettled `public.partner_earnings` grouped by `partner_id`.
  * Compute net payout: `SUM(gross_amount) - SUM(platform_fee) - SUM(tax_withheld) - adjustments`.
  * Dispatches disbursement via banking rail / IPS adapter (e.g. NCHL-IPS / ConnectIPS / Bank API).
  * Records bank transaction reference number in `public.payouts`.
  * Mark corresponding earnings as `is_settled = TRUE`.
  * Security: Restrict invocation strictly to cron service role or platform admin JWT claims.

---

## 3. Other Planned Edge Functions

* **`ai-concierge-chat/`**: Server-side tool execution loop for catalog queries and order drafting (protects Gemini / Claude / OpenRouter API keys).
* **`push-notify/`**: High-priority push notifications to Android (FCM) and iOS (APNs) clients for new incoming orders and driver updates.

---

## Edge Function Security Rules

1. **Zero Client Secrets**: All gateway merchant credentials, secret keys, and webhook signing tokens must be stored in Supabase secrets via `supabase secrets set <KEY>=<VALUE>`.
2. **Never Commit Private Keys**: No `.env` files with secret values should ever be committed to Git.
3. **Strict Validation**: Validate all incoming HTTP payloads against Zod schemas.
4. **Zero Raw Card Storage**: Never handle or log raw credit card numbers (PAN) or CVVs.
