# Midnight Partner Settlement & ConnectIPS Disbursement Architecture
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Overview & Business Objectives

All merchant, restaurant, grocery, hotel, and rider earnings on the **evrry Super App** are reconciled through an immutable, append-only **double-entry general ledger** (`public.platform_ledger`).

Settlement payouts do not occur ad-hoc or manually per order. Instead, they are processed through a structured **Midnight Settlement Pipeline**:
1. **Automated Audit**: Reconciles daily gross revenues, platform commissions, 0% VAT, and rider COD cash-in-hand offsets.
2. **Superadmin Human-in-the-Loop Gate**: Draft batches are reviewed in the Superadmin Operations Console (`apps/web/admin`).
3. **NCHL ConnectIPS Interbank Rail**: Generates compliant interbank clearing files or direct API disbursements.
4. **Statement Dispatch**: Partners receive daily settlement statements with bank UTR tracking via Resend.

---

## 2. Settlement Execution Flow

```
[ Midnight (00:00 NPT) or Admin Trigger ]
                   │
                   ▼
  [ Supabase Edge Function: payout-execute (action: 'build_batch') ]
                   │
                   ▼
  [ Database RPC: public.admin_build_settlement_batch() ]
  • Queries public.partner_ledger_balances
  • Filters: credit_balance_paisa > 0 AND verified primary bank exists
  • For Riders: Offsets rider_cash_in_hand (COD collected) against payable
  • Creates draft settlement_batches and public.payouts
                   │
                   ▼
  [ Superadmin Review in Operations Console ]
  • Verifies net payout figures and bank account details
  • Clicks "Approve Batch" ──> calls admin_approve_settlement_batch()
                   │
                   ▼
  [ Execution: payout-execute (action: 'execute_batch') ]
  • Dispatches disbursements via ConnectIPS / Bank Rail
  • Generates NCHL UTR reference numbers
  • Calls mark_payout_paid() for each payout:
      - Debits partner payable account (merchant_payable / rider_payable / host_payable)
      - Credits bank_clearing
      - Credits rider_cash_in_hand (if COD offset applied)
      - Asserts ledger group is 100% balanced
  • Dispatches daily settlement receipt email via Resend
```

---

## 3. The 4 Operational Actions

| Action | HTTP Method | Initiator | Description |
|---|---|---|---|
| `build_batch` | POST | Cron (00:00) or Admin | Computes payables, offsets COD cash, and drafts `settlement_batches`. |
| `approve_batch` | POST | Superadmin | Approves draft batch for disbursement; locks figures from modification. |
| `execute_batch` | POST | Admin Console | Executes disbursement, commits ledger postings, and sends email statements. |
| `export_connectips` | GET / POST | Admin Console | Generates compliant CSV file for corporate banking bulk upload. |

---

## 4. ConnectIPS NCHL CSV Export Format

For institutions uploading bulk payments directly to corporate internet banking:
```csv
Batch_ID,Debit_Account,Beneficiary_Bank,Beneficiary_Branch,Beneficiary_Account,Beneficiary_Name,Amount_NPR,Reference_Remarks
"batch-uuid","0010100000000001","NABIL","Kathmandu","00123456789012","Himalayan Momo Corner","14500.00","evrry-payout-1"
```

---

## 5. Security & Invariant Rules

1. **Zero-Hub COD Balance Invariant**:
   - A rider holding NPR 4,000 in cash-in-hand who earned NPR 3,500 in delivery fees receives **NPR 0 in bank payout**. Their delivery fees offset their cash debt down to NPR 500, which carries forward.
2. **Verified Primary Bank Account Only**:
   - Payouts are never routed to unverified bank accounts. If a partner has not uploaded bank verification documents, their balance carries forward safely in `partner_ledger_balances`.
3. **Double-Entry Ledger Balancing**:
   - The Postgres constraint trigger `platform_ledger_balanced` runs at transaction commit. If debits do not equal credits down to the single paisa, the entire payout transaction rolls back.
