# Push Notification & Background Worker Service

> **Microservice**: `services/notification-worker`  
> **Platform**: evrry Super App Ecosystem  
> **Maintainer**: Elifsi Technologies Private Limited  
> **Integrations**: Firebase Cloud Messaging (FCM), Apple Push Notification service (APNs), Redis Task Queue, Supabase Database Webhooks  

---

## 1. Overview

Push notifications cannot rely on persistent open WebSockets because mobile operating systems (Android Doze mode and iOS Background Execution limits) terminate idle background network connections to preserve battery life. When a user locks their device, background push notifications through FCM and APNs take over.

```
[ Backend Event / Supabase Webhook ] ──► [ Redis Task Queue / Celery ]
                                                   │
                                                   ▼
                                        [ Push Notification Worker ]
                                                   │
                                    ┌──────────────┴──────────────┐
                                    ▼                             ▼
                            [ Firebase (FCM) ]             [ Apple (APNs) ]
                                    │                             │
                                    ▼                             ▼
                           Android Device (Kotlin)        iOS Device (Swift)
```

---

## 2. Operation Mechanics

### A. Push Token Registration
- On app launch, the native Kotlin or Swift client requests notification permissions, retrieves the device push token, and registers it with the Supabase backend:
  - Table: `public.user_push_tokens` (`user_id`, `fcm_token`, `apns_token`, `platform`, `updated_at`).

### B. Event Triggers
1. **Order Lifecycle**:
   - Merchant accepts order $\rightarrow$ Push to Consumer: *"Your order has been accepted and is being prepared!"*
   - Rider picks up order $\rightarrow$ Push to Consumer: *"Rider is on the way!"*
   - Rider reaches delivery point $\rightarrow$ Push to Consumer: *"Rider has arrived at your gate."*
2. **Ride Sharing Alerts**:
   - Driver assigned $\rightarrow$ Push with vehicle plate & OTP.
   - Driver arrival $\rightarrow$ Push with sound alert.
   - Trip completed $\rightarrow$ Push with fare receipt and rating sheet.
3. **Safety & Emergency Pings**:
   - Immediate high-priority push notifications dispatched to designated family emergency contacts when an SOS trigger is activated.

### C. Worker Architecture
- Powered by `firebase-admin>=6.4.0` and Celery / Redis.
- Subscribes to Supabase PostgreSQL change events or pops tasks from a Redis task queue.
- Dispatches payload with `priority: high` and background data payload (`content-available: 1` for iOS).

---

## 3. Dependencies

See [`requirements.txt`](./requirements.txt) for the pinned dependencies list.
