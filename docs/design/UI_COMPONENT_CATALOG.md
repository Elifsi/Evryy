# EVRRY — Component Catalog

Tokens: [`UI_COLOR_TOKENS.json`](UI_COLOR_TOKENS.json). Scale/spacing: [`UI_TYPOGRAPHY_AND_SPACING.md`](UI_TYPOGRAPHY_AND_SPACING.md). Dimensions are **Decisions** unless marked *(Observed)*. States for every interactive component: default · pressed · focused · selected · disabled · loading · success · error (where relevant).

## Buttons
| | Primary | Secondary | Text/Link |
|---|---|---|---|
| Visual | `action.primary` bg, white `button` text, radius `lg`, height 52, full-width in forms *(Observed: full-width blue "Get Started" / "Search Flights")* | `surface.primarySoft` bg, `brand.primary` text | `brand.primary`, 600, no bg *(Observed: "Sign In", "See All")* |
| Pressed | `action.primaryPressed`, scale .98 | `secondaryPressed` | underline/opacity .7 |
| Focused | 2 px `border.focus` ring, offset 2 | same | same |
| Disabled | `primaryDisabled` bg/fg, no ripple | 40 % opacity | `text.disabled` |
| Loading | label replaced by 20 px spinner, width locked, taps ignored | same | — |
| Success/Error | brief check/ ! icon then revert; error also shows inline message | — | — |

## Inputs & search
Height 52, radius `lg`, bg white, 1 px `border.strong` (3:1), 16 px text, label above (`inputLabel`), leading 20 px icon *(Observed: search field with magnifier + placeholder "Search anything…")*. Focus: 2 px `brand.primary`. Error: 1.5 px `errorText` border + icon + message below in `errorText` (never colour only). Disabled: `surface.muted` bg. **Universal search** field is tappable (opens search screen) on Home.

## Service shortcut tile *(Observed)*
56 px square tile, radius `xl`, bg white/`surface.raised`, 1 px `border.default`, outline icon 24–28 px `brand.primary`; label `navLabel` `text.primary` 8 px below, centred, max 2 lines. Pressed: `surface.primarySoft`. Selected (Services grid): 2 px `brand.primary` border + `primarySoft`. Min target = tile + label (≥ 48 px).

## Bottom navigation *(Observed: 5 items, icon + label, selected = blue)*
64 px + inset, white, 1 px top border `border.default`, `zIndex.bottomNav`. Icon 24, label 12 `navLabel`. Selected: `brand.primary` filled icon + semibold label; unselected: `text.secondary` outline. Badge: 8 px `status.error` dot / count pill (≤ 99+). No horizontal scrolling; no more than 5 items.

## Tabs & category chips *(Observed: Flights/Hotels/Trains/Bus; All/Electronics/Fashion/Home)*
Chip height 36, radius `full`, `navLabel`/`bodySmall` 500. Unselected: `surface.default` + `text.primary`; selected: `brand.primary` bg + white (or `primarySoft` + blue text). Horizontal scroll, 8 px gap, 20 px leading inset, snap not required.

## Cards & containers
White (`surface.raised`) on `background.subtle`, radius `xl`, padding 16, 1 px `border.default`, `shadow.card` optional. Tappable cards: pressed `surface.muted`, full-card hit area, `role=button/link`.

## Promotional banner *(Observed: blue gradient card "Everything you need. One place." with circular arrow button; "Up to 50% Off — Top Brands")*
`promoCard` gradient, radius `xl`, padding 20, white `sectionHeading`/`display`-lite text, circular 40 px white button with blue arrow at end. White text on the gradient's lightest stop is 3.72:1 → keep headline ≥ 18 px semibold. Decorative wave art `accentLight` at ≤ 40 % opacity behind, text never over busiest region.

