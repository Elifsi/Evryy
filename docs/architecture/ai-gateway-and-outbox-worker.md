# AI Gateway & Outbox Retry Worker Architecture
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Overview & System Objectives

The final two operational pillars of the evrry backend are:
1. **Resilient Outbox Worker (`process-outbox`)**: Guarantees that invoices, OTPs, KYC decisions, and settlement statements are never lost even during third-party gateway downtime.
2. **Server-Side AI Gateway (`ai-gateway`)**: Protects OpenRouter / Gemini API credentials by executing all LLM inference server-side while integrating with user consent-gated memory (`public.user_memories`).

---

## 2. Resilient Outbox Worker (`process-outbox`)

```
[ Order Delivered / KYC Decision / Settlement Approved ]
                            │
                            ▼
        [ PostgreSQL Outbox: email_dispatch_queue ]
        • status = 'pending', attempts = 0
                            │
                            ▼ (Cron every 1 min or Webhook)
     [ Supabase Edge Function: process-outbox ]
     • Fetches up to 25 pending/failed jobs
     • Atomically locks records to 'processing'
     • Invokes send-email / Resend
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
        [ Succeeded ]               [ Failed ]
        • status = 'sent'           • attempts = attempts + 1
        • sent_at = now()           • If attempts >= 3: 'failed'
        • resend_id recorded        • Otherwise: 'pending' (retry)
```

---

## 3. Server-Side AI Gateway (`ai-gateway`)

### Core Capabilities

| Capability | Initiator | Action | Invariant |
|---|---|---|---|
| **AI Voice Concierge** | Consumer / Partner | `voice_concierge` | Automatically injects `get_ai_context(auth.uid())` if personalization consent is active. Never leaks API keys to phone bundles. |
| **Photo-to-Menu OCR** | Venue Merchant | `photo_to_menu` | Parses photographed paper menus into structured draft catalog items for partner manual verification before database commit. |
| **Kitchen Voice Toggle** | Restaurant Chef | `kitchen_voice` | Recognizes *"Chicken momo sakiyo"* and updates `catalog_items.is_available = FALSE` in real-time. |

---

## 4. Development Mock Mode vs Production

* **Development (Current Status)**:
  - If `OPENROUTER_API_KEY` or `GEMINI_API_KEY` is not present, the gateway operates in **Dev Mock Mode**.
  - Simulates contextual Nepali and English replies.
  - Returns authentic sample Nepali catalog items (Momo, Naan, Paneer Butter Masala) for menu OCR testing.
  - Toggles database availability for kitchen voice testing.
* **Production**:
  Set your API key via:
  ```bash
  supabase secrets set OPENROUTER_API_KEY="sk-or-v1-..."
  # or
  supabase secrets set GEMINI_API_KEY="AIzaSy..."
  ```
  The gateway automatically detects the secret and routes to Google Gemini 2.0 Flash / Claude 3.5 Haiku via OpenRouter.

---

## 5. Client Implementations

| Platform | Client Service | Key Methods |
|---|---|---|
| **Android Consumer (Kotlin)** | [`apps/consumer/android/.../EvrryAiService.kt`](file:///home/rahul/codes/Evrry/apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryAiService.kt) | `chatWithConcierge()` |
| **Android Partner (Kotlin)** | [`apps/partner/android/.../EvrryPartnerAiService.kt`](file:///home/rahul/codes/Evrry/apps/partner/android/src/main/kotlin/com/elifsi/evrry/partner/network/EvrryPartnerAiService.kt) | `parseMenuPhoto()`, `executeKitchenVoiceCommand()` |
| **iOS Consumer (Swift)** | [`apps/consumer/ios/.../EvrryAiService.swift`](file:///home/rahul/codes/Evrry/apps/consumer/ios/EvrryConsumer/Services/EvrryAiService.swift) | `chatWithConcierge()` |
| **iOS Partner (Swift)** | [`apps/partner/ios/.../EvrryPartnerAiService.swift`](file:///home/rahul/codes/Evrry/apps/partner/ios/EvrryPartner/Services/EvrryPartnerAiService.swift) | `parseMenuPhoto()`, `executeKitchenVoice()` |
| **Web (Next.js)** | [`apps/web/common/ai.ts`](file:///home/rahul/codes/Evrry/apps/web/common/ai.ts) | `chatWithConcierge()`, `parseMenuPhoto()` |
