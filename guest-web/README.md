# KitchenLink Gast-Web

Das Gast-Web ist eine responsive Next.js-Sandbox fuer anonyme
Restaurantbestellungen. Der aktuelle Stand laeuft unter
<https://kitchenlink.luneq.eu/alte-muehle/menu> auf Hostinger PaaS und verwendet
die Supabase-Sandbox in EU-Frankfurt.

## Implementierter Stand

- Next.js App Router mit TypeScript und pfadbasierten Venue-Routen
  (`/[venueSlug]/menu`).
- Menue-Leseweg aus Supabase, als ISR mit 60 Sekunden Revalidierung. Die lokale
  Fixture bleibt als bewusster Build-/Ausfall-Fallback erhalten.
- Supabase Anonymous Sign-in fuer Gastidentitaeten.
- Autoritative Sandbox-Bestellgrenze ueber
  `guest_web_submit_order`: Der Server prueft Verfuegbarkeit und Preise und
  liefert erst danach das ACK.
- Idempotente Bestellungen inklusive sauberer Replay-/Konfliktbehandlung.
- Sandbox-Banner, keine Live-Zahlung und keine fiskalische Wirkung.
- Semantische Design-Tokens aus `docs/design/DESIGN_SYSTEM.md`, ohne externe
  Font-Abhaengigkeit zur Laufzeit.
- Git-basiertes Auto-Deployment aus `main`; der Code bleibt hosting-neutral.

## Lokal starten

```bash
npm install
cp .env.example .env.local
npm run dev
```

In `.env.local` muessen diese Werte der Supabase-Sandbox stehen:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://<projekt-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-public-key>
```

Ohne gueltige Konfiguration rendert die bekannte Demo-Venue aus der lokalen
Fixture; eine Bestellung scheitert dann kontrolliert und erzeugt kein falsches
ACK.

## Pruefkommandos

```bash
npm run typecheck
npm run lint
npm test
npm run build
npm run test:integration
```

Die Integrationstests laufen nur mit `KL_INTEGRATION=1` und gesetzten
Supabase-Variablen gegen die echte Sandbox-Instanz. Ohne Opt-in werden sie
sauber uebersprungen.

## Betrieb und Grenzen

Der vollstaendige Setup-, Migrations-, Deployment- und Smoke-Test-Ablauf steht
in
[`docs/architecture/guest-web/SANDBOX_SETUP.md`](../docs/architecture/guest-web/SANDBOX_SETUP.md).

Bewusst noch offen sind eine produktionsreife Hosting-Entscheidung, die
PWA-/Offline-Stufe, eine Retention-Regel fuer verwaiste anonyme Nutzer,
venue-eigene Domains sowie echte Zahlungen und Fiskalisierung. Die aktuelle
oeffentliche URL bleibt bis zu einer ausdruecklichen Produktionsfreigabe eine
Sandbox.
