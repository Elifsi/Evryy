# Reference Repositories

Third-party open-source repositories kept **for reference only** (studying architectural patterns, state machines, and UX conventions; **not vendored directly into evrry**). 

Clones in this directory are gitignored (`reference/*/`). Run `./sync.sh [category]` to fetch or update specific domain references locally without bloating the main git repository.

---

## 1. AI Voice Agent & Multimodal Pipeline
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Server Engine** | [`livekit/agents`](https://github.com/livekit/agents) | Python / Node.js | Sub-200ms WebRTC agent pipeline with native function calling (`@function_tool`) that queries Supabase and pushes real-time screen events. |
| **Multimodal Pipeline** | [`pipecat-ai/pipecat`](https://github.com/pipecat-ai/pipecat) | Python | Production pipeline framework supporting Gemini Live and OpenAI Realtime with client starter kits. |
| **Android Client** | [`livekit/client-sdk-android`](https://github.com/livekit/client-sdk-android) | Kotlin, WebRTC | Android client SDK providing bi-directional audio streaming and real-time data channel packet consumption. |
| **iOS Client** | [`livekit/client-sdk-swift`](https://github.com/livekit/client-sdk-swift) | Swift, SwiftUI | Swift package for WebRTC audio capture, speaker playback, and UI synchronization channels. |
| **Web & Next.js** | [`livekit/components-js`](https://github.com/livekit/components-js) | Next.js, React | Pre-built React hooks (`useVoiceAssistant`, `useDataChannel`) for browser voice integration. |

---

## 2. Chat & E2E Messaging (WhatsApp Architecture)
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Web Chat** | [`Gmarvis/whatsapp-clone`](https://github.com/Gmarvis/whatsapp-clone) | Next.js, Supabase, Tailwind CSS | Direct Supabase Realtime chat implementation: message threads, real-time sync, and conversational state. |
| **Android Native** | [`GetStream/whatsApp-clone-compose`](https://github.com/GetStream/whatsApp-clone-compose) | Kotlin, Jetpack Compose | Production WhatsApp UI: chat bubbles, read ticks (sent, delivered, read), voice notes, and attachment sheets. |
| **iOS Native** | [`efxlve/whatsapp-clone`](https://github.com/efxlve/whatsapp-clone) | Swift, SwiftUI | Native iOS messaging UI: swipe-to-reply, grouping, attachment handling, and contact lists. |

---

## 3. Food Delivery & Multi-Vendor Operations
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Android Native** | [`kaaneneskpc/Deliverr`](https://github.com/kaaneneskpc/Deliverr) | Kotlin, Jetpack Compose | Reference for multi-variant single-codebase architectures (`customer`, `restaurant`, `rider` build flavors) in pure Jetpack Compose. |
| **Multi-Vendor Ops** | [`enatega/food-delivery-multivendor`](https://github.com/enatega/food-delivery-multivendor) | React Native, GraphQL, Node.js | Multi-sided platform mechanics: customer ordering, merchant kitchen dashboard, rider dispatch, and finite-state order lifecycles. |

---

## 4. Grocery Quick-Commerce (Blinkit Model)
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Quick-Commerce App** | [`Aakash901/BlinkitClone`](https://github.com/Aakash901/BlinkitClone) | Kotlin, Android SDK, MVVM | Quick-commerce Kirana workflows: direct add/remove quantity stepper components on catalog cards, subcategory shelves, and stock reservations. |

---

## 5. Ride Sharing & Real-Time Tracking (Uber / InDrive Model)
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Mobile Apps** | [`anandwana001/uber-clone`](https://github.com/anandwana001/uber-clone) | Kotlin, Coroutines, Mapbox | Decoupled Passenger UI and Driver background GPS broadcast loop with vehicle bearing/heading rotation. |
| **Realtime Engine** | [`amitshekhariitbhu/ridesharing-uber-lyft-app`](https://github.com/amitshekhariitbhu/ridesharing-uber-lyft-app) | Kotlin, Coroutines, WebSockets | Smooth marker interpolation, high-frequency location socket handling, and trip matchmaking transitions. |
| **Bidding Model** | [`WaqasSiddiqi/inDrive-Clone`](https://github.com/WaqasSiddiqi/inDrive-Clone) | Flutter, Node.js | InDrive-style real-time fare bidding where drivers counter-offer passenger fares before assignment. |
| **Full-Stack Trip Cycle** | [`rohitstwt/Uber-Clone`](https://github.com/rohitstwt/Uber-Clone) | React Native, TypeScript, Postgres | Trip lifecycle state machine, route polyline storage, and dynamic fare computation schemas. |

---

## 6. Hotels, Stays & Rentals
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Hotels (Supabase)** | [`OthmaneNissoukin/nextjs-hotel-booking`](https://github.com/OthmaneNissoukin/nextjs-hotel-booking) | Next.js App Router, Supabase | Direct Supabase integration for stay reservations, capacity filtering, media buckets, and Row Level Security (RLS). |
| **Calendar Engine** | [`aumsoni2002/Airbnb-Clone`](https://github.com/aumsoni2002/Airbnb-Clone) | Next.js, TypeScript, PostgreSQL | PostgreSQL `daterange` reservation overlap handling, guest filtering, host listing flow, and reviews. |
| **Mobile Stay UI** | [`pawanpk87/MyRoom`](https://github.com/pawanpk87/MyRoom) | Kotlin, Jetpack Compose | Native Material 3 DateRangePicker integration, guest selectors (Adults/Kids), and hotel amenity layouts. |
| **Room Rental Finder** | [`Samizen/RoomRental`](https://github.com/Samizen/RoomRental) | Full-stack Web | Long-term flat/room leasing: landlord verification, room layouts (1RK, 1BHK), tenant constraints, and utilities. |
| **Vehicle Rental** | [`vikasrana07/luxeride`](https://github.com/vikasrana07/luxeride) | Next.js, Supabase, Tailwind CSS | Supabase-driven fleet inventory, hourly/daily pricing matrices, reservation records, and deposit tracking. |

---

## 7. Camera & Stories (Snapchat Model)
| Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Compose Camera & UI** | [`Debanshu777/Compose-Snapchat-Clone`](https://github.com/Debanshu777/Compose-Snapchat-Clone) | Kotlin, Compose, CameraX | Full-screen CameraX viewfinder, horizontal pager navigation, story feeds, and interactive Snap Map. |
| **AR Lenses & SDK** | [`Snapchat/camera-kit-android-sdk`](https://github.com/Snapchat/camera-kit-android-sdk) | Kotlin / Swift SPM | Integration of official Snap AR lenses, real-time face tracking, and 3D filters into native camera viewfinders. |
| **Web Face Filters** | [`TowhidKashem/snapchat-clone`](https://github.com/TowhidKashem/snapchat-clone) | React, TypeScript, SCSS | WebGL real-time face tracking (`jeelizFaceFilter`), browser camera captures, and Mapbox Snap Map pins. |

---

## How to Sync Reference Repos Locally

```bash
# Sync default AI Voice Agent repos
./reference/sync.sh voice

# Sync Chat & Messaging references
./reference/sync.sh chat

# Sync Food & Delivery references
./reference/sync.sh food

# Sync Ridesharing references
./reference/sync.sh rides

# Sync everything
./reference/sync.sh all
```

> **Note on Licensing**: All reference repositories are third-party open-source projects. Check each repository's license (MIT, Apache 2.0, BSD) before adapting code patterns into evrry.
