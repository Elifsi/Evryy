# apps/web/consumer — Production Consumer Web App

## Status

🔮 **Planned — Implementation not yet initialized.**

## Technology Stack

- **Framework**: Next.js (App Router)
- **Language**: TypeScript
- **UI & Styling**: React, Tailwind CSS, Lucide Icons, Radix UI
- **Backend SDK**: `@supabase/ssr` / `@supabase/supabase-js`
- **State Management**: Zustand / React Query
- **Payments**: Hosted gateway integration (eSewa, Khalti, Fonepay, Card tokenization)

## Core Responsibilities

- Fully responsive web version of the **evrry** consumer experience (by **Elifsi Technologies Private Limited**).
- Web-based AI concierge chat interface with browser voice integration (Web Speech API).
- Search, browse, and multi-vertical checkout across food, grocery, hotels, electronics, and services.
- User account management, address book, saved cards, order tracking, and notification center.
- Direct messages and browser-based WebRTC calling.

## Reference

Use [`prototype/Phone/`](../../../prototype/Phone/) as the visual, interaction, and component reference when building this application.

> **Security Reminder**: Never expose `SUPABASE_SERVICE_ROLE_KEY` in client bundles. Use only `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
