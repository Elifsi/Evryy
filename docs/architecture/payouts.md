# Partner Payout & Financial Architecture

**evrry** (developed by **Elifsi Technologies Private Limited**) strictly separates inward customer collections from outward partner payouts.

When a consumer pays for an order, the funds are collected into the platform's escrow/clearing accounts. The platform accounts for partner earnings, deducts platform commission, handles adjustments, and subsequently settles net funds to partners according to defined settlement cycles.

---

## 1. Payout Subsystem Topology

```
                  ┌────────────────────────────────────────┐
                  │            Consumer Payment            │
                  │   (eSewa / Khalti / Fonepay / Card)    │
                  └───────────────────┬────────────────────┘
                                      │ Verified by Edge Function
                                      ▼
                  ┌────────────────────────────────────────┐
                  │       Payment & Ledger Subsystem       │
                  │       (Records immutable debit)        │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │            Partner Earnings            │
                  │  Gross Order - Platform Fee = Net Due  │
                  └───────────────────┬────────────────────┘
                                      │ Scheduled Settlement Cycle
                                      ▼
                  ┌────────────────────────────────────────┐
                  │           Settlement Engine            │
                  │   (Aggregates earnings & adjustments)  │
                  └───────────────────┬────────────────────┘
                                      │ Generates payout batch
                                      ▼
                  ┌────────────────────────────────────────┐
                  │             Partner Payout             │
                  │      (Disbursement & Bank Transfer)    │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │    Bank / IPS / Payout Rail Adapter    │
                  │ (NCHL-IPS, ConnectIPS, Direct Bank API)│
                  └────────────────────────────────────────┘
```

---

## 2. Core Financial Data Entities

To maintain strict auditability, the system separates financial concepts into dedicated entities rather than combining them into a generic "payment" table:

| Entity | Purpose | Key Attributes |
|---|---|---|
| **`orders`** | Business transaction describing purchased items | `id`, `consumer_id`, `partner_id`, `subtotal`, `status` |
| **`payments`** | Consumer payment transaction attempt | `id`, `order_id`, `provider`, `gateway_ref`, `amount`, `status` |
| **`transactions`** | Immutable double-entry financial ledger | `id`, `account_id`, `type` (`credit`/`debit`), `amount`, `reference_id` |
| **`partner_earnings`** | Earning record calculated per completed order | `order_id`, `gross_amount`, `platform_fee`, `tax`, `net_payable` |
| **`refunds`** | Partial or full reversal of a payment | `payment_id`, `amount`, `reason`, `processed_at`, `status` |
| **`settlements`** | Periodic aggregation of unpaid partner earnings | `partner_id`, `cycle_start`, `cycle_end`, `total_amount`, `status` |
| **`payouts`** | Actual disbursement transaction sent to partner bank | `settlement_id`, `bank_account_id`, `payout_ref`, `status` |

---

## 3. Financial Calculation Principles

1. **Server-Side Exclusivity**:
   - Financial calculations (commission deductions, VAT withholding, net earning calculations) occur exclusively in PostgreSQL stored procedures or Supabase Edge Functions.
   - Client applications never compute partner earnings or apply fee percentages locally.
2. **Auditability & Immutability**:
   - Financial ledger entries cannot be modified or deleted (`UPDATE` and `DELETE` privileges are revoked; corrections require compensating journal entries).
3. **Dispute & Refund Accounting**:
   - When a refund is granted, the settlement engine deducts the refunded amount from the partner's pending settlement balance or generates a negative adjustment entry.
7. **Disbursement Decoupling**:
   - Settlement batches can be reviewed by finance administrators prior to execution or automated based on partner trust tier.
   - Payout gateway failures (e.g. incorrect account number, bank network downtime) mark the payout as `failed` and return the balance to `unsettled` without modifying historical order records.

---

## 4. Automated Driver & Restaurant Payout Pipeline

Manual bank transfers to hundreds of delivery riders and merchants every night are not scalable. The platform integrates direct interbank settlement rails:

### A. Partner Bank Account Onboarding
Partners, drivers, and riders submit bank credentials through the partner app:
- Account Holder Legal Name (validated against citizen ID / PAN)
- Bank Name and Branch Code
- Bank Account Number

### B. Midnight Batch Settlement Engine (connectIPS / Khalti Payout API)
Every midnight (`00:00 NPT`), a scheduled Supabase Edge Function / Celery worker triggers the automated settlement pipeline:

#### 1. Merchant / Restaurant Settlement Formula
$$\text{Net Merchant Payout} = (\text{Total Online + COD Sales}) - (\text{Platform Commission \%}) - (\text{Refund Deductions})$$
- Merchants receive their full payout digitally via connectIPS/Khalti regardless of whether customers paid online or via Cash on Delivery (COD).

#### 2. Delivery Rider Settlement & Cash Reconciliation Formula
$$\text{Net Rider Payout} = (\text{Delivery Fares Earned}) + (\text{Tips}) - (\text{Cash on Delivery Collected in Hand})$$
- If the rider collected more physical cash from customers than their earned delivery fees, their net balance is negative (they owe the platform cash), which is deducted from their next shift's earnings or settled via dynamic Fonepay QR deposit.
- If their earned delivery fees exceed the cash in hand, the difference is automatically deposited directly to their registered bank account via connectIPS.

1. **Aggregation**: Aggregates all completed orders between `yesterday 00:00` and `23:59:59` that are not flagged or in dispute.
2. **Double-Entry Record**: Deducts pending partner balance and credits an outward payout record in `payouts` with status `processing`.
3. **NCHL connectIPS / Khalti Payout Execution**: Dispatches batch disbursement API calls with cryptographic checksums directly to the banking network.
4. **Reconciliation**: On receiving bank confirmation webhooks, transitions payout rows to `completed` and generates an itemized PDF remittance receipt in Supabase Storage.
