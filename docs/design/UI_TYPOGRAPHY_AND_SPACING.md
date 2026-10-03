# EVRRY — Typography & Spacing

Companion to [`UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md). Tokens live in [`UI_COLOR_TOKENS.json`](UI_COLOR_TOKENS.json) (`typography`, `spacing`, `layout`, `radius`).

> **Observed**: Inter family; weights Light–Bold; clear hierarchy (large display headline "One app. Every you." with blue emphasis on key words). **Decision**: all numeric sizes, line heights, spacing and radii below — the JPEG does not state them.

## 1. Typeface & weights

| Weight | Value | Typical use |
|---|---|---|
| Light | 300 | Large decorative numerals only (avoid for body — thin on low-DPI) |
| Regular | 400 | Body, descriptions |
| Medium | 500 | Labels, nav labels, chips |
| Semibold | 600 | Titles, buttons, amounts |
| Bold | 700 | Display, large balances/prices |

Fallback stack: `Inter, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif`. Bundle Inter (variable) in the app; don't depend on system install. Enable `font-variant-numeric: tabular-nums` for money.

## 2. Type scale (mobile base; sizes in px/sp/pt)

| Style | Size / Line | Weight | Letter-spacing | Use |
|---|---|---|---|---|
| display | 34 / 40 | 700 | −0.5 | Onboarding headline |
| screenTitle | 24 / 32 | 600 | −0.2 | Screen titles ("Services", "Shop") |
| sectionHeading | 18 / 24 | 600 | 0 | "Recent", "Popular Destinations" |
| cardTitle | 16 / 22 | 600 | 0 | Card/row primary text |
| body | 16 / 24 | 400 | 0 | Paragraphs, chat messages |
| bodySmall | 14 / 20 | 400 | 0 | Secondary descriptions |
| inputLabel | 14 / 20 | 500 | 0 | Field labels |
| button | 16 / 24 | 600 | 0 | Button text |
| navLabel | 12 / 16 | 500 | 0.1 | Bottom nav & tile labels (min 12) |
| caption | 12 / 16 | 400 | 0.1 | Timestamps, metadata, "See All" |
| amount | 20 / 28 | 600 | 0 | Prices, order totals (tabular) |
| amountLarge | 28 / 36 | 700 | −0.3 | Hero totals (checkout total) |

Rules: no text below **12 px**; metadata colour `text.secondary`; emphasis words in display headline use `brand.primary` (Observed on onboarding: "for everything" in blue). Support OS font scaling up to **200 %** (Android `sp`, iOS Dynamic Type); layouts must wrap/grow rather than clip.

### Currency & numbers
NPR format: `रू 1,250.00` or `NPR 1,250.00` (pick one product-wide; **Decision: `रू`** with Western digits, Nepali digits optional per locale). South-Asian grouping (`12,50,000`) for lakh/crore when locale = ne-NP. Negative/positive amounts always pair colour **and** sign/icon (never colour alone).

## 3. Spacing scale (4-pt base)

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64` → tokens `spacing.1…16`.

## 4. Layout rules

| Rule | Value | Source |
|---|---|---|
| Screen horizontal padding | 20 | Decision (reference shows generous side margins) |
| Section vertical gap | 24 | Decision |
| Card padding | 16 | Decision |
| Grid gap (shortcut tiles) | 12 | Decision |
| Icon→label gap | 8 | Observed (tight label under tile) |
| Input height | 52 | Decision |
| Button height | 52 (primary) / 44 (compact) | Decision |
| Min touch target | 48×48 dp (Android) / 44×44 pt (iOS) — use 48 | WCAG/Platform |
| Top bar | 56 + status-bar inset | Decision |
| Bottom nav | 64 + bottom safe-area inset | Decision |
| Max content width (web/tablet) | 480 centred phone column; wider layouts see §6 | Decision |

### Radii
`sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · full 9999` — tiles `lg/xl`, cards `xl`, inputs `lg`, primary button `lg`, chips `full`, bottom sheet top corners `xxl`, avatars `full`, app-icon tile (visual) ≈ 22 % of side.

### Borders
Hairline **1 px** `border.default` on cards/tiles/dividers; **2 px** `brand.primary` for focus ring (offset 2).

### Elevation
Cards: none or `shadow.card`. Floating layers: `shadow.raised`/`shadow.sheet`. Avoid >1 shadow level on a screen.

### Safe areas & scrolling
- Respect status-bar, notch/cutout and gesture-bar insets; pad content, not backgrounds (backgrounds bleed edge-to-edge).
- **Sticky**: top bar (with search where applicable) and bottom nav; primary CTA on form screens is sticky above the keyboard/nav.
- Content scrolls under translucent top bar only if contrast stays ≥ 4.5:1; otherwise opaque.
- Keyboard: view resizes (`adjustResize` / SwiftUI keyboard safe area); focused field scrolls into view with 16 px margin; composer sticks to keyboard top.

## 5. Responsive behaviour (no project breakpoints exist; these are Decisions for native, mapped to dp/pt)

| Class | Width | Behaviour |
|---|---|---|
| Small phone | < 360 | 4-col tile grid → keep 4 but reduce label to 12 px w/ 2-line wrap; side padding 16; product grid 2-col |
| Standard | 360–430 | Reference layout (5×2 shortcut grid → use 5 cols only if tile ≥ 56; else 4 cols) |
| Large phone | 430–600 | Same layout, tile & card widths flex; max column 480 |
| Tablet / web desktop | ≥ 600 | Centre 480 column for flows (chat list + thread may split 2-pane ≥ 840); shop/hotel grids 3–4 cols; bottom nav → side rail ≥ 840 |

Don't scale text with viewport width; scale only with the user's OS text-size setting. Grid changes = column count changes, never stretched tiles.

## 6. Provisional vs. decided summary

Every numeric value in this file is a **Decision** except: Inter family/weights, relative hierarchy, icon→label tightness and rounded shapes. Lock numbers after one design review in Figma and update the JSON once.
