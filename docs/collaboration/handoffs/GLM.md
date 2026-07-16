# Handoff — GLM (KL-WEB-001A Gast-Web-Stack-ADR)

**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A — Gast-Web-Stack und Hosting-ADR
**Branch:** `glm/guest-web-architecture`
**Worktree:** `/Users/test/Developments/kitchenlink-glm-web`
**Status:** ADR-001 als „Proposed" geliefert; kein Produktcode geändert

## Was in dieser Session erledigt wurde

1. Verbindliche Kontextdokumente gelesen: `AGENTS.md`, `CURRENT.md`,
   `DECISIONS.md`, `PRODUCT_BLUEPRINT.md` (insb. §3.1, §18.2, §18.3),
   `DESIGN_SYSTEM.md` (insb. §9 Gast-Web, §11 Implementierungsgrenze),
   `WORK_QUEUE.md` (KL-WEB-001 wartet auf Stack-Entscheidung) und alle
   aktuellen Handoffs.
2. Primärquellen-Recherche zu neun Themenbereichen mit **33 Quellen**:
   Next.js/React/PWA, Astro, SvelteKit, Hosting (Vercel vs. Cloudflare Pages),
   Supabase (RLS, anonyme Bestellung, TypeScript-Typen, EU-Region),
   PWA Offline (App Shell vs. Background Sync).
3. Drei Deliverables erstellt:
   - `docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md` — Architecture
     Decision Record (Status: Proposed)
   - `docs/architecture/guest-web/SOURCES.md` — Quellenregister
   - dieses Handoff

## Wichtigste Empfehlung

**Empfohlener Stack: Next.js (App Router) + Cloudflare Pages**
via `@cloudflare/next-on-pages`, mit Supabase als Backend (EU-Region Frankfurt).

- **Warum Next.js:** reifste Supabase-Integration (`@supabase/ssr`), hybride
  Rendering (statisches Menü + dynamischer Checkout), natürlicher Anschluss an
  den lokalen Venue-Hub später.
- **Warum Cloudflare Pages statt Vercel:** ~92 % günstiger, unbegrenzte
  Bandbreite, EU/GDPR-freundlicher, trotzdem Preview-Deployments pro Branch.
- **Alternativoption A:** Next.js + Vercel (Fallback bei Adapter-Problemen,
  gleicher Code, nur Hosting wechselt).
- **Verworfen:** Astro (Option B) — inhaltlich-seiten-zentriert; interaktiver
  Warenkorb/Checkout würde React-Inseln benötigen und damit Astros Hauptvorteil
  (minimal JS) aufheben.

## Kritische Trennung: Offline-App-Shell vs. bestätigte Bestellung

Die ADR stellt explizit klar (§7): die PWA-App-Shell (HTML/CSS/JS/Menü-Template)
darf offline gecacht werden (Service Worker), aber **keine Bestellung gilt als
„angekommen"**, bevor ein autoritativer Knoten sie bestätigt hat
(Blueprint §16.2). Die Background-Sync-API ist eine Ergänzung für Retry, keine
Bestellgarantie. Das Gast-Web muß den Bestell-Status ausschließlich aus der
Server-/Hub-Antwort ableiten.

## Offene Produktentscheidungen (dem Nutzer vorzulegen)

| # | Entscheidung | Einfluss |
|---|--------------|----------|
| D1 | Domain-Strategie (Subdomain vs. Pfad pro Venue) | DNS, SSL, QR |
| D2 | Anonyme Bestellung: reicht client-seitiger Session-Token? | RLS-Policy, GoBD |
| D3 | Custom-Domain pro Restaurant erlaubt? | Cloudflare-Setup |
| D4 | Vercel vs. Cloudflare finale Wahl (falls Adapter risikobelastet) | Kosten/GDPR |
| D5 | Offline-Shell-Tiefe (nur Shell oder auch Menüdaten) | Service-Worker-Strategie |

## Verification / Überprüfung

- Alle 33 Quellen am 2026-07-16 abgerufen und kategorisiert.
- ADR gegen die verbindlichen Quellen abgeglichen:
  - Blueprint §3.1 (Gast-Web-Anforderungen) — abgedeckt.
  - Blueprint §18.2 (TypeScript-Verträge, generierte Typen) — via
    `supabase gen types` erfüllt [S22][S24].
  - Blueprint §18.3 (Supabase gesetzt, getrennte Projekte) — reflektiert.
  - Blueprint §16.2 (Bestell-ACK nur nach autoritativem Commit) — in §7
    explizit getrennt.
  - DESIGN_SYSTEM.md §9 (Gast-Web venue-geführt) und §11 (gleiche Token-Namen,
    keine externen Fonts) — in Ordnerstruktur und §12 berücksichtigt.
- Status der ADR bleibt ausdrücklich „Proposed"; keine Aufnahme in DECISIONS.md.
- Workfloworktree von der Venue-Hub-Arbeit getrennt (eigener Branch
  `glm/guest-web-architecture`, eigene Dateien).

## Schreibbereich & Kollisionsfreiheit

- Ausschließlich neue Dateien unter `docs/architecture/guest-web/` und dieses
  Handoff erstellt.
- **Kein Produktcode** verändert; keine `CURRENT.md`-, `DECISIONS.md`- oder
  `WORK_QUEUE.md`-Änderungen.
- Das GLM-Handoff wurde vom vorherigen Menu-Taxonomy-Inhalt auf den Web-ADR-
  Scope überschrieben (vorheriger Inhalt ist im Branch
  `glm/offline-venue-hub` / Venue-Hub-Discovery bzw. in der Menu-Discovery
  vollständig erhalten).
- Keine fremde uncommittierte Arbeit berührt.

## Verbleibendes Risiko

- Die ADR ist ein Entwurf („Proposed"), keine Freigabe. Der Nutzer muß den
  Stack produktsprachlich bestätigen, bevor Implementierung beginnt.
- **`@cloudflare/next-on-pages`-Adapter-Risiko:** gelegentliche
  Kompatibilitätslücken bei Edge-Runtime-Features. Frühzeitige Verifikation
  der Kernrouten (Menü, Checkout) im Prototyp nötig. Vercel bleibt Notausgang.
- **QR-Erstladung** bei Next.js ist nicht so minimal wie bei Astro; durch SSG
  und Service-Worker-Caching abmilderbar, aber meßbar zu verifizieren.
- **Background Sync ist nicht verläßlich für Bestell-ACKs** — dies ist in der
  ADR klar getrennt, muß aber in der Implementierung strikt durchgehalten
  werden (`order-ack.ts` kapselt die Logik).
- **Zwei Build-Pipelines** (iOS Xcode + Web npm) erhöhen Repository-Komplexität.
- **TypeScript-Vertragssynchronisation** erfordert Disziplin bei Schema-
  Änderungen (`supabase gen types` in CI).

## Empfohlener nächster Schritt

Nach Nutzerfreigabe des Stacks (D4 und idealerweise D1–D3) kann die
Implementierung bei Bootstrap-Schritt 1 (Projektgerüst) beginnen. Parallel
sollte ein früher Proof-of-Concept die Cloudflare-Pages-Next.js-Kompatibilität
(Menü-Route + einfache Supabase-Abfrage) verifizieren, um das Adapter-Risiko
früh zu entschärfen.
