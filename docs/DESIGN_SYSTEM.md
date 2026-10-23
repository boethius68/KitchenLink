# KitchenLink — Design System & Brand Guidelines ("Tactile Hospitality Tech")

KitchenLink bridges two worlds: the warm, unhurried atmosphere of European gastronomy and the uncompromising technical reliability of an offline-resilient native POS system.

## 1. Core Design Principles

1. **Quiet UI in the Dining Room (`guest-web/`):** When guests scan a table QR code, the interface must feel like high-grade natural paper. Dish titles and culinary descriptions take center stage; EU allergens, additives, and controls remain calm, inline, and unobtrusive.
2. **High-Contrast Precision in Service (`kitchenlink/` & B2B):** Staff interfaces and B2B showcases use deep Espresso dark modes, strict tabular numerals, and unmistakable semantic status signals (Bonjour LAN Relay vs. Cloud Sync).
3. **No SaaS Clichés:** Avoid cold corporate blues and generic tech gradients. Use tactile colors inspired by stoneware, linen, espresso, and terracotta.

---

## 2. Color Tokens

| Token | Name | Hex | HSL | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `kl-canvas` | **Warm Alabaster** | `#FAF7F2` | `38 33% 96%` | Default background for `guest-web` menus |
| `kl-surface` | **Pure Linen** | `#FFFFFF` | `0 0% 100%` | Elevated cards, sheets, modals |
| `kl-subtle` | **Stone Wash** | `#F2ECE4` | `34 32% 92%` | Allergen badges, filter pills, secondary buttons |
| `kl-dark` | **Espresso Ink** | `#141413` | `60 3% 8%` | POS dark surfaces, B2B hero, sticky cart bar |
| `kl-charcoal` | **Charcoal Ink** | `#1C1B19` | `40 5% 11%` | Primary typography (softer than `#000`) |
| `kl-muted` | **Warm Slate** | `#6E6A63` | `38 5% 41%` | Dish descriptions, additive footnotes |
| `kl-terracotta` | **Burnt Terracotta**| `#C84B31` | `10 61% 49%` | Primary brand accent, active states, CTAs |
| `kl-sage` | **Sage Leaf** | `#3D5A45` | `137 19% 30%` | Dietary badges (Vegan/Vegetarian), DACH trust |
| `kl-emerald` | **Relay Emerald** | `#10B981` | `160 84% 39%` | Local LAN Relay active / TSE verified |
| `kl-amber` | **Amber Alert** | `#F59E0B` | `38 92% 50%` | Offline queue / Sync pending / Shift warnings |
| `kl-border` | **Warm Rule** | `#E6E0D6` | `38 24% 87%` | 1px hairlines and menu section dividers |

---

## 3. Typography

* **Editorial / Menu Headings (`font-serif`):** `Newsreader` (Google Fonts)
  * Used for venue names, menu categories (*"Vorspeisen & Handwerk"*), and B2B hero statements.
* **UI & Dish Copy (`font-sans`):** `Plus Jakarta Sans` (Google Fonts)
  * Used for dish titles (`font-semibold`), descriptions, buttons, and navigation.
* **Prices, Allergens & Fiscal Data (`font-mono`):** `JetBrains Mono` (Google Fonts)
  * Always enforce `font-variant-numeric: tabular-nums`. Used for prices (`12,50 €`), table badges (`Tisch 12`), EU allergen codes (`A1 · Weizen`), and TSE/DSFinV-K metadata.

---

## 4. Component Rules (`guest-web`)

* **Allergen & Additive Badges:** Never use loud warning icons. Render inline below the dish description using `bg-kl-subtle text-kl-muted font-mono text-[10px] px-1.5 py-0.5 rounded`.
* **Price Alignment:** Prices are right-aligned in `font-mono text-sm font-medium text-kl-charcoal` with a subtle `+` action button (`bg-kl-subtle hover:bg-kl-terracotta hover:text-white`) directly below.
* **Sticky Order Bar:** Anchored at the bottom in `bg-kl-dark text-kl-canvas rounded-xl shadow-md` with a `bg-kl-terracotta` item counter badge.

---

## 5. Native SwiftUI Implementation (`kitchenlink/`)

The native iOS/iPadOS application mirrors the design system via centralized tokens in `kitchenlink/DesignSystem/KLTheme.swift` and harmonizes existing components in `KitchenLinkDesignSystemV2.swift`.

### 5.1 Color Tokens & Extensions
All 11 design tokens are exposed as native SwiftUI `Color` extensions with adaptive light/dark mode support:
* `Color.klCanvas`: `#FAF7F2` (Warm Alabaster paper surface)
* `Color.klSurface`: `#FFFFFF` / `#1C1B19` (Card and modal background)
* `Color.klSubtle`: `#F2ECE4` / `#262523` (Pills, inputs, unselected chips)
* `Color.klDark`: `#141413` (Espresso Ink for POS, KDS & dark operational panels)
* `Color.klCharcoal`: `#1C1B19` / `#FAF7F2` (Primary high-contrast text)
* `Color.klMuted`: `#6E6A63` / `#A8A39B` (Secondary text, metadata, footnotes)
* `Color.klTerracotta`: `#C84B31` (Burnt Terracotta primary action, occupied table, fire course)
* `Color.klSage`: `#3D5A45` / `#5E8468` (KassenSichV TSE compliance & cashbook badges)
* `Color.klEmerald`: `#10B981` (Bonjour LAN Relay active / free table status)
* `Color.klAmber`: `#F59E0B` (Offline queue / reserved table status)
* `Color.klBorder`: `#E6E0D6` / `#2E2D2A` (1px hairlines and cell dividers)

### 5.2 System Typography & Tabular Numerals
SwiftUI leverages Apple's San Francisco / New York typographic system to match the web pairing without bundle bloat:
* **Editorial Titles:** `KLTheme.Typography.editorialTitle(...)` uses `.system(..., design: .serif)`
* **Operational Text & Dishes:** `KLTheme.Typography.dishTitle(...)` and `.operational(...)` use `.system(..., design: .default)`
* **Tabular Numerals & Code:** `KLTheme.Typography.tabularMono(...)` and `.tabularPrice(...)` enforce `.monospacedDigit()` for all currency amounts, order counters, PIN digits, and cryptographic signatures.

### 5.3 Button Styles & View Modifiers
* `KLTerracottaButtonStyle`: Primary high-emphasis CTA (`#C84B31` background with white text).
* `KLDarkButtonStyle`: Dark operational CTA for bump bars and service controls.
* `KLSecondaryButtonStyle`: Subtle bordered action with `.klSubtle` fill.
* `.klCardStyle()` & `.klBadgeStyle(...)`: Standardized card elevation and status pill styling.
