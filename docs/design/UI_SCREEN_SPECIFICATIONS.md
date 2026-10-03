# EVRRY — Screen Specifications

Companion to [`UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md) · [`UI_COMPONENT_CATALOG.md`](UI_COMPONENT_CATALOG.md) · [`UI_TYPOGRAPHY_AND_SPACING.md`](UI_TYPOGRAPHY_AND_SPACING.md). Reference: [`assets/App identity.jpg`](../../assets/App%20identity.jpg), "App UI Previews (Key Screens)".

**Legend** — 👁 Observed in reference · 🧭 Decision · ⚠ Provisional. All names/balances/transactions in the reference are **illustrative mock data**; nothing here implies a functioning feature.

> [!IMPORTANT]
> **Payments (reference screen 5) is excluded by product decision** (no in-app wallet; Balance, Send, Receive, Scan, Add Money, Wallet shortcut are not built). Section 5 below states what replaces it. Checkout payment choices (Fonepay QR, eSewa, Khalti, Card, COD) use the *Payment-method selector* in the component catalog.

---

## Navigation

**Primary bottom navigation (5, always visible on top-level screens)** — 👁 Home · Chat · Pay · Shop · More.
🧭 evrry mapping: **Home · Chat · Orders · Shop · More** (the *Pay* slot becomes **Orders/Activity**: orders, bookings, rides, history). ⚠ needs designer sign-off.

**Secondary service shortcuts (Home grid, 👁 10 tiles)**: Chat, Pay, Wallet, Contacts, Shop, Travel, Services, Bills, Health, More.
🧭 evrry mapping: **Chat · Food · Mart · Rides · Stays · Rooms · Rentals · Contacts · Vouchers · More** (Pay/Wallet/Bills/Health dropped or reassigned). No destination appears both as a tab *and* a tile except **Chat** and **Shop**, which are intentionally duplicated (👁 reference does the same) for one-tap reach.

| Concern | Rule |
|---|---|
| Selected tab | `brand.primary` filled icon + semibold label; re-tapping selected tab scrolls to top / pops to root |
| State | Each tab keeps its own back stack (restored on re-select) |
| Transitions | Push: slide-in 220 ms `standard`; modal/sheet: slide-up 220 ms; tab switch: cross-fade 150 ms; reduced-motion → fade only/none |
| Back | System back & top-bar chevron `<` (👁 present on Payments/Travel/Chat) pop one level; at root of a tab → go to Home; at Home → exit |
| Titles | Left-aligned `screenTitle` in top bar for root screens; inline back + title for pushed screens (👁 "< Travel") |
| Modules | Same top bar pattern, same bottom nav visibility (hidden only in full-screen flows: camera, map tracking, checkout, chat thread composer keeps nav hidden) |

---

## Screen 1 — Splash
| | |
|---|---|
| **Purpose** | Brand moment while app boots/auth restores |
| **Layout** 👁 | White bg; centred blue **symbol tile**; below it the **EVRRY wordmark**; below that tagline *Everything. One Place.*; abstract **blue gradient waves** lower area |
| **Components** | SymbolTile (≈ 96 px, radius ≈ 22 %), Wordmark (≈ 160–200 px wide), Tagline (`caption` wide-tracked, `text.secondary`), WaveArtwork (full-bleed bottom ≈ 40 % height, `accentLight`→`brand.secondary`) |
| **Tokens** | `background.main`, `gradient.brandIcon`, `gradient.waves`, `text.secondary` |
| **Spacing** 🧭 | Symbol→wordmark 24; wordmark→tagline 12; block vertically centred slightly above centre (~45 %) |
| **Interactive** | None |
| **States/edge** | Min display 600 ms, max 1.2 s (`motion.splash`) or until session check done; if offline → continue (cached session) ; failure → onboarding/sign-in |
| **A11y** | Decorative waves `aria-hidden`; announce "EVRRY" once; honour reduced-motion (no wave animation) |
| **Impl notes** | Android: SplashScreen API (icon = symbol, bg white); iOS: LaunchScreen with static symbol; Web: skip or ≤ 300 ms. Transition → onboarding (first run), else Home. |

## Screen 2 — Onboarding
| | |
|---|---|
| **Purpose** | Explain value & route to sign-in/sign-up |
| **Layout** 👁 | White bg; top: headline *One app / for everything / you do.* (middle line blue); description *Chat, Pay, Shop, Travel, Services and more.*; centre: abstract blue wave art + 3 page dots; bottom: full-width **Get Started** and *Already have an account? **Sign In*** |
| **Components** | Headline (`display`), Body (`body`, `text.secondary`), Art, PageDots (8 px, active `brand.primary`), PrimaryButton, TextLink |
| **Tokens** | `text.primary`, `brand.primary`, `text.secondary`, `gradient.waves`, `action.primary` |
| **Spacing** 🧭 | 20 side; headline top at safe-area + 48; CTA bottom = safe-area + 24; link 16 below CTA |
| **Interactive** | Get Started → phone-number + OTP sign-up (evrry auth); Sign In → sign-in; swipe between pages; **Skip** top-right 🧭 |
| **States** | OTP/network errors surface in next screen; button loading while checking session |
| **A11y** | Headline is a heading; pages reachable by buttons not only swipe; dots exposed as "Page 1 of 3"; CTA 52 px |
| **Notes** | Replace "Pay" in copy with evrry features before launch (copy decision); ⚠ reference copy lists *Pay*. |

## Screen 3 — Home
| | |
|---|---|
| **Purpose** | Hub: search, jump to services, promos, recent activity |
| **Layout** 👁 | Top: compact wordmark (left) + profile avatar (right) → universal search field → 5×2 shortcut grid → promo card (gradient, arrow button) → **Recent** (+ "See All") list → bottom nav |
| **Components** | TopBar, Avatar 40, SearchField, ServiceTile ×10, PromoBanner, SectionHeader, ListRow ×n, BottomNav |
| **Tokens** | `background.main`/`subtle`, `surface.raised`, `border.default`, `gradient.promoCard`, `text.*` |
| **Spacing** 🧭 | Section gap 24; grid 5 cols × 12 gap (≥ 360 px); < 360 → 4 cols; promo height ≈ 128 |
| **Interactive** | Search → full-screen search with recents & voice (AI concierge entry 🧭); tile → service; promo → deep link; avatar → Profile; row → detail |
| **States** | Loading: skeleton for promo + rows; empty Recent: friendly empty state; offline: banner "You're offline" + cached data; long names ellipsis (1 line) |
| **A11y** | Tiles: `button` with label; grid order = visual order; promo text readable ≥ 4.5 (use ≥ 18 px semibold on gradient); avatar label "Profile" |
| **Notes** | Dark preview exists in reference ⚠ no spec; ship light first. Recent = orders/chats/bookings, **not** wallet transactions. |

## Screen 4 — Chat
| | |
|---|---|
| **Purpose** | 1:1 messaging, order/ride coordination |
| **Layout** 👁 | Top: back, avatar, name + "Online", call icon (right); body: received bubble(s), sent bubble, **location preview card**, timestamps; bottom: composer *Type a message…*, attachment, blue circular send |
| **Components** | TopBar(chat), MessageBubble, TimestampLabel, LocationCard, Composer |
| **Tokens** | see Chat bubbles in catalog (⚠ sent-bubble colour), `status.success` (online dot) |
| **Spacing** 🧭 | Bubble gap 4 (same sender) / 12 (change); side inset 16; bubble padding 12×14 |
| **Interactive** | Call → in-app VoIP; long-press: reply/copy/delete; attach: camera, gallery, location, file; send; scroll-to-bottom FAB when scrolled up |
| **States** | Sending (clock icon) · sent ✓ · delivered ✓✓ · read ✓✓ blue; failed → red `!` + retry; typing indicator; E2EE banner "Messages are end-to-end encrypted" (🧭 product rule) |
| **A11y** | Each bubble labelled "You said … 10:42" / "Aarav said …"; status as text not colour only; composer min 48; live region for new messages |
| **Notes** | Partner (rider/merchant) threads show verified badge; request-gate screen for strangers uses Banner pattern. Call button also offers SIM-call fallback (product rule). |

## Screen 5 — Payments (EXCLUDED)
The reference shows balance card, Send/Receive/Scan/Add Money, transactions. **Not implemented** (no in-app wallet, see payments architecture). Replacement 🧭: the **Orders/Activity** tab = a filterable ListRow list (Orders · Bookings · Rides) with status chips and a receipt detail page. Receipts show line items, fees, voucher discount, and *payment method used* (Fonepay/eSewa/Khalti/Card/COD) as plain text. Amount formatting & status-with-icon rules from the typography/catalog docs still apply.

## Screen 6 — Shop
| | |
|---|---|
| **Purpose** | Browse & buy goods (food/grocery/retail per vertical) |
| **Layout** 👁 | Title *Shop* + filter icon; search field *Search products…*; chip row (All, Electronics, Fashion, Home); offer banner *Up to 50% Off — Top Brands*; 2-col product grid (image, name, price) |
| **Components** | TopBar, SearchField, Chips, PromoBanner, ProductCard |
| **ProductCard** 🧭 | Image 1:1 (radius `lg`, `surface.muted` placeholder), name `cardTitle` 2 lines, price `amount` + optional strikethrough `caption`, add button / quantity stepper (Blinkit-style) bottom-right |
| **Spacing** 🧭 | Grid 2 col gap 12, side 20; card padding 12 |
| **Interactive** | Chip filter; card → detail; stepper add/remove; filter sheet; cart badge on top bar |
| **States** | Out of stock (greyed + label), loading skeleton, no results empty state, error retry, price change toast |
| **A11y** | Price announced with currency; stepper buttons labelled "Add one …"; images have alt |
| **Notes** | Cart-based checkout for Shop/Food/Mart; Hotels = direct checkout (no cart). |

## Screen 7 — Travel → "Stays" (evrry adaptation)
| | |
|---|---|
| **Purpose** | Reference: flight search. evrry: **Hotel/Stay search** (+ Rides entry) |
| **Layout** 👁 | Back + title; segmented tabs (Flights/Hotels/Trains/Bus, "Flights" selected); stacked form (From, To, Date, Passengers); full-width **Search** button; **Popular Destinations** cards (Goa, Bali, Dubai) |
| **evrry mapping** 🧭 | Tabs: **Stays · Rides · Rooms · Rentals**; Stays form: *Where* (palika/city), *Check-in – Check-out* (date-range picker), *Guests & rooms*; destinations: Kathmandu, Pokhara, Chitwan… |
| **Components** | TopBar, SegmentedTabs, FormField ×3, PrimaryButton, DestinationCard |
| **DestinationCard** | 3 across/horizontal scroll; image 4:5, radius `xl`, name overlay on bottom gradient scrim (white text ≥ 4.5) |
| **States** | Button disabled until required fields valid; date validation errors inline; no-results state; booking CTA loading → direct to payment (no cart) |
| **A11y** | Tabs `role=tablist`; date picker keyboard accessible; field errors announced |

## Screen 8 — Services
| | |
|---|---|
| **Purpose** | Grid of service categories |
| **Layout** 👁 | Title *Services* (+ filter/grid icon); 3-col grid of tiles with icon + label: Bills, Recharge, DTH, Electricity, Gas, Water, Insurance, Health, Education |
| **evrry mapping** 🧭 | Food, Mart, Rides, Stays, Rooms, Rentals, Vouchers, Referrals, Help (bill-pay items are **not** in scope) |
| **Dimensions** | Tile = ServiceTile (56 px icon container) in a 3-col grid, gap 12 (16 on ≥ 430), label centred `navLabel`, max 2 lines |
| **States** | Pressed `primarySoft`; selected (if filter use) 2 px blue; "Coming soon" tiles `text.disabled` + badge |
| **A11y** | Tile = button with label; grid reading order row-wise; focus ring visible on keyboard |

## Screen 9 — Profile & More
| | |
|---|---|
| **Purpose** | Account, preferences, help |
| **Layout** 👁 | Header: avatar 56, name, phone **(masked in UI per privacy rule)**; grouped menu: My Profile, Payment Methods, Security, Notifications, Help & Support, About EVRRY; chevrons |
| **evrry additions** 🧭 | `@handle` + **My QR** button, Vouchers & Referrals, Leagues/Stamp card, Privacy (find-by-phone toggle), Language; "Payment Methods" = saved cards/links only (no balance) |
| **Components** | ProfileHeader, MenuRow ×n (56 px), grouped card, Toggle (52×32) |
| **Spacing** | Header padding 20; group card radius `xl`; row padding 16 |
| **States** | Unverified badge, logged-out → Sign-in CTA, update-available badge on About |
| **A11y** | Each row a `button` with label; toggles announce state; sign-out confirm dialog with destructive text `errorText` |

---

## Cross-screen requirements
- Contrast ≥ 4.5:1 normal text, 3:1 large text & UI boundaries; fix via text-safe tokens, not by altering brand colours.
- Targets ≥ 48; text ≥ 12; support 200 % text scaling; respect reduced-motion.
- Status never by colour alone; errors are specific and actionable.
- Focus order = reading order; custom focus ring `border.focus`.
- Mock data in the reference is illustrative; NPR + Nepal-specific names/places replace INR/India examples.
