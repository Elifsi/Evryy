# evrry — Social, Loyalty, Referrals & Multi-Vertical Architecture Specification

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

---

## 1. Booking, Listings & Delivery Interaction Architecture

evrry unifies 4 distinct transaction models into a single consumer client experience without friction:

| Service Vertical | Interaction Model | Checkout & Payment Flow | Dispatch & Settlement |
|---|---|---|---|
| **Hotel Booking** | Instant reservation based on check-in/out dates, guest count, and room type. | **Direct Checkout (No Cart)**: Tap "Book Now" $\rightarrow$ Direct to Payment Gateway (Fonepay QR / Card / eSewa / Khalti) $\rightarrow$ Instant Room Confirmation. | Syncs with hotel partner desk system; generates booking voucher with QR code. |
| **Room Renting / Real Estate** | Classified directory browsing (BHK layouts, photos, water/electricity utilities, parking, landlord badge). | **No In-App Payment**: Zero platform escrow/holding. Direct "Click-to-Call" or "Schedule Property Visit" between tenant and landlord. | Direct P2P negotiation without intermediary fees. |
| **Food & Parcel Delivery** | Multi-item catalog with dynamic quantity steppers (`+ / -`) on menu cards. | **Cart-Based Multi-Item Checkout**: Add to cart $\rightarrow$ Subtotal calculation with delivery/platform fees $\rightarrow$ Payment (Fonepay QR, eSewa, Khalti, Card, or COD). | Order routed to Merchant KDS (Kitchen Display); delivery rider dispatched upon kitchen acceptance. |
| **Ride Sharing** | Real-time geospatial pickup & dropoff with route polyline and upfront fare estimate. | **Trip-End / Direct Settlement**: Driver matched via real-time WebSocket bidding or instant assignment $\rightarrow$ Trip completed $\rightarrow$ Cash / Fonepay QR / Card paid at destination. | Rider GPS broadcast loop with bearing/heading rotation streamed to passenger map. |

---

## 2. Social & Messaging Engine (WhatsApp + Instagram + Snapchat)

### A. Identity & Discoverability (The WeChat Model)
- **Permanent `@handle` Discovery**: Users are discovered and added via their unique username handle (e.g., `@rahul`, `@sarita`).
- **Personal Profile QR Codes**: Every user has a dynamic QR code in their profile card for instant, 1-second in-person friend connections ("Scan & Add").
- **Privacy by Default**: Consumer phone numbers used for OTP login are strictly hidden from peers, group chats, strangers, and delivery drivers.
- **WeChat-Style Phone Search Toggle**: In `Settings -> Privacy`, users have a toggle: *"Allow others to find me by phone number"*. If enabled, friends who know the user's phone number can search it to discover their `@handle` (without revealing the phone number on their profile).

### B. Connection Gates & Verified Partner Bypass
- **Peer-to-Peer Gate**: Direct messages from strangers arrive in a **"Message Requests"** folder with Accept/Decline prompts. No notifications fire until approved.
- **Partner Auto-Bypass**: Verified business partners, delivery riders, and taxi drivers with an active, assigned order/trip bypass the gate automatically to message or call the customer directly for operational coordination. The thread auto-archives 2 hours after delivery.

### C. Dual-Mode Calling for Rides & Deliveries (VoIP + Cellular SIM)
- **Free In-App Voice Call**: High-definition, encrypted WebRTC voice calling over Wi-Fi / Mobile Data (Zero carrier airtime charges; phone numbers masked).
- **Cellular SIM Call Fallback**: Direct native dialer trigger (`tel:+977...`) when 4G/3G mobile data drops or is unavailable at the pickup location, ensuring no rider or passenger is ever stranded.

### D. Ephemeral & Social Media Layers
- **24-Hour Stories & Notes**: Placed at the top of the Chat dashboard. Notes allow short 60-character status thoughts; Stories allow 24-hour visual media snippets.
- **Snaps & Memories**: Fast-capture native camera interface (CameraX on Android, AVFoundation on iOS) with photo/video recording. Ephemeral snaps vanish after viewing or can be saved directly to the user's private, encrypted **"Memories Vault"** or exported to the device gallery.
- **End-to-End Encryption (E2EE)**: 1-on-1 text chats, voice notes, media files, and WebRTC audio/video calls are secured via the Signal Protocol.

---

## 3. Gamified Loyalty, Stamp Cards & Leagues

### A. Digital Stamp Cards (Japanese Point-Card Model)
- **Milestone Trigger**: 1 digital stamp awarded per transaction milestone (e.g., every NPR 500 spent on food, mart, or rides).
- **Sheet Completion**: Each digital card holds 10 stamp slots.
- **Reward Payout**: Completing the 10th stamp automatically issues a milestone rebate voucher (e.g., flat NPR 500 reward voucher).

