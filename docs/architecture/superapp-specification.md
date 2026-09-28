# evryy — Super App Architecture & Implementation Specification

> **Organization**: Elifsi Technologies Private Limited  
> **Platform**: evryy Super App Ecosystem  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  
> **Clients**: Android (Kotlin + Jetpack Compose), iOS (Swift + SwiftUI), Web (Next.js App Router)  
> **Backend**: Supabase (PostgreSQL 15+, PostGIS, Realtime, Auth, Storage, Edge Functions)

---

## 1. Technology Stack & Core Protocols

- **Backend / Database:** Supabase (PostgreSQL 15+, PostGIS spatial extensions, Realtime WebSockets, Supabase Auth, Supabase Storage, Edge Functions).
- **Android Client:** Native Kotlin, Jetpack Compose, Coroutines, StateFlow, MVVM/MVI Clean Architecture, Multi-Module Gradle, `io.github.jan-tennert.supabase:supabase-kt` (Postgrest, Realtime, Auth, Storage), Google Maps Compose, CameraX.
- **iOS Client:** Native Swift, SwiftUI, Swift Concurrency (`async/await`), Clean MVVM Architecture, Swift Package Manager, `github.com/supabase/supabase-swift`, MapKit, AVFoundation.
- **Web / Admin Client:** Next.js (App Router, TypeScript, Tailwind CSS, `@supabase/supabase-js`, `@supabase/ssr`, Mapbox GL / Leaflet).
- **Geospatial & Address Foundation:** Administrative divisions of Nepal (Provinces $\rightarrow$ Districts $\rightarrow$ Local Levels/Palikas $\rightarrow$ Wards) seeded into Supabase as relational foreign-key anchors.

---

## 2. Official Repository Reference Matrix

When designing architecture, schema models, or native client features, reference and align with the design patterns of these specialized public GitHub repositories:

