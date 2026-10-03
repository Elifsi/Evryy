# Security Policy

Security and financial integrity are foundational to the **evrry** platform, developed by **Elifsi Technologies Private Limited**. This policy outlines security boundaries, secrets handling, and the process for reporting vulnerabilities.

---

## 1. Reporting a Vulnerability

Please **do not** open public GitHub issues for security vulnerabilities.

Instead, use GitHub's private vulnerability reporting:
[Report a vulnerability](https://github.com/Elifsi/Evrry/security/advisories/new) via this repository's Security tab.

Please include:
- A description of the vulnerability and its potential impact.
- Clear steps or a proof-of-concept to reproduce the issue.
- Any relevant logs, network requests, or screenshots.

All reports will be acknowledged promptly and reviewed with high priority.

---

## 2. Secrets Management & Credentials

### A. Supabase Credentials
- **`anon` Key (Public)**:
  - Permitted in client applications (Android, iOS, Web).
  - Access is strictly governed by PostgreSQL Row Level Security (RLS).
- **`service_role` Key (Secret)**:
  - **NEVER** placed in client application code, app bundles, `Info.plist`, Android resources, or public environment variables.
  - **NEVER** committed to Git or documented with real/staging values.
  - Used exclusively in server-side Supabase Edge Functions (`supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...`).

### B. Payment Provider Credentials
- Private merchant codes, HMAC secret keys, and webhook signing tokens for payment gateways (eSewa, Khalti, Fonepay, Card Gateway) must **NEVER** reside on client devices.
- Payment initiation, signature verification, and settlement requests occur exclusively server-side in Supabase Edge Functions.

---

## 3. Financial & Business Logic Security

- **Server-Side Financial Authority**:
  - The server is the sole source of truth for all monetary computations (order totals, delivery fees, taxes, partner commissions, net payouts).
  - Client applications must never send or dictate final payable amounts to backend payment endpoints.
- **Cardholder Data Protection**:
  - evrry does not handle, store, or transmit raw credit/debit card numbers (PAN, CVV).
  - Card processing relies on PCI-DSS certified hosted gateway fields, tokenization, or mobile wallet SDKs.
- **Ledger Immutability**:
  - Financial records (`transactions`, `partner_earnings`, `settlements`, `payouts`) are append-only.
  - Adjustments and refunds are recorded as distinct compensating ledger entries.

---

## 4. Authorization & Multi-Tenant Boundaries

- **Consumer Isolation**:
  - A consumer cannot read or modify another consumer's private profile, address book, active carts, orders, or direct messages.
- **Partner Isolation**:
  - Partner business data (catalog, orders, customer details, bank accounts, earnings) is strictly multi-tenant isolated via Row Level Security using `partner_id` constraints.
  - Partner A can never observe or query Partner B's operational or financial records.
- **Staff Role-Based Access Control**:
  - Partner staff members have scoped permissions. Cashiers and kitchen staff cannot access partner banking details, settlement records, or payout triggers.
- **Administrative Functions**:
  - Platform-wide admin capabilities (KYC approval, payout dispatch, dispute mediation) are restricted to dedicated administrative service roles and protected Edge Functions.

---

## 5. Scope: Prototype vs. Production

### In Scope for Prototype (`prototype/Phone/`)
- Web Cryptography API end-to-end encryption implementation (`lib/chat/crypto.ts`).
- WebSocket chat relay connection authentication challenge (`server/chat-relay.mjs`).
- WebRTC media signaling and session handling.
- Input validation on AI tool execution handlers (`app/api/ai/chat/route.ts`).

### In Scope for Production (`apps/` & `supabase/`)
- All production client authentication flows, token handling, and session storage.
- Supabase Row Level Security policies and database functions.
- Payment gateway integration adapters and webhook verification handlers.
- Partner payout calculation and disbursement logic.
