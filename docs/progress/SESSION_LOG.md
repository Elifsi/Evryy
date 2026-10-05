# EVRRY Super App — Master Session & Progress Log
**Elifsi Technologies Private Limited**  
*Repository: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)*  
*Last Updated: 2026-10-05*

> **ORIENTATION FOR ANY NEW AI OR DEVELOPER**:  
> Read this single document before touching any code. It documents the exact current state of the platform, the architecture invariants that must NEVER be violated, and what has been built across all sessions.

---

## 1. Golden Architecture Invariants (MUST ALWAYS FOLLOW)

1. **Zero Client Secrets**:
   - Native Android (Kotlin), iOS (Swift), and Web (Next.js) client apps must **NEVER** hold third-party API keys (`RESEND_API_KEY`, `SPARROW_SMS_TOKEN`, `ESEWA_SECRET_KEY`, `KHALTI_SECRET_KEY`, `FIREBASE_SERVICE_ACCOUNT`, `OPENROUTER_API_KEY`).
   - All third-party integrations run server-side in **Supabase Edge Functions** (`supabase/functions/`).
2. **Double-Entry General Ledger (`public.platform_ledger`)**:
   - Every financial transaction must be posted in balanced pairs (debits = credits).
   - Postgres trigger `assert_ledger_group_balanced()` enforces that an unbalanced posting rolls back the transaction.
3. **Nepal Pre-Registration 0% VAT Policy**:
   - The platform starts pre-VAT registration with `vat_bps = 0` (0%).
   - Stored in `public.platform_settings`. When IRD registration completes, changing this to `1300` (13%) activates VAT platform-wide with zero code changes.
4. **Zero-Hub COD Digital Settlement**:
   - No cash counters or physical branch visits for delivery riders.
   - Cash-in-hand is reconciled automatically via: (a) earnings offset during midnight settlement, (b) digital reverse QR payment (`settle_rider_cod_digital`), or (c) admin reconciliation.
   - Soft limit: `rider_cod_limit_paisa = 500000` (NPR 5,000).
5. **Mobile vs. Web Scope Separation**:
   - **Mobile Partner App (`apps/partner`)**: Contains **all 5 verticals** (Food, Grocery, Cabs, Hotels, Rentals) because smartphone cameras are essential for menu OCR/room photos, and mobile GPS is essential for driving/riding.
   - **Web Partner Dashboard (`apps/web/partner`)**: Strictly for **stationary venue merchants & hosts** (restaurants, groceries, hotels, landlords). Zero driving/riding on web.
   - **Multi-Business Switcher**: Single user (`auth.users`) owns multiple stores/hotels via `partner_profiles.owner_id` (1:N) with an Instagram-style profile switcher.

---

## 2. Database Migrations Inventory (`supabase/migrations/`)

