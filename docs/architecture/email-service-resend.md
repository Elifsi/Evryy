# Email Service Architecture: Resend Integration Guide
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Core Principle: Zero Client-Side Secrets

In mobile application security (OWASP MASVS), **client-facing binaries must NEVER store third-party secret API keys**.

```
❌ WRONG (Insecure Anti-Pattern):
[ Android APK (Kotlin) ] ──(RESEND_API_KEY embedded)──> [ Resend API ]
   ↳ Decompilation via jadx-gui takes 10 seconds.
   ↳ Attacker extracts RESEND_API_KEY.
   ↳ Attacker sends millions of scam/phishing emails from @evrry.com.
   ↳ Domain blacklisted globally; massive financial liability.

✅ CORRECT (Enterprise evrry Architecture):
[ Android (Kotlin) ] ──┐
[ iOS (Swift) ]     ────┼──(User JWT / RPC)──> [ Supabase Edge Function ] ──(Secure RESEND_API_KEY)──> [ Resend API ]
[ Web (Next.js) ]   ───┘                              │
                                                      ▲
[ PostgreSQL (orders table) ] ──(Delivered Trigger)───┘
```

All transactional and verification emails are dispatched through the centralized **Supabase Edge Function** (`supabase/functions/send-email/index.ts`). Client applications (Kotlin, Swift, Next.js) invoke this function using standard Supabase SDKs without holding any secret credentials.

---

## 2. Dispatch Channels & Supported Actions

The `send-email` Edge Function supports four primary action types and one generic fallback:

| Action | Primary Trigger | Target Recipient | Content |
|---|---|---|---|
| `order_invoice` | PostgreSQL Trigger on order `status = 'delivered'` or client manual resend | Customer | Responsive HTML Tax Invoice (0% VAT, itemized bill, PAN, delivery address) |
| `verification_otp` | User signup / phone+email verification flow | Customer / Partner | 6-digit OTP code with 10-minute expiry and brand styling |
| `partner_kyc_status` | Admin Operations Console approval or rejection | Merchant / Host / Rider | Acceptance announcement OR specific document correction reason |
| `payout_statement` | Midnight Settlement Batch Cron (`payout-execute`) | Merchant / Host | Interbank transfer amount, UTR reference, masked bank account |
| `custom` | Admin announcement or high-priority security alert | User | Custom subject and HTML body |

---

## 3. Implementation in Native Android (Kotlin)

Native Android clients (`apps/consumer/android` and `apps/partner/android`) use the official Supabase Kotlin SDK (`io.github.jan-tennert.supabase:functions-kt`).

### Service Implementation
Location: [`apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryEmailService.kt`](file:///home/rahul/codes/Evrry/apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryEmailService.kt)

```kotlin
// Example: Requesting an email OTP verification code
val emailService = EvrryEmailService(supabaseClient)

viewModelScope.launch {
    val result = emailService.sendVerificationOtp(
        toEmail = "customer@example.com",
        otpCode = "481920",
        recipientName = "Aayush Sharma"
    )
    result.onSuccess { response ->
        Log.d("EvrryAuth", "Verification code dispatched successfully: ${response.id}")
    }.onFailure { error ->
        Log.e("EvrryAuth", "Failed to dispatch OTP", error)
    }
}
```

---

## 4. Implementation in Native iOS (Swift)

Native iOS clients (`apps/consumer/ios` and `apps/partner/ios`) use the official `supabase-swift` SDK.

### Service Implementation
Location: [`apps/consumer/ios/EvrryConsumer/Services/EvrryEmailService.swift`](file:///home/rahul/codes/Evrry/apps/consumer/ios/EvrryConsumer/Services/EvrryEmailService.swift)

```swift
// Example: Requesting an order invoice resend in iOS
let emailService = EvrryEmailService(client: supabaseClient)

Task {
    do {
        let response = try await emailService.sendOrderInvoice(
            to: "customer@example.com",
            invoiceData: invoicePayload
        )
        print("Invoice email sent! Resend ID: \(response.id ?? "n/a")")
    } catch {
        print("Failed to dispatch invoice: \(error.localizedDescription)")
    }
}
```

---

## 5. Implementation in Web (Next.js / TypeScript)

Location: [`apps/web/common/email.ts`](file:///home/rahul/codes/Evrry/apps/web/common/email.ts)

Used by:
- `apps/web/admin` (KYC approvals and financial statements)
- `apps/web/partner` (Store manager receipts and invitations)
- `apps/web/consumer` (Web ordering invoices)

```typescript
import { EvrryWebEmailClient } from '@/common/email';

const emailClient = new EvrryWebEmailClient();

// Send Partner KYC approval from Admin Console
await emailClient.sendPartnerKycStatus(
  'himalayan.momo@gmail.com',
  'Himalayan Momo & Sekuwa Corner',
  true // Approved
);
```

---

## 6. Automated Invoicing via PostgreSQL Outbox Pattern

To eliminate human error or mobile app crashes preventing invoices from reaching customers, **Migration 0013** introduces an automated database trigger:

- **Trigger**: `trg_queue_order_delivered_invoice` on `public.orders`
- **Condition**: Fires whenever `NEW.status = 'delivered'`
- **Action**:
  1. Queries customer email and phone from `public.profiles`.
  2. Queries merchant trade name and PAN number from `public.stores` and `public.partner_profiles`.
  3. Formats line items and pricing breakdown (subtotal, delivery fee, 0% VAT, platform fee).
  4. Inserts job into `public.email_dispatch_queue` with status `'pending'`.
  5. The `ON CONFLICT (reference_id, action) DO NOTHING` clause guarantees that an invoice is **never** sent twice for the same order.

---

## 7. Environment Setup & Deployment

### Supabase CLI Commands
Set your Resend API credentials securely in Supabase:

```bash
# 1. Set Resend API Key in Supabase production/staging secrets
supabase secrets set RESEND_API_KEY="re_123456789_abcdefg"

# 2. Set default verified sender email
supabase secrets set RESEND_FROM_EMAIL="evrry <noreply@evrry.com>"

# 3. Deploy the Edge Function
supabase functions deploy send-email
```

### Local Development / Mock Mode
When running locally without a live Resend key:
- If `RESEND_API_KEY` is omitted, the Edge Function automatically switches to **Mock Mode**.
- It prints the rendered email, recipient, and subject directly to the local Supabase terminal/console.
- Returns `{ success: true, mock: true, id: "mock_edge_..." }`.
- Allows end-to-end testing in Android, iOS, and Web without burning API quotas.
