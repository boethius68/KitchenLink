# KitchenLink Gast-Web

Sandbox-Fundament für das Gast-Web (KL-WEB-001). Grundlage sind die vom
Nutzer am 17. Juli 2026 freigegebenen Entscheidungen
(`docs/collaboration/DECISIONS.md`, Abschnitt „Guest Web") und
`docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md`:

- **Next.js App Router (TypeScript)**, hosting-neutral gehalten.
- **Vercel** ist das Sandbox-Deployment-Ziel; der Vercel-vs.-Cloudflare-PoC
  ist ein verbindliches Gate vor jeder Produktionsaktivierung.
- **Pfadbasierte Venue-Routen** (`/<venue>/menu`) in der Sandbox.
- **Supabase Anonymous Sign-in** ist für die spätere Bestellgrenze gesetzt;
  in diesem Fundament gibt es noch keine Supabase-Anbindung und keine
  Bestellübermittlung.

## Stand dieses Fundaments

- Statisch generierte Menüroute (`/[venueSlug]/menu`) aus lokalen
  Sandbox-Venue-Daten (`src/lib/venue-data.ts`, bewusste Naht für den
  späteren Supabase-Pfad).
- Mobile Gastkarte mit acht Gerichten, venue-geführtem Kopf
  (Traube-Fallback), traubenbasierter Mengensteuerung (≥ 44 px) und genau
  einer fixierten Zitronen-Bestellaktion.
- Design-Tokens aus `docs/design/DESIGN_SYSTEM.md` als CSS-Variablen
  (`src/styles/tokens.css`) mit identischen semantischen Namen wie in
  SwiftUI; `src/lib/design-tokens.ts` + Vitest halten beide konsistent.
- Sandbox-Banner auf jeder Seite; keine Zahlung, keine echte Bestellung.
- Schrift: System-Fallbacks. Bricolage Grotesque / Source Sans 3 folgen
  erst nach Lizenz-/Bundle-Prüfung als lokale Assets (keine
  Google-Fonts-Laufzeitabhängigkeit).

## Kommandos

```bash
npm run dev        # Dev-Server
npm run build      # Produktions-Build (SSG)
npm run lint       # ESLint
npm run typecheck  # tsc --noEmit
npm test           # Vitest (Cart-Logik, Fixture-Invarianten, Token-Abgleich)
```

## Bewusst noch nicht enthalten

- Autoritative Bestellgrenze (Edge Function oder RPC, ADR-001 §6) und
  jede Form der Bestellübermittlung.
- Supabase-Client, generierte Typen, Auth.
- PWA-/Offline-Shell (eigene spätere Stufe, ADR-001 §5).
- Venue-eigene Logos/Bilder; der Kopf nutzt den Traube-Fallback.
