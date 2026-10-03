# EVRRY — UI Implementation Guide

Applies the system in [`UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md) to the repo. **Nothing here changes architecture or unrelated logic.**

## 1. Current state (inspected)

| Area | Today |
|---|---|
| `prototype/Phone/` (Next.js 16, Tailwind) | Warm **saffron/ink** palette in `tailwind.config.ts` (`ink #1a1508`, `paper #fffdf6`, `accent #f5c518`, `accentDark`, `accentSoft`) + `globals.css`; tokens used as class names like `text-ink`, `bg-accent`, `bg-accentSoft` |
| `apps/consumer/*`, `apps/partner/*`, `apps/web/*` | README blueprints only (no code yet) |
| Fonts | No Inter bundled yet |
| Brand assets | `assets/App identity.jpg` only |

The EVRRY direction (white + navy + blue) **has been applied to the prototype** (tokens in `tailwind.config.ts`, Inter via `@fontsource-variable/inter`). Legacy saffron names were migrated: `accent`→`brand`, `accentDark`→`brand`, `accentSoft`→`brandSoft`; `ink`/`paper` keep their names with new values. Solid blue fills use `text-white`. Tier gradients, restaurant/hotel card gradients and the map placeholder remain content colours.

## 2. Single source of truth
[`UI_COLOR_TOKENS.json`](UI_COLOR_TOKENS.json) is canonical. Generate platform files from it (e.g. Style Dictionary) — don't hand-copy hex.

```
UI_COLOR_TOKENS.json
 ├─ web:      tailwind theme + CSS variables (apps/web, prototype)
 ├─ android:  Color.kt / Theme.kt (Material 3 ColorScheme + custom EvrryColors)
 └─ ios:      Assets.xcassets colorsets + Color+Evrry.swift
```

## 3. Web / Next.js (Tailwind)

`globals.css`
```css
:root {
  --color-primary: #005EFF;
  --color-secondary: #2F82F6;
  --color-accent-light: #93C5FD;
  --color-text: #0B172A;
  --color-text-muted: #64758B;
  --color-bg: #FFFFFF;
  --color-bg-subtle: #F8FAFC;      /* provisional */
  --color-surface-muted: #E2E8F0;  /* provisional */
  --color-border: #CBD5E1;         /* provisional */
  --color-success: #10B981;        /* provisional */
  --color-error: #EF4444;          /* provisional */
  --color-success-text: #047857;
  --color-error-text: #B91C1C;
}
```
`tailwind.config.ts` (semantic names, not raw colors)
```ts
colors: {
  brand: { DEFAULT: "var(--color-primary)", secondary: "var(--color-secondary)", light: "var(--color-accent-light)" },
  ink: "var(--color-text)",           // keep class name `ink` to ease migration
  muted: "var(--color-text-muted)",
  paper: "var(--color-bg)",
  subtle: "var(--color-bg-subtle)",
  line: "var(--color-border)",
  success: "var(--color-success)", danger: "var(--color-error)",
},
fontFamily: { sans: ["Inter", "system-ui", "sans-serif"] },
borderRadius: { lg: "16px", xl: "20px", xl2: "24px" },
```
Fonts: `next/font/google` → `Inter({ subsets:["latin"], variable:"--font-inter", weight:["300","400","500","600","700"] })` (self-hosted at build, no runtime request).

**Migration map (applied)**: see above; remaining items: dark-mode screens (voice/call overlays use provisional navy), wallet UI still present in prototype (scheduled for removal).

## 4. Android (Compose)
- Define `object EvrryColors` + map to Material 3 `lightColorScheme(primary=…, onPrimary=White, secondary=…, surface=…, outline=…, error=…)`.
- Type: bundle Inter variable in `res/font`, define `Typography` from the scale table.
- Shapes: `Shapes(small=8, medium=12, large=16, extraLarge=24)`.
- Icons: Material Symbols Outlined (weight 400); never mix with filled sets except selected nav.
- Adaptive icon: foreground/background/monochrome per asset checklist; `<monochrome>` in `ic_launcher.xml`.
- Splash: `androidx.core:core-splashscreen`.

## 5. iOS (SwiftUI)
- Colour assets with Light (+ optional Dark) appearance; `Color("Primary")`.
- `Font.custom("Inter", size:, relativeTo:)` so Dynamic Type works.
- SF Symbols (regular, outline), `.symbolRenderingMode(.monochrome)`.
- App icon: single 1024 asset (+ dark/tinted variants iOS 18).

## 6. Tokens → code checklist
- [ ] Generate web CSS vars, Android `Color.kt`, iOS colorsets from JSON
- [ ] Replace raw hex in components with tokens (grep `#[0-9a-fA-F]{3,8}` must return only token files and content gradients)
- [ ] Add text-safe status tokens; forbid `status.success/error` as text colour
- [ ] Contrast unit/UI checks (axe on web, Accessibility Scanner on Android, Xcode Accessibility Inspector)
- [ ] Reduced-motion & 200 % text-scale pass on every screen
- [ ] Verify provisional values with designer → remove `provisional` flags

## 7. Open items before build
1. Replace *Pay* tab with **Orders/Activity** (sign-off).
2. Confirm row-2 palette values and sent-bubble style.
3. Dark mode: decide ship/no-ship.
4. Provide vector assets (wordmark outlines, symbol, icon layers) — see checklist in the design system §1.2.
5. Decide currency glyph (`रू` vs `NPR`).
