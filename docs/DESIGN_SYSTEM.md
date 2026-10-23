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