| Vertical / Domain | Target Repository | Tech Stack | Architectural Role & Implementation Reference |
|---|---|---|---|
| **Administrative Spine** | [`bibekoli/local-levels-of-nepal-dataset`](https://github.com/bibekoli/local-levels-of-nepal-dataset) | JSON / SQL | Source of truth for 7 Provinces, 77 Districts, and 753 Local Levels (Metros, Sub-Metros, Municipalities, Rural Palikas) with English and Nepali names. |
| **Food Delivery (Android Native)** | [`kaaneneskpc/Deliverr`](https://github.com/kaaneneskpc/Deliverr) | Kotlin, Jetpack Compose | Reference for multi-variant single-codebase architectures (`customer`, `restaurant`, `rider` build flavors) in pure Jetpack Compose. |
| **Food & Multi-Vendor Ops** | [`enatega/food-delivery-multivendor`](https://github.com/enatega/food-delivery-multivendor) | React Native, GraphQL, Node.js | Multi-sided platform mechanics: customer ordering, merchant kitchen dashboard, rider dispatch, and finite-state order lifecycles. |
| **Grocery Quick-Commerce** | [`Aakash901/BlinkitClone`](https://github.com/Aakash901/BlinkitClone) | Kotlin, Android SDK, MVVM | Quick-commerce Kirana workflows: direct add/remove quantity stepper components on catalog cards, subcategory shelves, and stock reservations. |
| **Ride Sharing (Mobile Apps)** | [`anandwana001/uber-clone`](https://github.com/anandwana001/uber-clone) | Kotlin, Coroutines, Mapbox | Decoupled Passenger UI and Driver background GPS broadcast loop with vehicle bearing/heading rotation. |
| **Ride Sharing (Realtime Engine)** | [`amitshekhariitbhu/ridesharing-uber-lyft-app`](https://github.com/amitshekhariitbhu/ridesharing-uber-lyft-app) | Kotlin, Coroutines, WebSockets | Smooth marker interpolation, high-frequency location socket handling, and trip matchmaking transitions. |
| **Ride Sharing (Bidding Model)** | [`WaqasSiddiqi/inDrive-Clone`](https://github.com/WaqasSiddiqi/inDrive-Clone) | Flutter, Node.js | InDrive-style real-time fare bidding where drivers counter-offer passenger fares before assignment. |
| **Ride Sharing (Full-Stack)** | [`rohitstwt/Uber-Clone`](https://github.com/rohitstwt/Uber-Clone) | React Native, TypeScript, Postgres | Trip lifecycle state machine, route polyline storage, and dynamic fare computation schemas. |
| **Hotels & Stays (Supabase)** | [`OthmaneNissoukin/nextjs-hotel-booking`](https://github.com/OthmaneNissoukin/nextjs-hotel-booking) | Next.js App Router, Supabase | Direct Supabase integration for stay reservations, capacity filtering, media buckets, and Row Level Security (RLS). |
| **Hotels & Stays (Calendar Engine)** | [`aumsoni2002/Airbnb-Clone`](https://github.com/aumsoni2002/Airbnb-Clone) | Next.js, TypeScript, PostgreSQL | PostgreSQL `daterange` reservation overlap handling, guest filtering, host listing flow, and reviews. |
| **Hotels & Stays (Mobile UI)** | [`pawanpk87/MyRoom`](https://github.com/pawanpk87/MyRoom) | Kotlin, Jetpack Compose | Native Material 3 DateRangePicker integration, guest selectors (Adults/Kids), and hotel amenity layouts. |
| **Room Rental Finder** | [`Samizen/RoomRental`](https://github.com/Samizen/RoomRental) | Full-stack Web | Long-term flat/room leasing: landlord verification, room layouts (1RK, 1BHK, Single Room), tenant constraints (bachelor/family), and utilities (water/parking). |
| **Room Rental Finder (Supabase)** | [`remediios/vista`](https://github.com/remediios/vista) | Next.js, Supabase, Tailwind CSS | Property listing submission, photo uploads to Supabase Storage, and geospatial category exploration. |
| **Room Rental Finder (Regional)** | [`EmpSwarup/roomfinder`](https://github.com/EmpSwarup/roomfinder) | Full-stack Web | Localized room finding for Nepal featuring ward-level search and direct landlord communication channels. |
| **Vehicle Rental (Supabase)** | [`vikasrana07/luxeride`](https://github.com/vikasrana07/luxeride) | Next.js, Supabase, Tailwind CSS | Supabase-driven fleet inventory, hourly/daily pricing matrices, reservation records, and deposit tracking. |
| **Vehicle Rental (Mobile)** | [`arman-dogru/car-rental-android-app`](https://github.com/arman-dogru/car-rental-android-app) | Kotlin, MVVM, Android SDK | Two-sided car/bike agency portal and customer booking flow with specification filters (transmission, fuel, seats). |
| **Vehicle Rental (Multi-Category)** | [`aryairama/next-vehicle-rental`](https://github.com/aryairama/next-vehicle-rental) | Next.js, Express, Redux | Multi-category rental handling (motorcycles, scooters, sedans, SUVs) with category-specific rate cards. |
| **Vehicle Rental (Listing UI)** | [`livewithcodeankit/car-rental`](https://github.com/livewithcodeankit/car-rental) | Next.js, TypeScript, Tailwind CSS | High-performance catalog browsing, specs comparison, and interactive pickup/return timestamp selector. |
| **WhatsApp Chat (Web)** | [`Gmarvis/whatsapp-clone`](https://github.com/Gmarvis/whatsapp-clone) | Next.js, Supabase, Tailwind CSS | Direct Supabase Realtime chat implementation: message threads, real-time sync, and conversational state. |
| **WhatsApp Chat (Android Native)** | [`GetStream/whatsApp-clone-compose`](https://github.com/GetStream/whatsApp-clone-compose) | Kotlin, Jetpack Compose | Production WhatsApp UI: chat bubbles, read ticks (sent, delivered, read), voice notes, and attachment sheets. |
| **WhatsApp Chat (iOS Native)** | [`efxlve/whatsapp-clone`](https://github.com/efxlve/whatsapp-clone) | Swift, SwiftUI | Native iOS messaging UI: swipe-to-reply, grouping, attachment handling, and contact lists. |
| **Snapchat (Compose Camera & UI)** | [`Debanshu777/Compose-Snapchat-Clone`](https://github.com/Debanshu777/Compose-Snapchat-Clone) | Kotlin, Compose, CameraX | Full-screen CameraX viewfinder, Accompanist horizontal pager navigation, story feeds, and interactive Snap Map. |
| **Snapchat (Official AR Lenses)** | [`Snapchat/camera-kit-android-sdk`](https://github.com/Snapchat/camera-kit-android-sdk) & `camera-kit-ios-sdk` | Kotlin / Swift SPM | Integration of official Snap AR lenses, real-time face tracking, and 3D filters into native camera viewfinders. |
| **Snapchat (Web & Face Filters)** | [`TowhidKashem/snapchat-clone`](https://github.com/TowhidKashem/snapchat-clone) | React, TypeScript, SCSS | WebGL real-time face tracking (`jeelizFaceFilter`), browser camera captures, and Mapbox Snap Map pins. |
| **Android Client SDK** | [`jan-tennert/supabase-kt`](https://github.com/jan-tennert/supabase-kt) | Kotlin Multiplatform / Android | Primary client SDK for Android: Postgrest queries, Realtime subscriptions, Auth, and Storage. |
| **iOS Client SDK** | [`supabase/supabase-swift`](https://github.com/supabase/supabase-swift) | Swift, SPM | Primary client SDK for iOS: Swift Concurrency (`async/await`) and Realtime channel streaming. |

---

## 3. Unified Database Architecture & Integration Rules

When generating SQL schemas, Supabase Edge Functions, or client queries, adhere strictly to these database contracts:

### A. Geospatial & Administrative Spine
- Every entity with a physical location (`stores`, `properties`, `room_listings`, `rental_vehicles`, `driver_locations`, `snap_map_locations`) must reference `local_levels(id)` from `bibekoli/local-levels-of-nepal-dataset` and store a PostGIS `geography(point, 4326)` column.
- Use PostGIS spatial indices (`GIST`) for all proximity queries (`st_dwithin`, `st_distance`).

### B. Concurrency & Overlap Prevention
- **Hotel Stays:** Utilize PostgreSQL `daterange` with `btree_gist` exclusion constraints to mathematically prevent double-booking the same room on overlapping dates:
  ```sql
  ALTER TABLE room_reservations
    ADD CONSTRAINT no_double_booking
    EXCLUDE USING gist (room_id WITH =, reservation_period WITH &&);
  ```
- **Vehicle Rentals:** Utilize PostgreSQL `tsrange` (timestamp ranges) to prevent overlapping rentals for the same vehicle ID during hourly or multi-day reservations:
  ```sql
  ALTER TABLE vehicle_rentals
    ADD CONSTRAINT no_vehicle_overlap
    EXCLUDE USING gist (vehicle_id WITH =, rental_period WITH &&);
  ```
- **Grocery Stock:** Enforce strict atomic deduction via PostgreSQL stored procedures (`FOR UPDATE` row locking) to prevent race conditions and negative inventory:
  ```sql
  SELECT stock_quantity FROM inventory_items
  WHERE id = target_item_id FOR UPDATE;
  ```

### C. Shared Horizontal Engine
- **Identity & Roles:** A single `public.profiles` table linked to `auth.users(id)` with a typed role enum (`consumer`, `rider`, `driver`, `merchant`, `landlord`, `host`, `admin`).
- **In-App Wallet:** A shared `wallets` balance table and immutable `wallet_transactions` double-entry ledger handling refunds, ride fares, grocery payments, and rental deposits.
- **Messaging:** A unified `chats` and `messages` table with Supabase Realtime replication powering both social WhatsApp-style P2P messaging and contextual order/ride communication.
- **Ephemeral TTL & Cleanup:** Ephemeral media (`snaps`) must use auto-burn RPCs (`open_and_burn_snap`), while `stories` enforce a 24-hour expiration filter (`expires_at > now()`).
- **Row Level Security (RLS):** Every table must have RLS enabled with explicit policies scoping read/write access via `auth.uid()`.

---

## 4. Client Code Generation Instructions

When writing client-side code:

### 1. Kotlin (Android)
- Write clean, modular Jetpack Compose code with `@Composable` functions.
- Use `supabase-kt` with Kotlinx Serialization (`@Serializable`).
- Use Kotlin `Flow` to consume Supabase Realtime streams (`postgresChangeFlow`).
- Use AndroidX CameraX for camera-first viewfinder screens.
- Leverage multi-variant build flavors (`customer`, `restaurant`, `rider`) following `kaaneneskpc/Deliverr`.

### 2. Swift (iOS)
- Write declarative SwiftUI views with `@StateObject` / `@Observable` ViewModels.
- Use `supabase-swift` with Swift `Codable` structs matching the PostgreSQL snake_case columns via `CodingKeys`.
- Use Swift Concurrency (`Task`, `for await ... in channel.postgresChange(...)`).
- Use AVFoundation for camera operations and MapKit for map viewports.

### 3. Next.js (Web)
- Use App Router (`app/` directory), React Server Components (RSC) for initial page loads, and Client Components (`'use client'`) for live tracking and chat.
- Use `@supabase/ssr` to manage cookies and session validation across Server and Client boundaries.
- Mapbox GL / Leaflet for interactive maps and location picker dialogs.
