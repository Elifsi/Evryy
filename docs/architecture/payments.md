# Payment Gateway Architecture

**evryy** (developed by **Elifsi Technologies Private Limited**) implements a modular **Payment Service** abstraction with provider adapters designed to handle regional wallets, bank networks, and card payments cleanly without tight coupling or unnecessary duplication.

---

## 1. Supported Payment Methods & Rails

The platform supports the following customer-facing payment options:
- **Khalti Epay v2** (Mobile wallet, e-banking, SCT cards, Visa/Mastercard via Khalti Checkout)
- **eSewa Direct** (Mobile wallet, signed HMAC-SHA256 token verification, ePay flow)
- **Fonepay** (Interbank QR rails & merchant payment network)
- **Card Payments** (Debit/Credit cards facilitated via Khalti/eSewa or dedicated Card Gateway)
- **In-App evryy Wallet** (Instant balance stored in Supabase with double-entry ledger)

### Important Architectural Nuance: Card Handling
Card payments are **not** assumed to be a completely separate gateway by default:
- **Provider-Facilitated Cards**: In many regional integrations, gateways like **Khalti** or **Fonepay** already provide or facilitate card payment processing (Visa, Mastercard, SCT, UnionPay, domestic/international debit and credit cards) directly within their hosted checkout workflows.
- **No Unnecessary Duplication**: The platform does not create redundant, parallel card infrastructure when an active gateway adapter (e.g. Khalti) already handles card processing under the merchant agreement.
- **No Over-Assumption**: We do not assume Khalti or Fonepay will cover every future card scenario (e.g. specialized international cards, multi-currency processing, or direct merchant acquirers).
- **Extensible Card Gateway Adapter**: The architecture cleanly accommodates a dedicated, standalone **Card Gateway Adapter** (e.g. Stripe, Cybersource, Himalayan Bank Payment Gateway) as an optional/future component when a specific dedicated card processor is selected.

---

## 2. Payment Service & Provider Adapter Hierarchy

```
                          ┌───────────────────────────┐
                          │    Consumer Application   │
                          │   (Android / iOS / Web)   │
                          └─────────────┬─────────────┘
                                        │ 1. Select payment method
                                        │    (eSewa, Khalti, Fonepay, Card)
                                        ▼
                          ┌───────────────────────────┐
                          │      Payment Service      │
                          │ (Server-Side / Edge Fns)  │
                          └─────────────┬─────────────┘
                                        │ 2. Dispatches to selected adapter
            ┌───────────────────────────┼───────────────────────────┐
            ▼                           ▼                           ▼
   ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
   │  eSewa Adapter  │         │ Khalti Adapter  │         │ Fonepay Adapter │
   │ (ePay v2 / QR)  │         │ (Wallet + Cards/│         │ (Interbank QR / │
   │                 │         │  Bank checkout) │         │  Direct Rails)  │
   └─────────────────┘         └─────────────────┘         └─────────────────┘
                                        │
                                        ▼ (Optional / Future)
                               ┌─────────────────┐
                               │  Card Gateway   │
                               │     Adapter     │
                               │ (Dedicated card │
                               │  processor)     │
                               └─────────────────┘
```

---

## 3. Core Architecture Rules

### A. Provider Credential Isolation
- All API keys, merchant codes, secret keys, and webhook verification secrets reside **exclusively on the server** (stored securely via `supabase secrets set`).
- Client applications (Android, iOS, Web) NEVER receive, store, or inspect provider credentials.

### B. Hosted / Tokenized Security (Zero Raw Card Storage)
- **Never collect, transmit, or store raw card numbers (PAN), CVV, or card expiration dates** in the evryy database or application servers.
- All card flows utilize:
  1. Provider-hosted payment pages (Khalti / eSewa / Fonepay / Gateway redirect), OR
  2. PCI-DSS Level 1 compliant tokenized SDK elements if direct in-app card entry is later required.
- The evryy database stores only non-sensitive tokens (e.g., `provider_transaction_id`, payment method label like `"Khalti (Visa *4242)"`, status, and timestamp).

### C. Server-Side Financial Authority
- The server is the sole authority on order pricing: subtotals, item customizations, delivery fees, service fees, discounts, and taxes are calculated server-side before initiating any payment session.
- The client cannot alter the payable amount sent to the gateway.

