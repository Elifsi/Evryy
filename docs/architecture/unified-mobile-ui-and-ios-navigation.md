# Unified Mobile UI Architecture & iOS In-App Navigation Specification
**evrry Super App Platform (Android & iOS Parity)**  
*Elifsi Technologies Private Limited*

---

## 1. Executive Directive: Complete UI Parity (1:1 Mirroring)

To eliminate redundant design work, prevent UI drift, and streamline QA testing:
- **Single Source of Truth**: The Next.js phone prototype in [`prototype/Phone/`](file:///home/rahul/codes/Evrry/prototype/Phone/) serves as the visual and functional golden master.
- **Identical Layouts**: Android (Jetpack Compose) and iOS (SwiftUI) use the exact same layouts, color tokens, card structures, typography, and spacing.
- **Zero Platform Fragmentation**: A customer or driver switching between Android and iPhone will experience an identical interface, with native fluid animations on both platforms.

---

## 2. Critical iOS In-App Navigation & Back Button Rules

Unlike Android, **iOS devices do not have a physical back button or mandatory OS-level navigation bar**. If an iOS screen lacks an in-app back control, the user becomes permanently trapped.

### Rule 1: Mandatory Top-Left In-App Back Button (`44x44 pt` Minimum Tap Target)
Every nested view, catalog category, order tracking screen, checkout step, and profile sub-page **MUST** feature a prominent in-app back button at the top-left:

```
┌─────────────────────────────────────────────────────────┐
│  [ < Back ]               Screen Title             [ 🔍 ]│ <── Top App Bar (min 56pt)
├─────────────────────────────────────────────────────────┤
│                                                         │
│                      Screen Content                     │
│                                                         │
```

- **Tap Target**: Minimum `44x44 pt` (Apple Human Interface Guidelines & Material Accessibility standard).
- **Icon**: Chevron / Arrow-Left (`chevron.backward` in SwiftUI / `Icons.AutoMirrored.Filled.ArrowBack` in Jetpack Compose).
- **Behavior**: Calls the platform navigator (`navController.popBackStack()` in Compose / `dismiss()` or `presentationMode.wrappedValue.dismiss()` in SwiftUI).

### Rule 2: Modal & Bottom Sheet Dismissal (Top-Right `✕` & Drag Handle)
All bottom sheets (cart modifiers, ride biddings, address pickers) and full-screen dialogs must include:
1. **Top Drag Indicator**: Centered pill capsule (`w-12 h-1.5 rounded-full bg-muted`) for natural downward swipe-to-dismiss.
2. **Top-Right Close Button**: Dedicated circular `✕` icon button (`w-10 h-10 rounded-full bg-secondary/80 flex items-center justify-center`).

### Rule 3: Native Interactive Swipe-to-Go-Back
- SwiftUI `NavigationStack` and Compose gestures must keep the interactive edge swipe-to-back gesture active at all times.
- Never disable or intercept edge swipes unless drawing on an active canvas or dragging a map.

### Rule 4: Home Indicator & Safe Area Inset Protection
All sticky bottom action bars (*"Proceed to Checkout"*, *"Confirm Bid"*, *"Start Trip"*):
- Must enforce `WindowInsets.safeDrawing` (Compose) / `.safeAreaInset(edge: .bottom)` (SwiftUI).
- Never place interactive buttons flush against the bottom edge of the glass where they could conflict with the iOS Home indicator bar.

---

## 3. UI Token Parity Matrix

| Design Token | Jetpack Compose (Android) | SwiftUI (iOS) | Web / Next.js (Tailwind) |
|---|---|---|---|
| **Primary Brand** | `Color(0xFF00C853)` (Emerald / Green) | `Color(hex: "#00C853")` | `bg-emerald-600` |
| **Accent / InDrive** | `Color(0xFFFF6D00)` (Deep Amber) | `Color(hex: "#FF6D00")` | `bg-amber-500` |
| **Surface Dark** | `Color(0xFF121212)` | `Color(hex: "#121212")` | `bg-zinc-950` |
| **Card Surface** | `Color(0xFF1E1E1E)` | `Color(hex: "#1E1E1E")` | `bg-zinc-900` |
| **Text Primary** | `Color(0xFFFFFFFF)` | `Color.white` | `text-zinc-50` |
| **Text Muted** | `Color(0xFFA1A1AA)` | `Color(hex: "#A1A1AA")` | `text-zinc-400` |
| **Corner Radius** | `RoundedCornerShape(16.dp)` | `.cornerRadius(16)` | `rounded-2xl` |
| **Back Button** | `IconButton(modifier = Modifier.size(44.dp))` | `Button { dismiss() } .frame(width: 44, height: 44)` | `<button className="w-11 h-11">` |

---

## 4. Web Suite Alignment (`apps/web/`)

The web ecosystem shares the same responsive foundation:
1. **`apps/web/consumer/`**: Next.js Consumer Portal allowing users to order food, book rides, and reserve hotels directly from desktop or mobile web browsers.
2. **`apps/web/partner/`**: Next.js Partner Portal featuring the Kitchen Display System (KDS), Grocery pick-and-pack checklist, Hotel reservation desk, and thermal bill printing.
3. **`apps/web/admin/`**: Next.js Superadmin Control Center allowing Elifsi staff to configure platform fees (Rs 10), delivery radius fees, driver commission cuts (80%), and dispute resolution without touching SQL.
