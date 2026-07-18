# KitchenLink

KitchenLink ist ein smartphone-first Betriebssystem fuer Restaurants, Bars und
Cafes. Das Repository enthaelt derzeit eine native SwiftUI-Sandbox fuer den
Betrieb, ein oeffentlich erreichbares Gast-Web und die gemeinsame
Supabase-Grundlage.

## Aktueller Stand

- Gast-Web-Sandbox: <https://kitchenlink.luneq.eu/alte-muehle/menu>
- Hosting: Hostinger PaaS, automatischer Build aus `main`
- Backend: Supabase-Sandbox in EU-Frankfurt
- Business-App: SwiftUI-Prototyp fuer iPhone und iPad

Die veroeffentlichte Website ist weiterhin eine **Sandbox**. Bestellungen
werden in der Sandbox-Datenbank erfasst, bewegen aber kein echtes Geld und sind
keine produktiven oder fiskalisch gueltigen Vorgaenge.

## Repository

- `guest-web/` — Next.js-Gast-Web mit Supabase-Menue, ISR und autoritativer
  Sandbox-Bestellgrenze
- `kitchenlink/` — SwiftUI-Business-App und lokale Demo-/Simulationspfade
- `supabase/` — additive Migrationen und lokale CLI-Konfiguration
- `prototypes/` — isolierte technische Prototypen, nicht produktiv aktiviert
- `docs/` — Produkt-, Design-, Architektur- und Kollaborationsdokumentation

## Gast-Web lokal starten

```bash
cd guest-web
npm install
cp .env.example .env.local
npm run dev
```

Die benoetigten Supabase-Variablen und der komplette Sandbox-Aufbau sind in
[`docs/architecture/guest-web/SANDBOX_SETUP.md`](docs/architecture/guest-web/SANDBOX_SETUP.md)
beschrieben.

```bash
cd guest-web
npm run typecheck
npm run lint
npm test
npm run build
```

## Verbindliche Projektquellen

1. [`docs/collaboration/DECISIONS.md`](docs/collaboration/DECISIONS.md) — vom
   Nutzer freigegebene Entscheidungen
2. [`docs/PRODUCT_BLUEPRINT.md`](docs/PRODUCT_BLUEPRINT.md) — kanonischer
   Produktumfang
3. [`docs/collaboration/CURRENT.md`](docs/collaboration/CURRENT.md) — aktuell
   integrierter Stand und offene Entscheidungen

Aktive Entwicklungsarbeit erfolgt vorerst durch Codex und Claude Code nach
[`AGENTS.md`](AGENTS.md) und
[`docs/collaboration/PEER_WORKFLOW.md`](docs/collaboration/PEER_WORKFLOW.md).
Secrets, lokale Zugangsdaten und private Supabase-Schluessel gehoeren niemals
ins Repository.
