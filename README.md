<p align="center">
  <img src="docs/design/codex-logo/working-v1/kitchenlink-lockup.svg" alt="KitchenLink Logo" width="420">
</p>

<p align="center">
  <strong>Smartphone-First Restaurant Operating System</strong><br>
  Native SwiftUI POS • Instant QR Table Ordering • Offline LAN Relay • Supabase Backend
</p>

<p align="center">
  <a href="https://kitchenlink.luneq.eu/alte-muehle/menu"><strong>🚀 Live Guest Sandbox Demo</strong></a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://nextjs.org/"><img src="https://img.shields.io/badge/Next.js-14-black" alt="Next.js"></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/SwiftUI-iOS%20%2F%20iPadOS-orange" alt="SwiftUI"></a>
  <a href="https://supabase.com"><img src="https://img.shields.io/badge/Backend-Supabase-green" alt="Supabase"></a>
  <a href="https://github.com/boethius68/KitchenLink/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22"><img src="https://img.shields.io/badge/Contributions-Welcome-brightgreen" alt="Contributions Welcome"></a>
</p>

---

<p align="center">
  <img src="docs/design/app-direction.png" alt="KitchenLink Preview" width="850">
</p>

---

**KitchenLink** is a modern, smartphone-first operating system designed for restaurants, bars, and cafes. It bridges the gap between guests, service staff, and the kitchen with a native iOS/iPadOS business app, instant QR-code guest ordering in the browser, and offline-resilient local order dispatching.

> 🇩🇪 **Hinweis für die DACH-Gastronomie:**  
> KitchenLink wurde gezielt für den europäischen Markt entwickelt — mit lückenloser Auszeichnung aller 14 EU-Allergene, deklarationspflichtiger Zusatzstoffe und robuster Offline-Fähigkeit bei instabilem Restaurant-WLAN.

---

## Architecture Overview

```mermaid
graph TD
    subgraph Guests
        GW["Guest Web (Next.js 14)<br/>• QR Table Ordering<br/>• Dish-First Menu<br/>• Allergen & Additive Engine"]
    end

    subgraph Service & Kitchen
        IOS["iOS / iPadOS App (SwiftUI)<br/>• Table Management & POS<br/>• Kitchen Display & Shifts<br/>• Time Tracking & Manager PIN"]
    end

    subgraph Hub & Backend
        Cloud["Supabase (EU Frankfurt)<br/>• PostgreSQL Migrations & RLS<br/>• Authoritative Order RPCs"]
        LAN["Local Hub Relay (POC)<br/>• Local LAN Multicast / P2P<br/>• Zero-Cloud Offline Fallback"]
    end

    GW -->|HTTPS / WSS| Cloud
    GW -.->|Offline LAN Fallback| LAN
    IOS -->|Sync| Cloud
    IOS <-->|Bonjour / LAN Relay| LAN
```

---

## Key Features

- 📱 **Native Business App (`kitchenlink/`)**: Built in SwiftUI for iPhone and iPad. Covers floor plans, table ordering, kitchen dispatch screens, cash closing, staff time-tracking, and manager PIN authorizations.
- 🌐 **Dish-First Guest Web (`guest-web/`)**: Next.js 14 web app for instant guest ordering via table QR codes. Features quiet inline allergen pictograms covering all 14 EU allergens and statutory food additives without visual clutter.
- ⚡ **Offline-First Resilience**: If the internet or cloud connection drops, KitchenLink can fall back to local LAN order dispatching so service never halts during rush hours.
- 🗄️ **Authoritative State & RPCs (`supabase/`)**: Strict calculation of order options, portions, deltas, and allowances on the database layer with Row Level Security (RLS).
- 📖 **Comprehensive Documentation (`docs/`)**: Extensive product blueprints, architecture records, and design audits.

---

## Repository Structure

```
├── guest-web/             # Next.js 14 guest ordering web application
├── kitchenlink/           # Native SwiftUI iOS & iPadOS application
├── kitchenlink.xcodeproj  # Xcode project configuration
├── supabase/              # PostgreSQL schema, migrations, and seeds
├── prototypes/            # Standalone Swift packages (Local Guest POC, EventLog)
├── scripts/               # Menu extraction, test runners, quality gates
└── docs/                  # Architecture, product blueprint, and decision log
```

---

## Quick Start

### 1. Guest Web (Next.js)

```bash
cd guest-web
npm install
cp .env.example .env.local
npm run dev
```

Open [http://localhost:3000/alte-muehle/menu](http://localhost:3000/alte-muehle/menu) to view the sample restaurant menu.

To run the automated verification suite:
```bash
npm run typecheck
npm run lint
npm test
npm run build
```

### 2. iOS Business App (SwiftUI)

1. Open `kitchenlink.xcodeproj` in Xcode (Xcode 15+ required).
2. Select the `kitchenlink` scheme.
3. Choose an iOS Simulator (e.g., iPhone 15 Pro or iPad).
4. Build and run (<kbd>Cmd</kbd> + <kbd>R</kbd>).
5. Run unit tests (<kbd>Cmd</kbd> + <kbd>U</kbd>).

### 3. Backend (Supabase)

Local migrations are managed via the Supabase CLI in `supabase/migrations/`. Detailed configuration instructions are documented in [`docs/architecture/guest-web/SANDBOX_SETUP.md`](docs/architecture/guest-web/SANDBOX_SETUP.md).

---

## Roadmap & Blueprints

KitchenLink is being built towards an autonomous, reliable restaurant OS. Canonical product specs, milestone goals, and design guidelines are maintained in the repository:

- [`docs/PRODUCT_BLUEPRINT.md`](docs/PRODUCT_BLUEPRINT.md) — Product scope, milestones, and requirements
- [`docs/collaboration/DECISIONS.md`](docs/collaboration/DECISIONS.md) — Architectural and design decision record
- [`docs/collaboration/CURRENT.md`](docs/collaboration/CURRENT.md) — Current integrated state and active work

---

## Contributing & Good First Issues

Contributions, issues, and feature suggestions are very welcome! If you want to contribute, check out our beginner-friendly issues:

👉 **[Browse Good First Issues](https://github.com/boethius68/KitchenLink/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)**

Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting pull requests.

---

## License

This project is open-source under the [MIT License](LICENSE).
