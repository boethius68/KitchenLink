# KitchenLink Gast-Web

Sandbox-Fundament für das Gast-Web. Grundlage sind die vom Nutzer am
17. Juli 2026 freigegebenen Entscheidungen
(`docs/collaboration/DECISIONS.md`, Abschnitt „Guest Web") und
`docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md`:

- **Next.js App Router (TypeScript)**, hosting-neutral gehalten.
- **Vercel** ist das Sandbox-Deployment-Ziel; der Vercel-vs.-Cloudflare-PoC
  ist ein verbindliches Gate vor jeder Produktionsaktivierung.
- **Pfadbasierte Venue-Routen** (`/<venue>/menu`) in der Sandbox.
- **Supabase Anonymous Sign-in** + autoritative Bestellgrenze
  (`guest_web_submit_order`-RPC, KL-WEB-002) sind umgesetzt; Status kommt
  ausschließlich aus der Serverantwort.

## Stand dieses Fundaments

Die Komponente wurde gegen den visuellen Referenzscreen aus
`docs/design/claude-design/round-04/export/territories.html` (Abschnitt 6c,
Screen 2 "Gast-Web · 390 px · dichte Karte") abgeglichen und entlang davon
korrigiert:

- Statisch generierte Menüroute (`/[venueSlug]/menu`) aus lokalen
  Sandbox-Venue-Daten (`src/lib/venue-data.ts`, bewusste Naht für den
  späteren Supabase-Pfad).
- Mobile Gastkarte mit acht Gerichten, randlosem venue-geführtem Kopf
  (Traube-Fallback) mit "geöffnet"/"geschlossen"-Badge, umrandeten
  (`border-control`) traubenbasierten Mengensteuerungen (≥ 44 px), kleinen
  Tag-Pills ("beliebt", "vegetarisch") neben dem Namen und einer
  durchgehenden Zitronen-Bestellleiste als einziger dauerhafter
  Zitronenfläche (die gesamte Leiste ist die eine Primäraktion, nicht nur
  ein Button darin).
- Die Preiszeile bleibt bewusst als eigene, fett hervorgehobene Zeile unter
  der Beschreibung (Nutzerentscheidung; die Referenz zeigt Preis/Allergene
  inline in der Sekundärzeile).
- Kein automatischer Seitenwechsel auf Dunkel: Jeder verifizierte
  Referenzscreen zeigt das Gast-Web hell mit Traube-Kopf; nur die Küche ist
  laut Designsystem "immer Tief". Nutzer-Dunkelmodus verändert daher nicht
  die Seitenflächen, nur was ohnehin token-basiert ist.
- Design-Tokens aus `docs/design/DESIGN_SYSTEM.md` als CSS-Variablen
  (`src/styles/tokens.css`) mit identischen semantischen Namen wie in
  SwiftUI; `src/lib/design-tokens.ts` + Vitest halten beide konsistent.
- Sandbox-Banner auf jeder Seite; keine Zahlung, keine echte Bestellung.
- Schrift: System-Fallbacks. Bricolage Grotesque / Source Sans 3 folgen
  erst nach Lizenz-/Bundle-Prüfung als lokale Assets (keine
  Google-Fonts-Laufzeitabhängigkeit).
- Die Kontextzeile "Speisekarte" im Kopf ist ein Platzhalter für eine
  spätere echte Tisch-/Kanal-Session (kein QR-/Tisch-Fluss existiert noch;
  eine erfundene Tischnummer wäre irreführend gewesen).

## Kommandos

```bash
npm run dev        # Dev-Server
npm run build      # Produktions-Build (SSG)
npm run lint       # ESLint
npm run typecheck  # tsc --noEmit
npm test           # Vitest Unit (Cart-, Submit-/ACK-Logik, Fixture, Tokens)
npm run test:integration  # gegen echte Supabase-Instanz (skippt ohne Konfig)
```

## In Betrieb nehmen (Sandbox)

Die Schritt-für-Schritt-Anleitung für Supabase-Projekt (EU-Frankfurt),
Anonymous-Sign-in, Migrationen, `.env.local` und Vercel-Deployment steht in
[`docs/architecture/guest-web/SANDBOX_SETUP.md`](../docs/architecture/guest-web/SANDBOX_SETUP.md).
Ohne konfigurierte Supabase-Instanz läuft die Menüanzeige weiter über die
lokale Fixture; Bestellungen schlagen dann kontrolliert fehl (kein falsches
ACK).

## Bewusst noch nicht enthalten

- Hosting-Entscheidung D4 (Vercel vs. Cloudflare Workers) — offen, siehe
  ADR-001 §8 PoC-Matrix.
- Menü-Fetch via Supabase statt lokaler Fixture (`src/lib/venue-data.ts`).
- PWA-/Offline-Shell (eigene spätere Stufe, ADR-001 §5, Entscheidung D5).
- Venue-eigene Logos/Bilder; der Kopf nutzt den Traube-Fallback.
- Keine echten Zahlungen, keine produktive Freigabe (Blueprint §20).
