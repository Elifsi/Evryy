# apps/consumer/ — Consumer Applications

The **Consumer Application** provides the customer-facing **evrry** Super App experience, developed by **Elifsi Technologies Private Limited**.

## Target Platforms

- **Android**: [`apps/consumer/android/`](./android/) (Kotlin + Jetpack Compose)
- **iOS**: [`apps/consumer/ios/`](./ios/) (Swift + SwiftUI)
- **Web**: [`apps/web/consumer/`](../web/consumer/) (Next.js + TypeScript)

## Core Capabilities

The consumer clients enable end-users to:
- **Discover Services & Products**: Multi-vertical catalog covering food, grocery, electronics, fashion, hotels, rides, and on-demand services.
- **AI Concierge**: Conversational assistant with voice-first interaction and tool execution for searching, comparing, and scheduling.
- **Cart & Order Management**: Multi-vendor shopping carts, item customization, draft orders, and status tracking.
- **Payments**: Multi-provider payments (eSewa, Khalti, Fonepay, Card) via a secure server-side payment abstraction.
- **Live Order Tracking**: Real-time order progress and simulated/live driver routing for delivery and mobility.
- **Identity & Profiles**: Secure user authentication via Supabase Auth, delivery addresses, communication preferences, and audit logs.
- **Real-Time Communication**: End-to-end encrypted direct messaging and peer-to-peer WebRTC voice/video calling.

## Architecture

Consumer apps connect to the shared backend at [`supabase/`](../../supabase/). All client operations are scoped by user identity through Row Level Security (RLS).
