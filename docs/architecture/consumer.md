# Consumer Architecture

The Consumer application provides the customer-facing experience for **evryy**, developed by **Elifsi Technologies Private Limited**, across Android, iOS, and Web.

---

## 1. Platform Clients

| Client | Directory | Technology | Build / Package |
|---|---|---|---|
| **Android** | `apps/consumer/android/` | Kotlin, Jetpack Compose, Coroutines, Flow | Gradle (`build.gradle.kts`) |
| **iOS** | `apps/consumer/ios/` | Swift, SwiftUI, Combine, Swift Concurrency | Xcode, SPM |
| **Web** | `apps/web/consumer/` | Next.js (App Router), React, TypeScript, Tailwind | npm (`package.json`) |

---

## 2. Core Functional Subsystems

### A. Discovery & Search
- Multi-category catalog indexing: Food, Grocery, Retail, Hotels, Mobility/Rides, Professional Services.
- Full-text and semantic search queries executed through Supabase PostgREST with PostgreSQL `tsvector` or `pgvector`.
- Geolocation-based filtering to surface nearby restaurants, stores, and active service providers.

### B. AI Concierge
- Voice-first natural interaction:
  - Mobile: Native speech-to-text engines (Android SpeechRecognizer, iOS SFSpeechRecognizer).
  - Web: Browser Web Speech API with fallback to typed input.
- Concierge reasoning: Calls `supabase/functions/ai-concierge-chat/` which executes a tool-calling loop across catalog search, price calculation, and order draft creation.
- Grounding: All action confirmations (e.g. adding to cart, scheduling bookings) must be explicitly presented to and authorized by the user.

### C. Cart & Checkout Flow
1. **Draft Order**: User builds cart with items and customization options.
2. **Server Price Calculation**: Cart payload is sent to server to compute actual subtotal, delivery fee, platform fee, taxes, and applied coupons. Client never decides the total.
3. **Payment Initiation**: Server generates a payment session using the selected payment provider (eSewa, Khalti, Fonepay, Card).
4. **Authorization & Confirmation**: On successful payment callback verification, the order transitions from `draft` to `acknowledged`.

### D. Order Tracking & Realtime Updates
- Order status state transitions (`acknowledged` → `preparing` → `ready_for_pickup` → `dispatched` → `delivered`).
- Subscriptions to Supabase Realtime channels scoped to the consumer's `order_id`.
- Driver location streaming for active delivery/ride trips.

### E. Profile, Addresses & Preferences
- Supabase Auth session handling (email/password, phone OTP, OAuth).
- Address book with geocoded coordinates, delivery instructions, and default selection.
- Notification preferences and saved payment method references (tokenized, never raw credentials).

---

## 3. Client Security Boundaries

- Consumer clients only possess the Supabase `anon` key.
- Row Level Security ensures consumers cannot query other consumers' profiles, carts, orders, or private conversations.
- No direct database write access to order status or payment records; state transitions are handled through validated database functions or Edge Functions.
