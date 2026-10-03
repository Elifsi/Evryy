# apps/partner/android — evrry Native Partner Android App

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Technology Stack & Key Dependencies

```kotlin
// apps/partner/android/build.gradle.kts dependencies reference

// Supabase Kotlin Multiplatform SDK
implementation(platform("io.github.jan-tennert.supabase:bom:3.0.0"))
implementation("io.github.jan-tennert.supabase:postgrest-kt")
implementation("io.github.jan-tennert.supabase:auth-kt")
implementation("io.github.jan-tennert.supabase:realtime-kt")
implementation("io.github.jan-tennert.supabase:storage-kt")

// Native Maps & Hardware Location Broadcast
implementation("com.google.android.gms:play-services-maps:18.2.0")
implementation("com.google.android.gms:play-services-location:21.2.0")
implementation("com.google.maps.android:maps-compose:4.3.3")

// High-Priority Audio & Foreground Services
implementation("androidx.core:core-ktx:1.12.0")
implementation("androidx.lifecycle:lifecycle-service:2.7.0")

// ESC/POS Thermal Printing (Bluetooth & USB)
// e.g. com.dantsu.escposprinter:escposprinter:3.3.0
```

---

## 2. Multi-Flavor Architecture (`kaaneneskpc/Deliverr`)

The partner application uses single-codebase multi-variant Gradle build flavors:
- **`flavorDimensions += "partnerType"`**
  - `rider`: Optimized for delivery riders and mobility drivers. Foreground GPS tracking loop, order pickup OTPs, and turn-by-turn routing.
  - `restaurant`: Optimized for tablets. Kitchen Display System (KDS), preparation timers, 86ing items, and thermal printer integration.
  - `store`: Optimized for grocery pick & pack with barcode scanning.

---

## 3. Official Architectural Reference Alignments

- **Kitchen KDS & Order Lifecycles**: Follows [`enatega/food-delivery-multivendor`](https://github.com/enatega/food-delivery-multivendor) for finite-state order transitions (`pending_vendor` $\rightarrow$ `accepted` $\rightarrow$ `preparing` $\rightarrow$ `ready_for_pickup`).
- **Driver Bidding Counter-Offers**: Follows [`WaqasSiddiqi/inDrive-Clone`](https://github.com/WaqasSiddiqi/inDrive-Clone) for real-time ride counter-bids before trip assignment.
- **Vehicle Rental Agency Portal**: Follows [`arman-dogru/car-rental-android-app`](https://github.com/arman-dogru/car-rental-android-app) for vehicle listing, inspection checklist, and security deposit management.
- **Driver GPS Broadcast**: Follows [`anandwana001/uber-clone`](https://github.com/anandwana001/uber-clone) with vehicle bearing/heading calculation.

---

## 4. Security & Permissions

- Partner staff permissions strictly governed by PostgreSQL Row Level Security (RLS) linked to `public.partner_members` (`owner`, `manager`, `cashier`, `driver`).
- Zero financial or bank disbursement authority on `cashier` or `driver` logins.
