# apps/consumer/android — evrry Native Consumer Android App

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Technology Stack & Key Dependencies

```kotlin
// apps/consumer/android/build.gradle.kts dependencies reference

// Native Maps & Hardware Location
implementation("com.google.android.gms:play-services-maps:18.2.0")
implementation("com.google.android.gms:play-services-location:21.2.0")
implementation("com.google.maps.android:maps-compose:4.3.3")

// Supabase Kotlin Multiplatform SDK
implementation(platform("io.github.jan-tennert.supabase:bom:3.0.0"))
implementation("io.github.jan-tennert.supabase:postgrest-kt")
implementation("io.github.jan-tennert.supabase:auth-kt")
implementation("io.github.jan-tennert.supabase:realtime-kt")
implementation("io.github.jan-tennert.supabase:storage-kt")

// Low-Latency Networking & Audio WebSockets
implementation("io.ktor:ktor-client-okhttp:2.3.12")
implementation("io.ktor:ktor-client-websockets:2.3.12")
implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

// Push Notifications
implementation("com.google.firebase:firebase-messaging-ktx:23.4.1")

// Camera & Viewfinder
implementation("androidx.camera:camera-camera2:1.3.2")
implementation("androidx.camera:camera-lifecycle:1.3.2")
implementation("androidx.camera:camera-view:1.3.2")

// Nepal Fintech Checkout
// Khalti SDK or custom secure Chrome Custom Tabs / WebView intent for eSewa & Khalti
```

---

## 2. Architecture & Design Patterns

- **Architecture**: MVI / MVVM with Clean Architecture (Domain, Data, Presentation layers).
- **UI Framework**: 100% Jetpack Compose with Material 3 theming.
- **Async Concurrency**: Kotlin Coroutines and reactive `StateFlow` / `SharedFlow`.
- **Realtime Integration**: Supabase `postgresChangeFlow` for live order status and encrypted chat sync.
- **Zero Google Directions Fees**: Free Google Maps SDK for base tiles; road polylines and ETAs rendered from self-hosted OSRM endpoints (`http://osrm.evrry.local:5000/route/v1/driving/...`).

---

## 3. Reference Architecture Alignments

- **Multi-Variant Architecture**: Follows [`kaaneneskpc/Deliverr`](https://github.com/kaaneneskpc/Deliverr) for build flavors (`customer`, `restaurant`, `rider`).
- **Quick-Commerce Steppers**: Follows [`Aakash901/BlinkitClone`](https://github.com/Aakash901/BlinkitClone) for Kirana catalog cards with quantity steppers.
- **WhatsApp Chat UI**: Follows [`GetStream/whatsApp-clone-compose`](https://github.com/GetStream/whatsApp-clone-compose) for bubbles, voice notes, and read ticks.
- **Camera & Snap**: Follows [`Debanshu777/Compose-Snapchat-Clone`](https://github.com/Debanshu777/Compose-Snapchat-Clone) with CameraX and Snap Map.

---

## 4. Reference Prototype

Refer to the working web prototype at [`prototype/Phone/`](../../../prototype/Phone/) for feature workflows, state machines, and UX specifications.

> ⚠️ **Security Reminder**: Never place Supabase `service_role` keys, private gateway secrets, or merchant keys into Android build configs, code, or assets.