## List / transaction-style row (use for Recent, Orders, Activity)
Height ≥ 64, padding 12×16; 40–44 px circular leading avatar/brand logo; title `cardTitle`, subtitle `bodySmall` `text.secondary`, trailing caption (time) `caption` and optional trailing amount `amount`. Divider 1 px `border.default` inset to text. Status = icon + word (e.g. ✔ "Delivered") — colour is additive. Amount sign always explicit.
> Visual pattern only. Do **not** implement wallet credits/debits.

## Avatar
Circular; 32 (list-compact) / 40 (rows, chat header) / 56 (profile) / 80 (profile header); initials fallback on `primarySoft` with `brand.primary` text; online dot 10 px `status.success` + 2 px white ring (also expose "online" to a11y).

## Chat bubbles *(Observed)*
Received: `surface.default`/white + 1 px border, left, radius 16 (bottom-left 4). Sent: `brand.primary` bg, white text, right, radius 16 (bottom-right 4) *(reference sent bubbles appear light-blue tint — see conflict below)*. Max width 78 %. Timestamp `caption`. Location preview card: map thumbnail 16:9, radius 12, title + address, tap → map. Composer: pill input (height 48) + attachment icon + circular 40 px blue send button; send disabled when empty.
> **Reference ambiguity**: sent bubble looks light-blue (`#DBEAFE`-ish) with dark text, not solid blue. **Provisional**: use `action.secondaryPressed` (`#DBEAFE`) bg + `text.primary`; solid-blue variant is the fallback. Decide with designer.

## Bottom sheet & dialog
Sheet: white, top radius `xxl`, 4×36 drag handle, padding 20, `shadow.sheet`, scrim `overlay.scrim`, max height 90 %. Dialog: radius `xl`, width ≤ 320, title `sectionHeading`, body `body`, buttons stacked (primary then text). Focus trapped; Esc/back closes unless destructive in-flight.

## Dropdowns / menus
Radius `lg`, white, `shadow.raised`, item height 48, selected item `primarySoft` + check icon. Native pickers preferred on mobile.

## Menu row (Profile & More) *(Observed)*
Height 56, leading 20–24 px blue outline icon, label `body`, trailing chevron 16 `text.secondary`, dividers 1 px, grouped in a white card radius `xl`.

## Travel/Stays search form *(Observed: stacked fields + full-width "Search Flights")*
Stacked field rows (52) with leading icon, 12 px gap; single primary CTA. For evrry map to **Stays** (location, dates, guests) — see screen spec.

## Empty states
Centred 120 px line illustration (accentLight/blue outline), `sectionHeading` title, `bodySmall` secondary text, one primary or secondary action. Never blame the user.

## Loading
Skeleton blocks `surface.muted` (shimmer 1.2 s, disabled under reduced-motion) for lists/cards; 24 px spinner `brand.primary` for in-button/refresh. Splash progress is implicit (no bar).

## Toasts & banners
Toast: bottom, above nav, radius `lg`, `text.primary` bg `#0B172A` + white text (dark toast), 4 s auto-dismiss, optional action; icon + text for success/error. Inline banner: `primarySoft` / error-tint bg with icon, persistent until resolved. Announce via live region.

## Success & error patterns
Success: 56 px circle `status.success` fill + white check, title, subtitle, primary CTA. Error: `status.error` fill + `!`, **plain-language** message, next step, retry. Field errors inline.

## Payment-method selector (evrry-specific — not in reference)
List of radio rows (Fonepay QR · eSewa · Khalti · Card · Cash on Delivery), each = menu-row pattern with provider logo 32 px, selected = 2 px `brand.primary` border + `primarySoft`. Fonepay QR screen: white card, QR centred 240 px min, amount `amountLarge`, remark `caption`, countdown; QR blurred (overlay) when scanned. Uses only tokens above.

## Consistency rules
1. One primary button per screen section. 2. No raw hex. 3. Icons: one library, outline. 4. Radii from the scale only. 5. Status never colour-only. 6. Touch targets ≥ 48. 7. Text ≥ 12. 8. New components must be added here before use.
