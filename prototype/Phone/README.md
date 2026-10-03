# evrry — Web Prototype & Reference Implementation

> **Important**: This directory contains the original **evrry mobile prototype**, developed by **Elifsi Technologies Private Limited**.
> It is an end-to-end interactive demo that serves as the **visual, UX, interaction, and functional reference** for the future production consumer applications (Android, iOS, Web) and partner applications.
>
> **Do NOT delete, rewrite, or replace this prototype with a stub.**
> It is intentionally decoupled from production backend infrastructure to allow rapid visual and workflow experimentation.

---

## Role in the Repository

| Directory | Purpose | Status |
|---|---|---|
| `prototype/Phone/` | Visual, functional, and UX reference for the entire platform | ✅ **Current & Working** |
| `apps/consumer/` | Native Android and iOS consumer applications | 🔮 Planned |
| `apps/partner/` | Native Android and iOS partner/merchant applications | 🔮 Planned |
| `apps/web/` | Production consumer and partner web portals | 🔮 Planned |
| `supabase/` | Centralized production backend (DB, Auth, RLS, Edge Functions) | 🔮 Planned |

---

## Features Implemented in This Prototype

1. **Voice-First AI Concierge**:
   - Real-time voice interaction using browser Web Speech API (`webkitSpeechRecognition`) + `speechSynthesis`.
   - Tool-calling agent loop (`search_catalog`, `get_item`, `present_recommendations`).
   - Grounding validation (never trusts unverified model claims).
   - Multi-provider fallback: Google Gemini → Anthropic Claude → OpenRouter → built-in zero-config rule-based fallback.

2. **Unified Mock Service Catalog**:
   - Shared catalog across Electronics, Food, Grocery, Fashion, Hotels, Rides, and Services.
   - Dual interface: voice/chat conversational search and manual **Explore** marketplace.

3. **End-to-End Encrypted Direct Messaging & WebRTC Calling**:
   - Browser-to-browser E2EE chat using Web Cryptography API (ECDH P-256 key agreement + AES-GCM-256).
   - In-memory WebSocket relay server (`server/chat-relay.mjs`) for ciphertext routing.
   - TOFU (Trust On First Use) ECDSA identity signature challenge on socket connect.
   - Peer-to-peer 1:1 WebRTC voice and video calls (`lib/chat/webrtc.ts`) with custom CallOverlay UI.

4. **Ride Booking & Simulation**:
   - Fare estimation, pickup/destination selection, vehicle tier picking.
   - Deterministic simulated driver assignment, route progression, and live animated abstract map.

5. **Food & Grocery Ordering**:
   - Restaurant menus, item customizations, transparent delivery/platform fee calculations.
   - Order draft → explicit authorization → state lifecycle tracking (`pending vendor` → `in progress` → `completed`).

6. **Snap, Camera & Custom Filters**:
   - Live camera capture with real-time CSS color grading filters.
   - In-app filter creator tool with custom filter preset saving to local storage.

7. **Wallet & Financial Simulation**:
   - Stored payment methods, mock authorization, balance tracking, and immutable audit logging.

---

## Running the Prototype Locally

```bash
cd prototype/Phone
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Running with Real AI Models

Copy `.env.example` to `.env.local` inside `prototype/Phone/`:

```bash
cd prototype/Phone
cp .env.example .env.local
```

Set at least one API key:
- `GEMINI_API_KEY`: Get from [Google AI Studio](https://aistudio.google.com/apikey)
- `ANTHROPIC_API_KEY`: Get from [Anthropic Console](https://console.anthropic.com/)
- `OPENROUTER_API_KEY`: Get from [OpenRouter](https://openrouter.ai/)

### Running with E2E Chat & WebRTC Calling

To test encrypted messaging and calls between two browser sessions:

```bash
cd prototype/Phone
npm run dev:all
```

This starts both the Next.js frontend (port 3000) and the WebSocket relay (port 8787). Open two browser tabs or private windows to test chat pairing.

---

## Testing

```bash
cd prototype/Phone
npm run lint         # ESLint check
npx tsc --noEmit     # TypeScript typecheck
npm run test         # Vitest unit + integration tests (75 tests)
npm run test:e2e     # Playwright browser end-to-end tests
npm run build        # Production Next.js build
```

---

## Known Intentional Prototype Limitations

- State is persisted locally via `localStorage` (Zustand); there is no shared database.
- Identity is generated per browser context; there is no centralized auth server.
- Payment flows are client simulations; no live payment gateways or bank integrations exist here.
- These production capabilities will be built into `apps/` and backed by `supabase/`.