### B. Tiered Competitive Leagues
- **Progress Metric**: 1 Tier Point (TP) earned per NPR 100 spent across any vertical.
- **League Progression**:
  $$\text{Copper} \longrightarrow \text{Bronze} \longrightarrow \text{Silver} \longrightarrow \text{Platinum} \longrightarrow \text{Diamond}$$
- **Perks by League**:
  - *Copper / Bronze*: Baseline rewards and standard support.
  - *Silver*: 1.25x E-Coin multiplier, 1 monthly free delivery voucher.
  - *Platinum*: 1.5x E-Coin multiplier, waived platform fees on rides, priority customer support.
  - *Diamond*: 2.0x E-Coin multiplier, VIP concierge service, zero platform fees, exclusive merchant discounts.

### C. Daily Check-Ins & Virtual Currency (E-Coins)
- **Check-In Streak**: Micro-rewards credited for consecutive daily app opens (Day 1: 5 coins $\rightarrow$ Day 7: 50 coins).
- **Checkout Redemption**: E-Coins can be toggled on at checkout for micro-discounts (capped at e.g. NPR 10 to NPR 25 per order to prevent margin erosion).

---

## 4. Referral Engine & Vouchers Hub

### A. Two-Sided Referral Mechanics ("Refer & Earn")
- **Unique Referral Links**: Every user gets a personalized referral code and link (e.g., `evrry.app/r/@handle` or `EVRRY-RAHUL`).
- **Two-Sided Incentive Loop**:
  1. **New User (Friend)**: Signs up via referral link and instantly receives a **NPR 100 Welcome Voucher** valid on their first Food or Ride order.
  2. **Referrer**: Once the invited friend completes their first paid delivery or ride, the referrer automatically receives a **NPR 150 Reward Voucher** in their Voucher Wallet.
- **Viral Sharing**: One-tap WhatsApp, Messenger, and SMS sharing buttons with pre-filled inviting copy.

### B. Dedicated Vouchers Hub & Wallet UI
- **Profile Navigation**: Dedicated **"Vouchers & Offers"** screen in the user profile and a prominent banner in the cart.
- **Voucher Wallet Capabilities**:
  - **Active Vouchers Tab**: Visual voucher cards showing discount amount (e.g. "NPR 150 OFF", "FREE DELIVERY", "20% OFF"), category applicability (Food, Grocery, Rides, Hotels), minimum spend requirement, and live expiry countdown.
  - **Enter Promo Code Input**: Manual redeem field for influencer promo codes, merchant flash sales, or seasonal event vouchers.
  - **Referral Progress Card**: Shows total friends invited, completed referrals, and total vouchers earned to date.
  - **1-Tap Checkout Application**: At checkout, eligible vouchers are auto-suggested with the highest-saving voucher pre-selected, displaying instant breakdown before payment.

---

## 5. PostgreSQL Database Schemas for Social, Loyalty & Vouchers

```sql
-- Loyalty & Tiers
CREATE TYPE loyalty_league AS ENUM ('copper', 'bronze', 'silver', 'platinum', 'diamond');

CREATE TABLE public.user_loyalty (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_league loyalty_league NOT NULL DEFAULT 'copper',
  tier_points INTEGER NOT NULL DEFAULT 0,
  e_coins_balance INTEGER NOT NULL DEFAULT 0,
  consecutive_checkin_days INTEGER NOT NULL DEFAULT 0,
  last_checkin_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Digital Stamp Cards
CREATE TABLE public.user_stamp_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vertical TEXT NOT NULL DEFAULT 'all', -- 'food', 'mart', 'rides', 'all'
  stamps_count INTEGER NOT NULL DEFAULT 0 CHECK (stamps_count >= 0 AND stamps_count <= 10),
  completed_sheets_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vouchers & Discounts
CREATE TABLE public.vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('flat_amount', 'percentage', 'free_delivery')),
  discount_value NUMERIC(10, 2) NOT NULL,
  min_order_value NUMERIC(10, 2) NOT NULL DEFAULT 0,
  max_discount_cap NUMERIC(10, 2), -- For percentage discounts
  applicable_vertical TEXT NOT NULL DEFAULT 'all', -- 'food', 'grocery', 'rides', 'hotels', 'all'
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User-Claimed Vouchers
CREATE TABLE public.user_vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  used_at TIMESTAMPTZ,
  order_id UUID REFERENCES public.orders(id),
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Referral Tracking
CREATE TABLE public.user_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code_used TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  first_order_id UUID REFERENCES public.orders(id),
  reward_voucher_id UUID REFERENCES public.vouchers(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```
