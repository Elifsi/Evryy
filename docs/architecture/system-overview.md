# System Architecture Overview

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  

**evryy** is an AI-first super-app platform connecting consumers and service partners across dining, grocery quick-commerce, ride-sharing, hotels and stays, room rentals, vehicle rentals, encrypted P2P chat, and social camera experiences.

---

## 1. Top-Level Platform Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             CLIENT APPLICATIONS                             │
│                                                                             │
│   ┌───────────────────────────────────┐   ┌─────────────────────────────┐   │
│   │           CONSUMER APPS           │   │        PARTNER APPS         │   │
│   │  • Android (Kotlin + Compose)     │   │  • Android (KDS, POS, Rider)│   │
│   │  • iOS (Swift + SwiftUI)          │   │  • iOS (iPad Ops Counter)   │   │
│   │  • Web (Next.js App Router)       │   │  • Web Merchant Portal      │   │
│   └─────────────────┬─────────────────┘   └──────────────┬──────────────┘   │
└─────────────────────┼────────────────────────────────────┼──────────────────┘
                      │                                    │
                      │    HTTPS / WSS (Supabase SDKs)     │
                      ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CENTRALIZED SUPABASE BACKEND (PostgreSQL)                │
│                                                                             │
│   • Supabase Auth (Consumer & Partner RBAC, JWT claims)                     │
│   • PostgreSQL Database with PostGIS & strict Row Level Security (RLS)      │
│   • Supabase Realtime (WebSockets for order events & chat)                  │
│   • Supabase Storage (Catalog media, vehicle photos, snap storage)          │
│   • Supabase Edge Functions (eSewa / Khalti verification, payouts)          │
└──────────────┬──────────────────────────────────────────────┬───────────────┘
               │                                              │
               ▼                                              ▼
┌─────────────────────────────────────────┐  ┌────────────────────────────────┐
│      LOCAL MICROSERVICES & ROUTING      │  │     FINTECH & NOTIFICATIONS    │
│                                         │  │                                │
│  • AI Voice Gateway (FastAPI, 16kHz)    │  │  • Khalti Epay v2 & Webhook    │
│    ├── Faster-Whisper & IndicConformer  │  │  • eSewa HMAC-SHA256 Token     │
│    ├── AI4Bharat IndicXlit & Parler-TTS │  │  • connectIPS / Khalti Payouts │
│    └── Local vLLM Qwen 2.5 Inference    │  │  • Push Worker (FCM & APNs)    │
│  • Redis (GEOADD Driver GPS, Sockets)   │  │  • Evryy In-App Wallet Engine  │
│  • OSRM Backend (Zero Google Fees)      │  │                                │
└─────────────────────────────────────────┘  └────────────────────────────────┘
```

---

## 2. Master End-to-End System Workflow

```
========================================================================================================
                                     THE EVRYY PLATFORM WORKFLOW
========================================================================================================

 [MOBILE CLIENTS: KOTLIN / SWIFT]
   │
   ├── (A) VOICE ORDERING FLOW
   │     1. Mic records audio -> Streams 16kHz PCM bytes over WebSocket -> /ws/voice-agent
   │     2. [ai-voice-gateway]:
   │        ├── Transcribes audio via Faster-Whisper or AI4Bharat IndicConformer
   │        ├── Transliterates Romanized speech (e.g., "momo" -> मोमो) via IndicXlit
   │        ├── Passes text to local Qwen 2.5 (vLLM / Ollama)
   │        ├── Qwen calls tool: search_menu_items(query="momo", sort="rating_asc")
   │        ├── Python executes read-only query on Supabase (ai_agent_reader role)
   │        ├── Qwen calls tool: add_to_cart(dish_id, qty)
   │        ├── Emits UI_ACTION JSON event -> Client updates cart bar dynamically
   │        └── Synthesizes reply audio via Piper / Indic-Parler-TTS -> Plays on phone speaker
   │
   ├── (B) CHECKOUT & PAYMENT FLOW
   │     1. User taps "Pay via Khalti / eSewa"
   │     2. Backend initiates transaction -> Returns payment sheet URL & pidx
   │     3. User authorizes transaction -> Gateway fires webhook back to /payments/callback
   │     4. Backend writes new row to `orders` table (Read-Write role)
   │     5. Push Worker fires FCM alert to Restaurant: "New Order #1042 Received!"
   │
   ├── (C) REAL-TIME RIDER TRACKING & MAPS
   │     1. Rider accepts order -> Background GPS sends lat/lng to Redis every 3 seconds
   │     2. Customer Map View:
   │        ├── Free Google Maps Mobile SDK displays street background
   │        ├── Polyline & ETA calculated on server via OSRM Docker container (Zero Google Fees)
   │        └── Animated bike marker glides smoothly along coordinates streamed from Redis
   │
   └── (D) FAMILY SAFETY & LOCATION SHARING
         1. Customer hits "Share Ride with Family"
         2. IN-APP: Pushes live ride session into encrypted family chat thread (updates in real time)
         3. EXTERNAL: Generates signed web token: https://evryy.app/track/{token}
            └── Opens in WhatsApp / SMS / Safari without requiring family members to install the app
========================================================================================================
```

---

## 3. Core Architectural Pillars

### A. Consumer vs. Partner Separation
- **Consumer Applications**: Optimized for discovery, voice AI interaction, multi-vendor cart building, checkout, real-time ride tracking, and camera/snap creation.
- **Partner Applications**: Tailored for business operations: inventory management, incoming order queues, kitchen display systems (KDS), dispatching, double-entry ledger tracking, and role-based staff permissions.

### B. Centralized Shared Backend
- A single, centralized Supabase infrastructure powers all clients.
- Data separation and multi-tenant security are guaranteed at the database layer via **PostgreSQL Row Level Security (RLS)**.
- Client applications access the database directly via Supabase SDKs using public `anon` credentials, scoped strictly by JWT authentication tokens.

### C. Zero-Fee Open Routing (OSRM)
- Instead of paying high per-request fees to Google Maps Directions API, road polylines, navigation paths, and ETAs are calculated on self-hosted OSRM containers running the `nepal-latest.osm.pbf` dataset.

### D. Reference Prototype Delineation
- [`prototype/Phone/`](../../prototype/Phone/) is the working Next.js interactive prototype and visual/functional reference (75 tests passing).
- [`apps/`](../../apps/) contains the planned production native and web clients.

---

## 4. Key Reference Documents
- [Super App Specification & Reference Matrix](./superapp-specification.md)
- [Master Dependencies Specification](./dependencies-master.md)
- [Consumer Architecture](./consumer.md)
- [Partner Architecture](./partner.md)
- [Payment Architecture](./payments.md)
- [Partner Payout & Financial Architecture](./payouts.md)