| Migration File | Key Tables, Enums & Functions |
|---|---|
| `20261005000001_extensions_and_enums.sql` | PostGIS, btree_gist, pg_trgm, pgcrypto, all domain enums |
| `20261005000002_geography_spine.sql` | Nepal administrative spine (provinces, districts, municipalities, wards) |
| `20261005000003_identity_partners_admin.sql` | Profiles, partner_profiles, bank_accounts, KYC docs, admin audit logs |
| `20261005000004_catalog_orders.sql` | Stores, catalog_items, inventory, `place_order()`, orders state machine |
| `20261005000005_stays_rooms_rides.sql` | Stays, rooms (anti-double-booking gist), InDrive rides (`place_ride_bid`, `accept_ride_bid`) |
| `20261005000006_payments_ledger_payouts.sql` | Payments, platform_ledger (`assert_ledger_group_balanced`), settlement_batches, `confirm_payment` |
| `20261005000007_social_chat.sql` | E2EE keys, chats, messages, ephemeral burning snaps (`open_and_burn_snap`), 24h stories |
| `20261005000008_loyalty_vouchers_referrals.sql` | Loyalty leagues, daily check-in (Asia/Kathmandu), vouchers, referral chains |
| `20261005000009_ai_memory_and_retention.sql` | Privacy-gated AI memory (`get_ai_context`, `save_user_memory`), 50-item cap, 30-day purge |
| `20261005000010_privileges_and_storage.sql` | Function privilege lockdown (service_role only), Storage bucket RLS policies |
| `20261005000011_seed_nepal_geography.sql` | Deterministic seed data: 7 provinces, 77 districts, 753 local levels |
| `20261005000012_enhancements_reviews_reconciliation.sql` | Reviews table, 0% VAT default, rider COD safety limit, digital COD settlement (`settle_rider_cod_digital`) |
| `20261005000013_automated_invoice_dispatch_and_email_queue.sql` | `email_dispatch_queue`, trigger `trigger_queue_delivered_order_invoice` on order delivery |
| `20261005000014_sms_verification_and_rate_limiting.sql` | `sms_dispatch_logs`, `sms_rate_limits`, anti-bombing rate limiter RPC `check_sms_rate_limit` |
| `20261005000015_device_push_tokens.sql` | `user_device_tokens` (FCM/APNs), RPC `register_device_token`, dead-token pruning |
| `20261005000016_on_demand_instant_payouts.sql` | On-demand instant cash-out, RPC `request_on_demand_payout`, COD lock, instant fee |
| `20261005000017_ai_voice_personas.sql` | 4 Voice Personas (Eli, Rony, Jenny, Sol), `ai_voice_personas` table, voice preferences, RPCs |

---

## 3. Supabase Edge Functions Inventory (`supabase/functions/`)

All 8 functions are **100% implemented, production-ready, and support Dev Mock Mode** (running at zero cost when keys are omitted):

| Function | Primary Purpose | Supported Adapters & Features |
|---|---|---|
| **`send-email/`** | Customer tax invoices, OTPs, KYC notices, daily payout statements | Resend REST API, responsive HTML templates, Dev Mock Mode |
| **`send-sms/`** | Phone OTP verification for Nepal mobile carriers | Sparrow SMS, Aakash SMS, Dev Mock Mode, rate limiter (max 3 / 10m) |
| **`payment-initiate/`** | Creates gateway payment sessions with server-side pricing | eSewa ePay v2 (HMAC-SHA256), Khalti v2 (`pidx`), Fonepay dynamic QR |
| **`payment-verify/`** | Verifies payment completion & updates ledger | eSewa server status API, Khalti `/epayment/lookup/`, calls `confirm_payment` |
| **`payout-execute/`** | Midnight partner settlement & banking disbursement | Audits balances, offsets rider cash, ConnectIPS NCHL CSV export, email statements |
| **`push-notify/`** | High-priority push alerts to devices | Firebase Cloud Messaging (FCM HTTP v1) via OAuth2, APNs, dead token pruning |
| **`process-outbox/`** | Resilient transactional outbox worker | Polls `email_dispatch_queue`, retries failures with exponential backoff |
| **`ai-gateway/`** | Server-side AI Concierge, 4 Voice Personas & WebRTC Room Broker | OpenRouter/Gemini, user memory (`get_ai_context`), 4 Personas (Eli, Rony, Jenny, Sol), `create_voice_room` (LiveKit WebRTC), Photo-to-Menu OCR, Kitchen Voice |

---

## 4. Chronological Session History

### Session 1: Platform Foundation & Core Verticals
- Analyzed and merged food, grocery, ride-hailing (InDrive bidding), stays, and long-term rental business models.
- Established the double-entry general ledger architecture with deferred balancing triggers.
- Formulated the Zero-Hub COD digital settlement math and Pre-VAT 0% policy.
- Implemented Migrations `0001` through `0012`.

### Session 2: Resend Email Subsystem
- Designed and tested responsive HTML tax invoice and OTP verification templates.
- Pinned `resend@^6.1.1` and wrote 4 Vitest unit tests verifying currency formatting, HTML output, and mock modes.
- Committed under git commit `6a7588b`.

### Session 3: Universal Backend & Real-Time AI Voice Streaming Stack
- **Universal Email Edge Function & Invoicing Trigger**:
  - Implemented `supabase/functions/send-email/` and Migration `0013` (`email_dispatch_queue`).
  - Created client bridges in Kotlin, Swift, and Next.js Web. Committed `906fd59`.
