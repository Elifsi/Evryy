# apps/consumer/ios — evrry Native Consumer iOS App

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Technology Stack & Key Dependencies

```swift
// Swift Package Manager (Package.swift / Xcode Dependencies)

// 1. Supabase Swift Client (PostgREST, Auth, Realtime, Storage)
.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.14.0")

// 2. Push Notifications via Firebase Messaging (APNs Bridge)
.package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.23.0")

// 3. Native Maps & Location
// GoogleMaps SPM or MapKit integration
// CoreLocation: Native iOS hardware GPS location provider with background navigation

// 4. Audio Streaming & Voice Processing
// AVFoundation: Low-level audio recording via AVAudioEngine and live voice playback node
```

---

## 2. Architecture & Design Patterns

- **Architecture**: Clean MVVM Architecture with `@Observable` (iOS 17+) or `@StateObject` ViewModels.
- **UI Framework**: Declarative SwiftUI adhering to Apple Human Interface Guidelines (HIG).
- **Concurrency**: Native Swift Concurrency (`async/await`, `Task`, `AsyncSequence`).
- **Realtime Channels**: Direct consumption of Supabase Realtime channel streams:
  ```swift
  for await change in channel.postgresChange(AnyAction.self, schema: "public") {
      // update state
  }
  ```
- **Zero Google Directions Fees**: Free Google Maps SDK / MapKit for map viewport; polylines and turn-by-turn geometry fetched from self-hosted OSRM endpoints.

---

## 3. Reference Architecture Alignments

- **WhatsApp Chat UI**: Follows [`efxlve/whatsapp-clone`](https://github.com/efxlve/whatsapp-clone) for swipe-to-reply, thread grouping, media sheets, and contact lists.
- **Camera & Lenses**: Follows [`Snapchat/camera-kit-ios-sdk`](https://github.com/Snapchat/camera-kit-ios-sdk) for AVFoundation capture pipelines.
- **Payment Handling**: Web redirection and deep-link callback handlers for Khalti (`/api/v2/epay/initiate/`) and eSewa HMAC-SHA256 signatures.

---

## 4. Reference Prototype

Refer to the working web prototype at [`prototype/Phone/`](../../../prototype/Phone/) for feature workflows, state machines, and UX specifications.

> ⚠️ **Security Reminder**: Never place Supabase `service_role` keys, private gateway secrets, or merchant keys into Xcode configurations, `Info.plist`, or app bundles.
