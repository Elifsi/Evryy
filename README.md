# evryy — Super App Platform Monorepo

> **An open-source, AI-first super-app platform developed by [Elifsi Technologies Private Limited](https://github.com/Elifsi).**  
> Unifying Food Delivery, Quick-Commerce Grocery, Rides, Hotels & Stays, Room Rentals, Vehicle Rentals, WhatsApp-style Encrypted Chat, and Camera/Snap experiences into a single ecosystem.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Status: Active Development](https://img.shields.io/badge/Status-Active%20Development-green.svg)](./docs/roadmap/README.md)
[![Organization](https://img.shields.io/badge/Organization-Elifsi%20Technologies-purple.svg)](https://github.com/Elifsi)
[![Repository](https://img.shields.io/badge/GitHub-Elifsi%2FEvryy-blue.svg)](https://github.com/Elifsi/Evryy)

---

> ### 📍 Quick Navigation: Where is Everything?
>
> | What you are looking for | Directory / Document | Status | Description |
> |---|---|---|---|
> | **Super App Specification** | [`docs/architecture/superapp-specification.md`](./docs/architecture/superapp-specification.md) | 📐 **Architecture Blueprint** | Full multi-vertical specification, tech stack protocols, and official repository reference matrix. |
> | **Working Reference Prototype** | [`prototype/Phone/`](./prototype/Phone/) | ✅ **Current & Runnable** | Complete working Next.js 16 prototype with catalog, voice AI concierge, encrypted chat, WebRTC, and ride/order simulations. |
> | **Consumer Mobile Apps** | [`apps/consumer/`](./apps/consumer/) | 🔮 Planned | Production native apps: [Android (Kotlin/Compose)](./apps/consumer/android/) and [iOS (Swift/SwiftUI)](./apps/consumer/ios/). |
> | **Partner / Merchant Apps** | [`apps/partner/`](./apps/partner/) | 🔮 Planned | Production business apps: [Android (KDS/POS)](./apps/partner/android/) and [iOS (Merchant)](./apps/partner/ios/). |
> | **Production Web Portals** | [`apps/web/`](./apps/web/) | 🔮 Planned | Production web clients: [Consumer Web](./apps/web/consumer/) and [Partner Dashboard](./apps/web/partner/). |
> | **Centralized Shared Backend** | [`supabase/`](./supabase/) | 🔮 Planned (Configured) | Shared Supabase backend: [Migrations](./supabase/migrations/), [Edge Functions](./supabase/functions/), seed data, and RLS. |
> | **Architecture & Tech Specs** | [`docs/architecture/`](./docs/architecture/) | 📚 Complete | Detailed system, consumer, partner, payment, and payout architecture documents. |

---

## Architecture at a Glance

The platform unifies multiple native and web clients around a single, centralized backend:

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT APPLICATIONS                      │
│                                                             │
│   CONSUMER SURFACES                 PARTNER SURFACES        │
│   • Android (Kotlin + Compose)      • Android (KDS/POS)     │
│   • iOS (Swift + SwiftUI)           • iOS (Counter/Ops)     │
│   • Web (Next.js + React)           • Web Merchant Portal   │
│           │                                 │               │
└───────────┼─────────────────────────────────┼───────────────┘
            │                                 │
            └────────────────┬────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────┐
│             CENTRALIZED SUPABASE BACKEND (supabase/)        │
│                                                             │
│   • Supabase Auth (User & Partner Role-Based Access)        │
│   • PostgreSQL with strict Row Level Security (RLS)         │
│   • Supabase Realtime (Order Tracking & Messaging)          │
│   • Supabase Edge Functions (Deno / TypeScript):            │
│       ├── Payment Service (eSewa, Khalti, Fonepay, Card)    │
│       ├── Partner Settlement & Payout Engine                │
│       └── Conversational AI Concierge Tool Loop             │
└─────────────────────────────────────────────────────────────┘
```

---

## Complete Repository Directory Tree

```
Evryy/
│
├── prototype/
│   └── Phone/                 ← 🟢 START HERE: Working Next.js reference prototype
│       ├── app/               # 41 App Router routes (Home, Explore, Chat, Snap, Rides)
│       ├── components/        # Reusable UI & feature components
│       ├── lib/               # Zustand stores, mock catalog, AI logic, E2EE crypto
│       ├── server/            # WebSocket relay for E2EE chat & WebRTC signaling
│       ├── e2e/               # Playwright browser end-to-end tests
│       └── README.md          # Prototype documentation & feature catalog
│
├── apps/                      ← 🔮 PRODUCTION CLIENT APPLICATIONS (Planned)
│   │
│   ├── consumer/              # Customer-facing applications
│   │   ├── android/           # Native Android app (Kotlin + Jetpack Compose)
│   │   ├── ios/               # Native iOS app (Swift + SwiftUI)
│   │   └── README.md          # Consumer architecture & requirements
│   │
│   ├── partner/               # Business & merchant applications
│   │   ├── android/           # Native Android app (KDS, POS, Rider mode)
│   │   ├── ios/               # Native iOS app (iPad merchant counter)
│   │   └── README.md          # Partner capabilities & workflows
│   │
│   └── web/                   # Production web portals
│       ├── consumer/          # Customer web portal (Next.js + React)
│       ├── partner/           # Merchant web management dashboard (Next.js)
│       └── README.md          # Web surfaces overview
│
├── supabase/                  ← 🔮 SHARED BACKEND INFRASTRUCTURE
│   ├── config.toml            # Local Supabase CLI configuration
│   ├── seed.sql               # Local development seed data
│   ├── migrations/            # Version-controlled SQL schema & RLS policies
│   └── functions/             # Server-side Edge Functions (payments, payouts, AI)
│
├── docs/                      ← 📚 PLATFORM DOCUMENTATION
│   ├── architecture/          # System, Consumer, Partner, Payments, Payouts
│   ├── product/               # Product requirements & user journeys
│   ├── development/           # Setup guides & coding standards
│   ├── roadmap/               # Phased platform milestones
│   └── README.md              # Documentation index
│
├── .github/                   ← ⚙️ CI/CD & GITHUB GOVERNANCE
│   ├── workflows/ci.yml       # Automated CI workflow (lint, typecheck, test, build)
│   ├── ISSUE_TEMPLATE/        # Standardized bug & feature templates
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS             # Default review assignment to @Elifsi
│
├── scripts/                   # Repository maintenance & tooling scripts
├── .env.example               # Central environment variable reference
├── .gitignore                 # Monorepo build artifact rules
├── AGENTS.md                  # Development rules for AI coding assistants
├── ARCHITECTURE.md            # Master architecture & security document
├── CONTRIBUTING.md            # Contributor guidelines & testing checklists
├── SECURITY.md                # Vulnerability reporting & credential boundaries
├── CODE_OF_CONDUCT.md         # Contributor Covenant v2.1
└── LICENSE                    # MIT License © 2026 Elifsi Technologies Private Limited
```

---

## How to Run the Working Prototype Today

The reference prototype at `prototype/Phone/` is completely functional:

```bash
# 1. Navigate to the prototype directory
cd prototype/Phone

# 2. Install dependencies
npm install

# 3. Start the Next.js development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Key Interactive Features to Explore
* **Voice-First AI Concierge**: Tap the animated orb on the home screen to speak, search items, and book services.
* **Encrypted Chat & WebRTC Calling**: Run `npm run dev:all` (Next.js + WebSocket relay) and open two browser windows at `http://localhost:3000/chat`.
* **Explore Marketplace**: Browse Dining, Grocery, Retail, Hotels, Mobility, and Services.
* **Ride Booking Simulation**: Test fare estimation and simulated live driver tracking.
* **Snap & Camera**: Test live camera capture with customizable CSS color filters.

### Running Quality Checks on the Prototype
```bash
cd prototype/Phone
npm run lint         # ESLint check (0 errors)
npx tsc --noEmit     # TypeScript typecheck (0 errors)
npm run test         # Vitest unit & integration tests (75/75 passing)
npm run build        # Production Next.js Turbopack build (41 routes compiled)
```

---

## Where Should New Code Go? (Guide for Developers)

| If you are working on... | Put your code in... | Guidelines |
|---|---|---|
| **Adding a UI idea or exploring UX** | `prototype/Phone/` | Fast-paced browser prototype. Local state, no production DB required. |
| **Building the Consumer Android App** | `apps/consumer/android/` | Kotlin + Jetpack Compose. Clean Architecture. Connect to Supabase. |
| **Building the Consumer iOS App** | `apps/consumer/ios/` | Swift + SwiftUI. Connect to Supabase. |
| **Building the Consumer Web Portal** | `apps/web/consumer/` | Production Next.js. Connect to Supabase Auth & PostgreSQL. |
| **Building the Partner Android App** | `apps/partner/android/` | Kotlin + Compose. Order receipt printing, KDS, rider dispatch. |
| **Building the Partner Web Portal** | `apps/web/partner/` | Next.js desktop dashboard for inventory, analytics, and staff. |
| **Database Schemas & RLS** | `supabase/migrations/` | Timestamped forward-only SQL migrations. RLS required on every table. |
| **Payments, Payouts & Privileged Backend** | `supabase/functions/` | Deno/TypeScript Edge Functions. Private keys stay server-side. |

> ⚠️ **Policy**: Do NOT commit empty placeholder PRs or fake frameworks merely to populate folders. New applications should follow the [Platform Roadmap](./docs/roadmap/README.md).

---

## Financial & Security Architecture

1. **Streamlined Payment Ingestion** ([`docs/architecture/payments.md`](./docs/architecture/payments.md)):
   - **Zero Stored-Value Wallet**: In-app customer wallets are removed to eliminate NRB PSP licensing and escrow liabilities.
   - **Fonepay Dynamic QR**: Real-time EMVCo QR with locked payable amount and system remarks; blurs on scan, auto-processes on server webhook (IMS Supermarket billing model); supports screenshot sharing to bank apps via gallery scan.
   - **Hosted Redirection & Deep Linking**: Direct wallet checkout via **eSewa**, **Khalti**, and **Fonepay Direct** (login/OTP handled exclusively on gateway servers before returning via `evryy://checkout/callback`).
   - **Cards via Khalti & eSewa**: 3D-Secure Visa, Mastercard, and SCT card checkouts hosted directly by certified gateway sheets (zero raw card storage).
   - **Cash on Delivery (COD)**: Physical cash collection on delivery verified with a 4-digit recipient OTP handshake.

2. **Partner Payout & Cash Reconciliation Subsystem** ([`docs/architecture/payouts.md`](./docs/architecture/payouts.md)):
   - Inward payments and outward partner payouts are decoupled.
   - Server-side settlement engine with double-entry immutable ledger accounting.
   - Midnight automated batch disbursements via **connectIPS (NCHL API)** and Khalti Payout API.
   - Full rider cash reconciliation offsetting collected COD cash against earned delivery fees.

3. **Multi-Tenant Authorization & Row Level Security**:
   - Consumers can only access their own profile, cart, orders, and chats.
   - Partners can never access another partner's orders, catalog, or financial data.
   - Zero `service_role` keys permitted in client bundles.

---

## Documentation Index

Explore the complete platform documentation:
- 📐 [Super App Specification & Reference Matrix](./docs/architecture/superapp-specification.md)
- 🏛️ [System Architecture Overview](./docs/architecture/system-overview.md)
- 👤 [Consumer Architecture](./docs/architecture/consumer.md)
- 🏪 [Partner Architecture](./docs/architecture/partner.md)
- 💳 [Payment Architecture](./docs/architecture/payments.md)
- 💰 [Partner Payout Architecture](./docs/architecture/payouts.md)
- 🎯 [Consumer Product Requirements](./docs/product/consumer/README.md)
- 📋 [Partner Product Requirements](./docs/product/partner/README.md)
- 🛠️ [Developer Setup Guide](./docs/development/README.md)
- 🗺️ [Platform Roadmap](./docs/roadmap/README.md)

---

## Contributing & Community

Contributions are warmly welcomed! Please read:
* [`CONTRIBUTING.md`](./CONTRIBUTING.md) — Setup guide, testing checklist, and PR conventions.
* [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md) — Community standards (Contributor Covenant v2.1).
* [`SECURITY.md`](./SECURITY.md) — Security policy and vulnerability disclosure instructions.

---

## License

This project is licensed under the **MIT License** — see the [`LICENSE`](./LICENSE) file for details.

Copyright (c) 2026 **Elifsi Technologies Private Limited**
