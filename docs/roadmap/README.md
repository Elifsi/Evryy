# Platform Roadmap

This document outlines the phased development roadmap for **evrry**, developed by **Elifsi Technologies Private Limited**.

---

## Phase 0: Prototype & UX Validation (Current)
- [x] End-to-end interactive Next.js web prototype (`prototype/Phone/`)
- [x] Multi-category mock catalog (food, grocery, retail, hotels, rides, services)
- [x] Voice-first AI concierge loop with tool use & model fallback
- [x] End-to-end encrypted direct messaging and WebRTC voice/video calling
- [x] Simulated ride booking and driver auto-advance tracking
- [x] Camera filters (Snap) and custom filter creator
- [x] Monorepo restructuring with complete architectural separation

---

## Phase 1: Shared Backend & Database Foundations (Upcoming)
- [ ] Initialize Supabase project and local development environment
- [ ] Implement core SQL migrations with Row Level Security:
  - User profiles & auth integration
  - Partner profiles & staff RBAC associations
  - Unified catalog and modifier schemas
  - Order state machines & immutable financial ledger
- [ ] Seed data for restaurants, grocery, retail, and test users
- [ ] Payment gateway Edge Functions (`payment-initiate`, `payment-verify`)
  - Integration with eSewa, Khalti, Fonepay, and Card gateways

---

## Phase 2: Native Consumer Mobile Apps
- [ ] Scaffold `apps/consumer/android/` (Kotlin + Jetpack Compose)
- [ ] Scaffold `apps/consumer/ios/` (Swift + SwiftUI)
- [ ] Connect mobile apps to Supabase Auth & Realtime
- [ ] Implement AI Concierge voice loop with native speech engines
- [ ] Implement native cart, order checkout, and live order tracking

---

## Phase 3: Partner Applications & Operations
- [ ] Scaffold `apps/partner/android/` (Kitchen Display & Rider dispatch)
- [ ] Scaffold `apps/web/partner/` (Merchant Web Management Portal)
- [ ] Real-time incoming order sound alerts & acceptance workflow
- [ ] Catalog, pricing, and stock availability management
- [ ] Partner earnings ledger, settlement engine, and automated payouts (`payout-execute`)

---

## Phase 4: Production Consumer Web & Scale
- [ ] Implement `apps/web/consumer/` (Production consumer Next.js application)
- [ ] Cross-client notification infrastructure (FCM / APNs)
- [ ] Advanced analytics and partner reporting
