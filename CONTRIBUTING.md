# Contributing to KitchenLink

Thank you for your interest in contributing to KitchenLink! We welcome contributions from developers, designers, and gastronomy enthusiasts who want to help build modern, resilient, smartphone-first software for restaurants, bars, and cafes.

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Project Architecture

KitchenLink is organized as a multi-tier monorepo:

- **`guest-web/`**: Next.js 14 web application for guest table-ordering via QR codes. Optimized for high-speed mobile loading, legal allergen & additive transparency, and cart state management.
- **`kitchenlink/`**: Native SwiftUI application for iPhone and iPad, providing business operations, floor plan management, kitchen displays, shift control, and manager authorization.
- **`supabase/`**: PostgreSQL database migrations, authoritative RPC functions (cart pricing, order submission), row-level security (RLS), and deterministic demo seeds.
- **`prototypes/`**: Standalone Swift packages for local event sourcing (`KitchenLinkEventLog`) and zero-cloud peer-to-peer LAN order relay (`KitchenLinkLocalGuestPOC`).
- **`docs/`**: Canonical product requirements ([`PRODUCT_BLUEPRINT.md`](docs/PRODUCT_BLUEPRINT.md)), technical decisions, and architecture deep-dives.

---

## Getting Started

### 1. Prerequisites

- **Node.js** (v18+ or v20 LTS) & **npm**
- **Xcode** 15+ (macOS, for the native iOS business app)
- **Supabase CLI** (optional, for local backend development)

### 2. Fork and Clone

```bash
git clone https://github.com/<your-username>/KitchenLink.git
cd KitchenLink
```

### 3. Running `guest-web`

```bash
cd guest-web
npm install
cp .env.example .env.local
npm run dev
```

Visit `http://localhost:3000` (or `http://localhost:3000/alte-muehle/menu` for the sample restaurant).

### 4. Running the iOS App

1. Open `kitchenlink.xcodeproj` in Xcode.
2. Select the `kitchenlink` scheme.
3. Choose an iOS Simulator (e.g., iPhone 15 Pro or iPad Air).
4. Press <kbd>Cmd</kbd> + <kbd>R</kbd> to build and run.

---

## Verification & Testing

Before submitting a pull request, ensure all tests and linters pass.

### For `guest-web`:

```bash
cd guest-web

# Type check
npm run typecheck

# Linter
npm run lint

# Automated test suite (Vitest)
npm test

# Production build test
npm run build
```

### For iOS App:

- Run tests in Xcode using <kbd>Cmd</kbd> + <kbd>U</kbd> (`kitchenlinkTests` target).

---

## Pull Request Guidelines

1. **Create a topic branch**: `git checkout -b feature/your-feature-name` or `fix/your-fix-name`.
2. **Keep PRs focused**: Small, self-contained changes are reviewed and merged much faster.
3. **Preserve Architectural Principles**:
   - **Offline resilience**: Critical operations must degrade gracefully when internet access is disrupted.
   - **Dish-first design**: Menu views prioritize dish names and ingredients over distracting imagery or buttons.
   - **Legal transparency**: All 14 EU allergens and statutory additives must remain clear, accurate, and accessible to guests.
4. **Never commit secrets**: Do not check in `.env.local`, Supabase service role keys, or production credentials.
5. **Open a Pull Request**: Submit your PR with a descriptive title and fill out the PR template.