### D. Separation of Backend Financial Concepts
The backend treats the following as **distinct, decoupled entities**:
- **`payments`**: Individual inward payment attempts from a customer to the platform.
- **`refunds`**: Reversals of customer payments back to the original funding source.
- **`transactions`**: Immutable double-entry ledger entries documenting debits and credits.
- **`settlements`**: Scheduled aggregation cycles calculating net merchant balances.
- **`payouts`**: Outward bank disbursements from the platform to partner bank accounts.

---

## 4. Payment Adapter Interface (Conceptual Contract)

```typescript
export type PaymentMethodSelection = 'esewa' | 'khalti' | 'fonepay' | 'card';

export interface PaymentInitiationRequest {
  paymentId: string;
  orderId: string;
  amountInPaisa: number;
  currency: 'NPR' | 'USD';
  customer: {
    id: string;
    name: string;
    email?: string;
    phone?: string;
  };
  callbackUrl: string;
  returnUrl: string;
}

export interface PaymentInitiationResult {
  paymentId: string;
  provider: PaymentMethodSelection;
  providerSessionId?: string;
  redirectUrl?: string;
  qrData?: string;
  expiresAt: string;
}

export interface PaymentVerificationResult {
  paymentId: string;
  providerTransactionId: string;
  status: 'completed' | 'failed' | 'cancelled' | 'pending';
  verifiedAmount: number;
  paidVia?: string; // e.g. "wallet", "card_visa", "bank_transfer"
  rawResponse: Record<string, unknown>;
}

export interface PaymentProviderAdapter {
  providerId: PaymentMethodSelection;
  
  // Initiates an authenticated payment session with the provider
  initiate(request: PaymentInitiationRequest): Promise<PaymentInitiationResult>;
  
  // Verifies the payment with the provider via server webhook or status query
  verify(payload: Record<string, unknown>, signature?: string): Promise<PaymentVerificationResult>;
  
  // Initiates a partial or full refund through the provider if supported
  refund?(paymentId: string, amountInPaisa: number, reason: string): Promise<boolean>;
}
```

---

## 5. Execution Flow

1. **Order Checkout**: Consumer requests order placement in `apps/consumer/` or `apps/web/consumer/`.
2. **Server Initiation**: `supabase/functions/payment-initiate/` calculates total, creates a `pending` row in `payments`, and delegates to the appropriate provider adapter.
   - If the user selects **Card**, the Payment Service evaluates whether card processing is routed through an enabled gateway (e.g. Khalti Checkout with Card enabled) or through a dedicated Card Gateway Adapter.
3. **Customer Authorization**: The customer authorizes payment via wallet deep-link, web redirect, or scanned QR code.
4. **Server Verification**: `supabase/functions/payment-verify/` receives the callback/webhook, cryptographically validates signatures, ensures idempotency, and updates `payments.status = 'completed'`.
5. **Ledger & Order Advancement**: A database trigger or Edge Function records the immutable transaction in `transactions` and transitions the order to `acknowledged`.

---

## 6. Nepal Fintech Endpoint Contracts & Automated Refunds

### A. Khalti Epay v2 Flow
1. **Initiate**: Mobile client calls `/api/v2/epay/initiate/` on the server backend.
   - Request: `return_url`, `website_url`, `amount` (in paisa), `purchase_order_id`, `purchase_order_name`.
   - Backend receives `pidx` (Payment Index) and `payment_url`.
2. **Checkout**: Mobile client mounts `payment_url` in an in-app browser or native Khalti bottom sheet.
3. **Webhook Callback**: On authorization, Khalti dispatches a secure POST to `/api/v1/payments/khalti/callback` containing `{ pidx, txnId, amount, status }`.
4. **Verification**: Server issues a lookup request to Khalti's `/api/v2/epay/lookup/` with `{ pidx }` to verify authenticity before unlocking order fulfillment.

### B. eSewa Direct Integration
- Signed HMAC-SHA256 signature calculated over:
  `total_amount,transaction_uuid,product_code`
- Verified server-side against eSewa's public verification endpoint.

### C. Automated Refunds Engine
When a merchant declines an order or no delivery rider accepts within 7 minutes:
- **Option 1 (Instant / Default)**: Instant credit to the customer's in-app **evryy Wallet** balance in PostgreSQL, usable immediately across any other service vertical with zero gateway turnaround.
- **Option 2 (Gateway Reversal)**: Automated API invocation to Khalti's `/api/v2/payment/refund/` using the original `pidx` and reference ID, releasing funds directly back to the source bank/wallet within standard banking settlement windows.
