# Push Notification Service Architecture (FCM v1 & APNs)
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. Overview & High-Priority Invariants

Real-time operations across Nepal's on-demand sectors require sub-second push notifications:
* **Restaurant KDS & Kitchens**: Instant loud buzzer/chime when a new customer order arrives (`order_placed`).
* **Delivery Riders**: High-priority alert when food or grocery packages are ready for pickup (`order_ready`).
* **Ride-Hailing & Cabs**: Instant fare bid notifications between passengers and drivers (`ride_bid_received`, `ride_bid_accepted`).
* **E2EE Chat**: Push alert when receiving a new message or snap while the app is closed.

All push notifications route through the centralized **Supabase Edge Function (`push-notify`)**, which targets active device tokens registered in `public.user_device_tokens`.

---

## 2. Push Notification Architecture

```
[ Event: New Order / Ride Bid / Chat Message ]
                     │
                     ▼
  [ Supabase Edge Function: push-notify ]
  • Queries public.user_device_tokens for active devices
  • Separates Android (FCM), iOS (APNs), and Web Push
                     │
       ┌─────────────┴─────────────┐
       ▼                           ▼
[ Dev Mock Mode ]           [ Production Mode ]
• No Firebase key needed    • Google OAuth2 with FCM v1
• Logs notification to      • POST https://fcm.googleapis.com/v1/projects/{id}/messages:send
  server terminal screen    • Cleans up stale / uninstalled tokens
```

---

## 3. Token Registration & Lifecycle (Migration 0015)

Device tokens are managed in [`supabase/migrations/20261005000015_device_push_tokens.sql`](file:///home/rahul/codes/Evrry/supabase/migrations/20261005000015_device_push_tokens.sql):

1. **Multi-App Variant Isolation**: Distinguishes between `consumer`, `partner`, and `admin` devices so kitchen tablets only receive store orders and personal phones only receive consumer orders.
2. **Automated Token Recycling**: If an Android or iPhone is shared, or a user logs out and logs in as someone else, `register_device_token()` rebinds the token to the active `auth.uid()`.
3. **Automated Dead Token Pruning**: When FCM returns `UNREGISTERED` (e.g. app was uninstalled), `push-notify` automatically flags `is_active = FALSE`, keeping database queries fast and cost-free.

---

## 4. How to Test Right Now (Dev Mock Mode)

When `FIREBASE_SERVICE_ACCOUNT` is not yet set in Supabase secrets, the function runs in **Dev Mock Mode**:
```
===================================================================
🔔 [PUSH NOTIFICATION — DEV MOCK MODE]
Target:      partner -> 7f83b2...
Title:       New Order Incoming! #10042
Body:        2x Chicken Steamed Momo (NPR 450.00)
Priority:    high
Sound:       kitchen_buzzer
Data:        {"order_id": "...", "type": "order_placed"}
Recipients:  1 active device(s)
===================================================================
```
Zero cost, instant visibility, and zero external setup needed to test full app flows.

---

## 5. How to Go Live in Production

When ready for live push notifications:
1. In Google Firebase Console, go to **Project Settings > Service Accounts**.
2. Click **Generate New Private Key** to download the JSON service account file.
3. Set the JSON string in Supabase secrets:
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"evrry-prod",...}'
   ```
4. The `push-notify` function will immediately start dispatching live notifications to real devices across Nepal.

---

## 6. Client Implementations

| Platform | Location | Method |
|---|---|---|
| **Android Consumer (Kotlin)** | [`apps/consumer/android/.../EvrryPushService.kt`](file:///home/rahul/codes/Evrry/apps/consumer/android/src/main/kotlin/com/elifsi/evrry/consumer/network/EvrryPushService.kt) | `registerDeviceToken()`, `unregisterDeviceToken()` |
| **Android Partner (Kotlin)** | [`apps/partner/android/.../EvrryPartnerPushService.kt`](file:///home/rahul/codes/Evrry/apps/partner/android/src/main/kotlin/com/elifsi/evrry/partner/network/EvrryPartnerPushService.kt) | `registerDeviceToken(fcmToken, partnerId)` |
| **iOS Consumer (Swift)** | [`apps/consumer/ios/.../EvrryPushService.swift`](file:///home/rahul/codes/Evrry/apps/consumer/ios/EvrryConsumer/Services/EvrryPushService.swift) | `registerDeviceToken()`, `unregisterDeviceToken()` |
| **iOS Partner (Swift)** | [`apps/partner/ios/.../EvrryPartnerPushService.swift`](file:///home/rahul/codes/Evrry/apps/partner/ios/EvrryPartner/Services/EvrryPartnerPushService.swift) | `registerDeviceToken(apnsToken, partnerId)` |
| **Web (Next.js)** | [`apps/web/common/push.ts`](file:///home/rahul/codes/Evrry/apps/web/common/push.ts) | `sendPushNotification()`, `registerWebPushToken()` |