- **Nepal SMS & Dual Auth Infrastructure**:
  - Implemented Migration `0014` (`sms_dispatch_logs`, `sms_rate_limits`, anti-bombing rate limiter RPC).
  - Built `supabase/functions/send-sms/` supporting Sparrow SMS, Aakash SMS, and Dev Mock Mode.
  - Added whitelisted test numbers in `supabase/config.toml`. Committed `6836f21`.
- **Nepal Direct Payment Rails**:
  - Implemented `supabase/functions/payment-initiate/` and `payment-verify/` for eSewa v2 HMAC, Khalti v2 pidx, and Fonepay dynamic QR.
  - Created client payment bridges for Android, iOS, and Web. Committed `8b5aa37`.
- **Midnight Settlement & ConnectIPS Disbursement**:
  - Implemented `supabase/functions/payout-execute/` supporting automated audit, COD offset, ConnectIPS CSV export, and email receipts. Committed `c93142e`.
- **Push Notification Service**:
  - Implemented Migration `0015` (`user_device_tokens`) and `supabase/functions/push-notify/` supporting FCM v1, APNs, and dead token auto-cleaning. Committed `e575442`.
- **24/7 On-Demand Instant Payouts**:
  - Implemented Migration `0016` and instant payout execution with Zero-Hub COD lock and NPR 15 flat fee. Committed `5052fe8`.
- **4 Persona AI Voice Agents & Low-Latency WebRTC Pipeline**:
  - Implemented Migration `0017` (`20261005000017_ai_voice_personas.sql`) defining the 4 Voice Personas (**Eli**, **Rony**, **Jenny**, **Sol**), public personas catalog, and user preference RPCs.
  - Built the Python AI Voice Gateway microservice in `services/ai-voice-gateway/` with:
    - Faster-Whisper in-memory PCM ASR + AI4Bharat IndicConformer.
    - AI4Bharat IndicXlit Romanized-to-Devanagari real-time phonetic transliteration.
    - Piper-TTS & AI4Bharat Indic-Parler-TTS with dynamic persona pitch and speed modulation.
    - Dialog orchestrator with tool schemas (`search_catalog`, `add_to_cart`, `calculate_ride_fare`).
    - Real-time `VoicePipeline` featuring VAD, turn completion detection, and barge-in / interruption handling.
    - LiveKit WebRTC Worker Agent (`LiveKitVoiceAgent`) & direct binary WebSocket (`/ws/voice-agent`).
  - Added LiveKit WebRTC server to `docker-compose.yml`.
  - Upgraded `supabase/functions/ai-gateway/index.ts` to broker WebRTC room tokens (`create_voice_room`) and inject persona prompts.
  - Updated multiplatform client services (`EvrryAiService.kt`, `EvrryAiService.swift`, `apps/web/common/ai.ts`).
  - Created unit tests in `prototype/Phone/lib/ai/personas.test.ts`.
- **Full Verification**:
  - Ran complete test suite: 14/14 test files passed, 86/86 unit and integration tests passed (100% success).

---

## 5. Next Immediate Phase: Frontend Implementation

The backend is 100% complete and self-contained. The roadmap now transitions to the UI screens:
1. **Superadmin Operations Console (`apps/web/admin`)**:
   - Split-screen Partner KYC Document Review Queue.
   - Midnight Settlement Batch Approval & ConnectIPS Export Console.
   - User & Rider Moderation (Bans, Cash Reconciliation).
2. **Partner Web Portal (`apps/web/partner`)**:
   - Restaurant Kitchen Display System (KDS) & Order Management.
   - Menu Management & Photo-to-Menu Vision OCR.
   - Hotel Room Availability Calendar & Rate Editor.
3. **Native Consumer & Partner Mobile Apps (`apps/consumer/`, `apps/partner/`)**:
   - Android: Jetpack Compose with Material 3.
   - iOS: SwiftUI with Clean Architecture.
