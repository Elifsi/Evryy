# apps/partner/ios — evryy Native Partner iOS App

> **Platform**: evryy Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evryy.git](https://github.com/Elifsi/Evryy.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Technology Stack & Key Dependencies

```swift
// Swift Package Manager (Package.swift / Xcode Dependencies)

// 1. Supabase Swift Client (PostgREST, Auth, Realtime, Storage)
.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.14.0")

// 2. High-Priority Push Alerts & APNs
// UserNotifications framework with Critical Alert entitlements for high-decibel order rings

// 3. Printing & Hardware
// CoreBluetooth for portable ESC/POS thermal printers & AirPrint support
```

---

## 2. Architecture & Design Patterns

- **UI Framework**: Modern SwiftUI with iPad split-view navigation (`NavigationSplitView`) for kitchen display systems (KDS) and counter order checkout.
- **Concurrency**: Native Swift Concurrency (`async/await`) consuming real-time order state streams from Supabase:
  ```swift
  for await change in client.channel("merchant-orders").postgresChange(...) {
      // update incoming order queue
  }
  ```
- **Staff Role Scoping**: UI surfaces adapt automatically to the logged-in staff role (`owner`, `manager`, `cashier`, `driver`) based on PostgreSQL RLS claims.

---

## 3. Reference Alignments

- **Multi-Vendor Kitchen Dashboard**: Follows [`enatega/food-delivery-multivendor`](https://github.com/enatega/food-delivery-multivendor) for ticket prep timers and item modifier views.
- **Hotel Desk Operations**: Follows [`OthmaneNissoukin/nextjs-hotel-booking`](https://github.com/OthmaneNissoukin/nextjs-hotel-booking) and [`pawanpk87/MyRoom`](https://github.com/pawanpk87/MyRoom) for room status, guest check-in, and reservation rosters.
