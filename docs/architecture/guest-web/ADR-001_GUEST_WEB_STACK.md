# ADR-001: KitchenLink Gast-Web-Stack und Hosting

**Status:** Proposed
**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A
**Entscheidungssteller:** Nutzer (produktsprachliche Freigabe offen)

Diese Architecture Decision Record (ADR) vergleicht drei konkrete Lösungsstapel
für das KitchenLink Gast-Web und empfiehlt einen. Sie erfindet keine
Produktentscheidungen und enthält keine Implementierung. Quellenverweise `[Sxx]`
verweisen auf [`SOURCES.md`](./SOURCES.md).

---

## 1. Kontext und Problemstellung

### 1.1 Produktauftrag (aus verbindlichen Quellen)

Das Gast-Web ist die zweite Plattform nach der iOS-/iPadOS-Business-App
(`PRODUCT_BLUEPRINT.md` §3.5). Die Anforderungen aus Blueprint und DECISIONS.md:

- Gäste bestellen **sofort im Browser, ohne App-Installation** (DECISIONS.md,
  Blueprint §3.1) — QR-Einstieg, Link, Restaurantwebsite oder Suche.
- **Anonyme Bestellung** am Tisch ist möglich (Blueprint §3.1, §13.1).
- Responsive für **iPhone, Android und Desktop** (Blueprint §3.1).
- Supabase ist als Cloud-Backend gesetzt (Blueprint §18.3); der **Betreiber
  besitzt keinen eigenen Server**.
- Frontend-Hosting, Framework und Deployment sind **offen** (WORK_QUEUE
  KL-WEB-001: „Wartet auf Stack-Entscheidung").
- Das Design-System fordert: **SwiftUI und Web verwenden dieselben semantischen
  Token-Namen** (`DESIGN_SYSTEM.md` §11); keine Runtime-Abhängigkeit von
  Google Fonts.
- Das Gast-Web ist **venue-geführt**: Restaurantname/Logo/Bild führen den Kopf,
  Traube ist der Fallback, Zitrone nur für die fixierte Bestellaktion
  (`DESIGN_SYSTEM.md` §9).
- Späterer Anschluss an den **lokalen Venue-Hub** für Offline-Bestellung
  (Blueprint §16, siehe `docs/discovery/offline-venue-hub/`).

### 1.2 Technische Problemstellung

Der Betreiber hat keinen Server. Die Gast-Web-Auslieferung muss daher über ein
verwaltetes Hosting (PaaS/Edge) erfolgen. Gleichzeitig müssen folgende
Spannungen aufgelöst werden:

| Spannung | Beschreibung |
|----------|--------------|
| **QR-Performance vs. Interaktivität** | QR-Erstladung muss schnell sein (Gast wartet am Tisch), aber Warenkorb/Checkout brauchen Interaktivität |
| **Statisch vs. dynamisch** | Menü ist weitgehend statisch (gut für SEO/Cache), Bestellung ist dynamisch (gut für App-Framework) |
| **EU-DSGVO vs. Hosting-Anbieter** | Erstmarkt Deutschland; personenbezogene Daten (anonyme Bestellung, ggf. Kundenkonto) brauchen EU-Region |
| **Offline-Shell vs. Offline-Bestellung** | UI kann offline gecacht werden; eine Bestellung darf aber erst als „angekommen" gelten, wenn ein autoritativer Knoten sie bestätigt hat (Blueprint §16.2) |
| **TypeScript-Verträge** | Blueprint §18.2 fordert gemeinsame API-Verträge und generierte Typen, keine duplizierten freien Modelle |

---

## 2. Berücksichtigte Lösungen

Drei Lösungsstapel werden verglichen. Alle setzen Supabase als Backend voraus
und verwenden TypeScript. Sie unterscheiden sich in Framework, Rendering-Strategie
und Hosting.

### Option A: Next.js (App Router) + Vercel

- **Framework:** Next.js mit React, App Router, Server Components
- **Rendering:** Hybride (SSR/SSG/ISR) — Menüseiten statisch generierbar,
  Checkout dynamisch
- **PWA:** via Serwist (next-pwa-Nachfolger) [S01][S02][S03]
- **Hosting:** Vercel (Next.js-Mutterfirma); Preview-Deployments pro Branch
- **Supabase:** `@supabase/ssr`, reifes Tutorial-Ökosystem [S10]
- **Stärken:** beste Next.js-DX auf Vercel, Preview-Deployments out-of-the-box,
  SSR für SEO, Server Actions für privilegierte Vorgänge
- **Schwächen:** Vercel EU/GDPR weniger ideal [S18]; Free-Tier 100 GB/Monat
  Bandbreite [S19]; kostenintensiv bei Skalierung [S17]

### Option B: Astro + Cloudflare Pages

- **Framework:** Astro (Insel-Architektur, partielle Hydration)
- **Rendering:** Statisch mit selektiver Hydration — Menü als statisches HTML,
  interaktive Inseln (Warenkorb) hydratisiert
- **PWA:** Astro unterstützt Service Worker; statische Auslieferung ideal für
  App-Shell-Caching
- **Hosting:** Cloudflare Pages (unbegrenzte Bandbreite, EU-freundlich)
- **Stärken:** extrem schnelle Erstladung, minimales JS, beste SEO,
  Cloudflare EU/GDPR günstiger und ~92 % günstiger [S16][S17][S18]
- **Schwächen:** komplexerer Warenkorb/Checkout benötigt React/Vue/Svelte-Inseln;
  Supabase-Auth-Integration weniger dokumentiert als Next.js; Astro ist
  inhaltlich-seiten-zentriert, nicht app-zentriert [S05][S06]

### Option C: Next.js (App Router) + Cloudflare Pages (Open Next / @cloudflare/next-on-pages)

- **Framework:** Next.js mit React, App Router (wie Option A)
- **Hosting:** Cloudflare Pages statt Vercel via `@cloudflare/next-on-pages`
- **Stärken:** vereint Next.js-DX mit Cloudflare-Kosten/GDPR-Vorteilen;
  hybrides Rendering; Supabase-Integration reif
- **Schwächen:** `next-on-pages` ist eine Adapter-Schicht mit Kompatibilitätslücken
  bei bestimmten Next.js-Features (Edge-Runtime-Einschränkungen); Preview-
  Deployments vorhanden aber weniger nahtlos als nativ Vercel; zusätzliche
  Komplexitätsschicht

---

## 3. Vergleich anhand der Bewertungskriterien

Legende: ✅ stark / ⚠️ akzeptabel / ❌ schwach

| Kriterium | A: Next.js+Vercel | B: Astro+Cloudflare | C: Next.js+Cloudflare |
|-----------|:---:|:---:|:---:|
| **Mobile QR-Erstladung** | ⚠️ (größeres JS-Bundle) | ✅ (minimales JS, Inseln) | ⚠️ (wie A) |
| **Anonyme Bestellung (Supabase/RLS)** | ✅ (`@supabase/ssr`, reif) | ⚠️ (mehr Eigenleistung) | ✅ (wie A) |
| **PWA / Offline-Shell** | ⚠️ (Serwist, Aufwand) | ✅ (statisch, natürlich geeignet) | ⚠️ (wie A) |
| **SEO** | ✅ (SSR/SSG) | ✅ (statisch, minimal JS) | ✅ (wie A) |
| **TypeScript-Verträge (generiert)** | ✅ (reif) | ✅ (framework-unabhängig) | ✅ (wie A) |
| **Tests** | ✅ (Vitest/Jest/Playwright) | ✅ (Vitest/Playwright) | ✅ (wie A) |
| **Kosten (Free-Tier)** | ⚠️ (100 GB, Skalierung) | ✅ (unbegrenzte Bandbreite) | ✅ (Cloudflare) |
| **EU-Datenschutz** | ⚠️ (Vercel EU weniger ideal) [S18] | ✅ (Cloudflare EU-freundlich) [S18] | ✅ (wie B) |
| **Preview-Deployments** | ✅ (nativ Vercel) | ✅ (Cloudflare Pages) | ✅ (Cloudflare Pages) |
| **Anschluss lokaler Venue-Hub** | ✅ (dynamische Endpunkte) | ⚠️ (statisch-zentriert) | ✅ (wie A) |
| **DX / Reife** | ✅ (größtes Ökosystem) | ⚠️ (schmaler, inhaltslastig) | ⚠️ (Adapter-Schicht) |

### Wichtige qualitative Notizen

- **Supabase-Region unabhängig vom Hosting:** Unabhängig von der Wahl des
  Frontend-Hostings bleibt Supabase in der **EU-Region Frankfurt** (`eu-central-1`)
  [S25][S27][S28] und bietet einen **DPA** an [S26]. Das Frontend-Hosting
  betrifft nur die Auslieferung statischer Assets, nicht die personenbezogenen
  Bestelldaten, die in Supabase liegen.
- **TypeScript-Verträge sind framework-unabhängig:** `supabase gen types`
  erzeugt Typen aus dem DB-Schema [S22][S23], automatisierbar via GitHub
  Actions [S24]. Das funktioniert bei allen drei Optionen gleich.
- **Background Sync ist keine Bestellgarantie:** Die PWA-Background-Sync-API
  [S29][S31] erlaubt automatisches Retry von Writes, ist aber nicht verlässlich
  für kritische ACKs. Siehe §7 zur Trennung von Offline-Shell und bestätigter
  Bestellung.

---

## 4. Empfehlung

### Empfohlene Lösung: Option C — Next.js (App Router) + Cloudflare Pages

**Empfehlung:** Next.js mit App Router, gehostet auf Cloudflare Pages via
`@cloudflare/next-on-pages`, mit Supabase als Backend (EU-Region Frankfurt).

#### Begründung

1. **Beste Balance aus Interaktivität und Kosten/GDPR.** Next.js liefert die
   für Warenkorb, Checkout und späteren Venue-Hub-Anschluss benötigte
   App-artige Dynamik [S05][S12], während Cloudflare Pages die EU/GDPR- und
   Kostenvorteile bringt, die Vercel fehlen [S16][S17][S18][S19].

2. **Supabase-Integration ist am reifsten bei Next.js.** Die `@supabase/ssr`-
   Pakete und Tutorials sind für Next.js besser dokumentiert als für SvelteKit
   oder Astro [S10]. Das senkt das Implementierungsrisiko für anonyme
   Bestellung und RLS.

3. **Preview-Deployments bleiben erhalten.** Cloudflare Pages bietet
   Preview-Deployments pro Branch/PR wie Vercel — ein harter Anspruch aus
   dem Auftrag.

4. **QR-Erstladung ist akzeptabel lösbar.** Zwar hat Next.js ein größeres
   JS-Bundle als Astro, aber Menüseiten können statisch generiert (SSG) und
   via Service Worker als App-Shell gecacht werden [S01][S03][S04]. Die
   Zweitladung ist dann instant. Für die erste QR-Ladung reicht eine
   schlanke Menü-Route ohne client-seitige schwerere Komponenten.

5. **Hybrides Rendering deckt beide Welten ab.** Statisches Menü (SEO,
   Cache-günstig) und dynamischer Checkout (Echtzeit, Supabase-Realtime)
   in einem Framework [S12].

6. **Venue-Hub-Anbindung ist natürlich.** Später kann der gleiche
   Next.js-Stack den lokalen Venue-Hub als alternative Datenquelle
   ansprechen (siehe §7), was mit einem rein statischen Astro schwerer wäre.

#### Akzeptiertes Risiko

`@cloudflare/next-on-pages` ist eine Adapter-Schicht mit gelegentlichen
Kompatibilitätslücken bei Edge-Runtime-Features. Dies wird durch frühzeitige
Verifikation der Kernrouten (Menü, Checkout) im Prototyp gemindert. Sollte
der Adapter blockieren, ist **Option A (Vercel) dieFallback-Alternative**
mit minimaler Codeänderung (nur Hosting-Konfiguration, nicht das Framework).

### Alternativoption: Option A — Next.js + Vercel

Wenn Cloudflare-Pages-Kompatibilität sich als Blockade erweist oder die
nahtlosesten Preview-Deployments und die niedrigste Betreiber-Komplexität
Priorität haben, ist Vercel dieFallback-Alternative. Der Code bleibt
identisch (dasselbe Next.js-Framework); nur das Hosting wechselt. Die
höheren Kosten und die schwächere EU/GDPR-Position von Vercel [S18] sind
dann bewusst zu akzeptieren.

### Warum nicht Astro (Option B)?

Astro ist für inhaltliche, statisch-lastige Seiten ideal [S05][S06][S07],
aber das Gast-Web benötigt einen interaktiven Warenkorb, Checkout,
Echtzeit-Status und später die Venue-Hub-Anbindung. Das würde in Astro
bedeuten, React/Vue/Svelte-Inseln einzubetten — dann hat man die Komplexität
von Astro plus einem App-Framework, ohne Astros Hauptvorteil (minimal JS)
voll zu nutzen. Die Performance-Einbuße von Next.js ist durch SSG +
Service-Worker-Caching ausgleichbar.

---

## 5. Architekturdiagramm

```
┌──────────────────────────────────────────────────────────────────┐
│                          Gast-Gerät                               │
│  Safari / Chrome (iPhone, Android, Desktop)                      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  PWA App Shell (Service Worker gecacht)                  │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │    │
│  │  │  Menü-Ansicht│  │ Warenkorb    │  │ Checkout /     │  │    │
│  │  │  (statisch,  │  │ (client-seitig│  │ Bestellung     │  │    │
│  │  │   SSG)       │  │  interaktiv) │  │ (→ Supabase)   │  │    │
│  │  └─────────────┘  └──────────────┘  └────────────────┘  │    │
│  └──────────────────────────────────────────────────────────┘    │
└───────────────┬──────────────────────────────┬───────────────────┘
                │ HTTPS                        │ HTTPS (Supabase JS)
                │ (statische Assets +          │
                │  Next.js SSR/SSG)            │
   ┌────────────▼──────────────┐    ┌──────────▼─────────────────┐
   │   Cloudflare Pages         │    │     Supabase               │
   │   (Frontend-Hosting)       │    │     (EU-Region Frankfurt)  │
   │                            │    │                            │
   │   • Next.js App Router     │    │   • PostgreSQL + RLS       │
   │   • @cloudflare/           │    │   • Auth (anonym/gast)     │
   │     next-on-pages          │    │   • REST/Realtime          │
   │   • Preview-Deployments    │    │   • Row Level Security     │
   │   • CDN / Edge             │    │     (anon-Rollen-Policy)   │
   │   • unbegrenzte Bandbreite │    │   • generierte TS-Typen    │
   └────────────────────────────┘    └────────────────────────────┘
                                            ▲
                │ später (Blueprint §16)    │
                │                           │ lokaler Venue-Hub
   ┌────────────▼──────────────┐            │ (iPhone/iPad, offline)
   │   Restaurant-WLAN         │────────────┘
   │   ┌──────────────────┐    │   • NWListener HTTP-Server
   │   │  Venue Hub       │    │   • lokales SQLite-Event-Log
   │   │  (iPad/iPhone)   │────┼──▶ Outbox/Inbox-Sync
   │   └──────────────────┘    │   • Bestell-ACK erst nach
   └───────────────────────────┘     dauerhaftem Commit
```

### Datenfluss — normale Online-Bestellung

```
1. Gast scannt QR → Browser öffnet https://<venue>.kitchenlink.app/menu/<slug>
2. Cloudflare Pages liefert statisch generierte Menüseite (SSG, CDN-gecacht)
3. Gast fügt Artikel hinzu (client-seitig, Supabase-Menü via RLS lesbar)
4. Gast sendet Bestellung → Supabase (RLS: anon-Rolle darf INSERT mit Policy)
5. Supabase persistiert → Realtime notify → Business-App sieht Bestellung
6. Gast-Web zeigt Bestätigung (Status "eingegangen")
```

---

## 6. Deploymentfluss

### 6.1 CI/CD-Pipeline (GitHub-basiert)

```
Feature-Branch (push)
        │
        ▼
GitHub Actions auslösen
        │
        ├──▶ npm ci && npm run lint && npm run typecheck
        ├──▶ npm run test (Vitest)
        ├──▶ npm run build (next build)
        ├──▶ Cloudflare Pages: Preview-Deployment pro Branch
        │     → eindeutige URL (z.B. <hash>.kitchenlink-pages.dev)
        └──▶ supabase gen types (optional, bei Schema-Änderung)
        │
        ▼
Pull Request mit Preview-URL im Kommentar
        │
        ▼
Review (Peer-Workflow) → Merge nach main
        │
        ▼
Cloudflare Pages: Production-Deployment
        → https://<venue>.kitchenlink.app (Custom Domain)
        → https://kitchenlink-guest.pages.dev (Fallback)
```

### 6.2 Umgebungen

| Umgebung | Zweck | Supabase-Projekt | Sichtbarkeit |
|----------|-------|------------------|--------------|
| **Preview** (pro Branch) | Review, Tests | Entwicklungs-Supabase | nur PR-Reviewer |
| **Staging** (main-pre-merge) | Integrationstest | Sandbox-Supabase | intern |
| **Production** | echte Gäste | Produktions-Supabase (EU) | öffentlich, nach Freigabe |

> Blueprint §18.3 fordert getrennte Supabase-Projekte für Entwicklung, Sandbox
> und Produktion. Das Gast-Web-Hosting spiegelt das mit drei Deployment-Umgebungen.

---

## 7. Offline-App-Shell vs. bestätigte Offline-Bestellung (kritische Trennung)

Diese Trennung ist produktsprachlich zwingend (Blueprint §16.2: „Die App darf
nie eine Bestellung als angekommen bestätigen, bevor mindestens ein
autoritativer Venue-Knoten sie dauerhaft gespeichert hat").

### 7.1 Was offline gehen darf: die App-Shell

Die **PWA-App-Shell** (HTML, CSS, JS, Menü-Template, Icons) kann via Service
Worker gecacht werden [S29][S32]. Das erlaubt:

- schnelle Zweitladung (Instant-Load aus Cache)
- Menü-Ansicht auch bei schlechtem Netz
- Warenkorb-Zusammenstellung offline

**Aber:** Das ist nur die UI-Hülle. Keine Bestellung gilt als „angekommen",
nur weil die UI sie lokal anzeigt.

### 7.2 Was offline nicht gehen darf: die Bestellannahme

Eine **tatsächliche Bestellung** erfordert die dauerhafte Speicherung durch
einen autoritativen Knoten. Drei Fälle:

| Fall | Mechanismus | Status für Gast |
|------|-------------|-----------------|
| **Online (Normalfall)** | Bestellung → Supabase (RLS) → ACK | „Eingegangen" (bestätigt) |
| **Internet aus, Venue-Hub im WLAN vorhanden** | Bestellung → lokaler Venue-Hub (HTTP) → dauerhafter SQLite-Commit → ACK | „Eingegangen" (bestätigt durch Hub) |
| **Internet aus, kein Venue-Hub erreichbar** | Bestellung kann **nicht** bestätigt werden | „Offline — Bestellung noch nicht übermittelt" — **kein falsches ACK** |

### 7.3 Background Sync als Ergänzung, nicht als Garantie

Die PWA-Background-Sync-API [S29][S31] kann Writes automatisch retrien, sobald
Konnektivität zurückkehrt. Das ist nützlich, um eine Bestellung in einer
Foreground-Queue zu puffern [S30]. **Aber:** der Gast darf erst dann
„Eingegangen" sehen, wenn das ACK vom autoritativen Knoten (Supabase oder
Venue-Hub) tatsächlich eintrifft. Bis dahin zeigt das Gast-Web einen
eindeutigen Offline-/Pending-Status (Design-System §6: „wartet"-Dringlichkeit).

### 7.4 Implikation für die ADR

Das Gast-Web muss so gebaut sein, daß der Bestell-Status ausschließlich aus
der Server-/Hub-Antwort abgeleitet wird, **niemals** aus dem lokalen
Absenden. Die Service-Worker-Logik cached die Shell, aber die Bestell-Logik
ist ein autoritativ bestätigter Vorgang.

---

## 8. Vorgeschlagene Ordnerstruktur

```
guest-web/                          (neues Top-Level-Verzeichnis, getrennt vom iOS-Projekt)
├── package.json
├── next.config.js                  (App Router, next-on-pages-Konfiguration)
├── wrangler.toml                   (Cloudflare-Pages-Konfiguration)
├── tsconfig.json
├── supabase/
│   └── generated-types.ts          (via `supabase gen types`, CI-aktualisiert) [S22][S24]
├── public/
│   ├── manifest.webmanifest        (PWA-Manifest)
│   └── icons/                      (App-Icons, maskable)
├── src/
│   ├── app/                        (Next.js App Router)
│   │   ├── layout.tsx              (Root, lädt Design-Tokens)
│   │   ├── [venueSlug]/
│   │   │   ├── menu/
│   │   │   │   └── page.tsx        (statisch generierte Menüseite)
│   │   │   └── checkout/
│   │   │       └── page.tsx        (dynamischer Checkout)
│   │   └── api/                    (Route Handler, später Venue-Hub-Proxy)
│   ├── components/
│   │   ├── MenuCard.tsx
│   │   ├── Cart.tsx
│   │   └── OrderStatusBadge.tsx
│   ├── lib/
│   │   ├── supabase-client.ts      (createClient<Database> mit generierten Typen)
│   │   ├── design-tokens.ts        (semantische Namen aus DESIGN_SYSTEM.md)
│   │   └── order-ack.ts            (ACK-Logik: Status nur aus Server-Antwort)
│   ├── styles/
│   │   └── tokens.css              (CSS-Variablen, Traube/Zitrone semantisch)
│   └── sw/                         (Service-Worker: App-Shell-Caching)
│       └── register.ts
├── __tests__/                      (Vitest)
│   ├── order-ack.test.ts
│   └── cart.test.ts
└── e2e/                            (Playwright)
    └── guest-order.spec.ts
```

### Begründung der Trennung

- **`guest-web/` als eigenes Verzeichnis**, getrennt vom `kitchenlink/`-iOS-Projekt
  und von der späteren `admin-web/`-Browser-Verwaltung (Blueprint §3.3).
- **`supabase/generated-types.ts`** als einzige Quelle der typisierten Verträge,
  CI-generiert [S24], niemals manuell gepflegt.
- **`design-tokens.ts`** spiegelt die semantischen Namen aus
  `DESIGN_SYSTEM.md` §3–5, sodaß SwiftUI und Web dieselben Token-Namen teilen
  (Design-System §11).
- **`order-ack.ts`** kapselt die kritische ACK-Logik aus §7 — testbar und
  isoliert von der UI.

---

## 9. Bootstrap-Schritte (Implementierung folgt nach Freigabe)

Diese Schritte sind **nicht Teil dieser ADR** (keine Implementierung), sondern
ein Vorschlag für die Umsetzung, sobald der Nutzer den Stapel freigibt.

1. **Projektgerüst:** `npx create-next-app guest-web` (App Router, TypeScript,
   Tailwind optional). Separates Verzeichnis, eigene `package.json`.
2. **Cloudflare-Pages-Setup:** `@cloudflare/next-on-pages` installieren,
   `wrangler.toml` anlegen, GitHub-Integration verbinden, Preview-Deployments
   aktivieren.
3. **Supabase-Anbindung:** `@supabase/ssr` installieren,
   `createClient<Database>` mit generierten Typen [S22], EU-Frankfurt-Projekt.
4. **Design-Tokens:** `design-tokens.ts` und `tokens.css` aus
   `DESIGN_SYSTEM.md` ableiten; Traube/Zitrone semantisch, Zitronenregel
   technisch sichern (nur eine Primäraktion).
5. **Menü-Route:** statisch generierte `[venueSlug]/menu`-Seite, RLS-lesbar
   für `anon`.
6. **Warenkorb + Checkout:** client-seitig interaktiv, Bestellung via Supabase
   mit RLS-Policy für anonyme INSERT.
7. **PWA-Shell:** Service Worker registrieren, App-Shell cachen [S01][S03],
   `manifest.webmanifest`.
8. **ACK-Logik:** `order-ack.ts` — Status ausschließlich aus Server-Antwort;
   Offline-Pending-Status.
9. **Tests:** Vitest (Unit: ACK, Warenkorb) + Playwright (E2E: QR → Bestellung).
10. **Sandbox-Banner:** sichtbares Sandbox-Label auf jeder Gast-Seite
    (Blueprint §20).

---

## 10. Konsequenzen

### Positive Konsequenzen

- **Klarer Stack** für das gesamte Gast-Web; keine offene Technologiefrage mehr.
- **EU-DSGVO-konform** durch Cloudflare-Pages-Hosting und Supabase-Region
  Frankfurt [S18][S25][S26].
- **Kosteneffizient** durch Cloudflare (unbegrenzte Bandbreite, kein Egress) [S16][S17][S19].
- **Typsicherheit End-to-End** durch generierte Supabase-Typen [S22][S23][S24].
- **Preview-Deployments** fürPeer-Review-Workflow.
- **PWA-Fähigkeit** für schnelle Zweitladung und spätere Offline-Shell.
- **Venue-Hub-Anschluss** später natürlich möglich (gleicher TypeScript-Stack).
- **Design-System-Kompatibilität**: gleiche semantische Token-Namen wie SwiftUI.

### Negative Konsequenzen / Akzeptierte Nachteile

- **`@cloudflare/next-on-pages`-Adapter-Risiko:** gelegentliche
  Kompatibilitätslücken bei Edge-Runtime-Features. Migration zu Vercel
  (Option A) bleibt alsNotausgang mit gleichem Code.
- **Größeres JS-Bundle als Astro:** durch Service-Worker-Caching und SSG
  abmilderbar, aber die erste QR-Ladung ist nicht so minimal wie bei einem
  rein statischen Ansatz.
- **Zwei Build-Pipelines:** iOS (Xcode) und Web (npm/Next.js) getrennt —
  erhöht Build-/CI-Komplexität im Repository.
- **TypeScript-Vertragssynchronisation** erfordert Disziplin: Schema-Änderung
  → `supabase gen types` → beide Clients aktualisieren.

---

## 11. Offene Produktentscheidungen (dem Nutzer vorzulegen)

Diese ADR kann folgende Entscheidungen nicht selbst treffen und behält sie
dem Nutzer vor (Blueprint §16, DECISIONS.md-Governance):

| # | Entscheidung | Warum offen | Einfluss |
|---|--------------|-------------|----------|
| D1 | **Domain-Strategie** — pro Venue Subdomain (`<venue>.kitchenlink.app`) oder Pfad (`kitchenlink.app/<venue>`)? | Produkt/Branding | DNS, SSL, QR-Generierung |
| D2 | **Anonyme Bestellung ohne jegliche Identität** — reicht ein client-seitiger Session-Token, oder verlangt das Produkt eine minimale Identifikation? | Datenschutz/Produkt | RLS-Policy-Design, GoBD-Relevanz |
| D3 | **Custom-Domain pro Restaurant** — darf ein Restaurant eine eigene Domain auf das Gast-Web zeigen? | Produkt/Vertrieb | Cloudflare-Konfiguration, SSL-Zertifikate |
| D4 | **Vercel vs. Cloudflare finale Wahl** — wenn der Adapter Risiken zeigt, ist Vercel (teurer, EU schwächer) akzeptiert? | Kosten/GDPR | Hosting-Provider |
| D5 | **Offline-Shell-Tiefe** — wie viel vom Gast-Web darf offline gecacht werden (nur Shell, oder auch Menüdaten)? | Datenschutz/Performance | Service-Worker-Strategie, Offline-Bestellung-Pfad |

Diese Punkte werden im Pull Request und im Handoff sichtbar gemacht.

---

## 12. Compliance- und Sicherheitsnotizen

- **RLS muß auf allen Tabellen** des exponierten `public`-Schemas aktiv sein
  [S20]. Die `anon`-Rolle darf nur über explizite Policies schreiben.
- **Service-Role-Key** nur server-seitig (Route Handlers), niemals im Browser.
- **Supabase EU-Region Frankfurt** (`eu-central-1`) für alle
  produktiven Projekte [S25][S28].
- **DPA** mit Supabase abschließen, bevor produktive Personendaten fließen [S26].
- **Sandbox-Banner** auf jeder Gast-Seite, solange nicht produktiv freigegeben
  (Blueprint §20).
- **Keine echten Zahlungen** im Gast-Web bis zur Payment-Freigabe (DECISIONS.md).
- **Keine externen Font-/Farbdienste zur Laufzeit** (DESIGN_SYSTEM.md §11):
  Bricolage Grotesque und Source Sans 3 als gebündelte lokale Assets.

---

## 13. Beziehung zu anderen ADRs und Discovery-Dokumenten

- **Offline-Venue-Hub** (`docs/discovery/offline-venue-hub/GLM_ARCHITECTURE.md`):
  diese ADR ergänzt das Hub-Konzept für die Gast-Seite. Der Venue-Hub liefert
  lokal autoritative Bestätigung; das Gast-Web leitet offline an ihn weiter,
  wenn Supabase nicht erreichbar ist.
- **Design-System** (`docs/design/DESIGN_SYSTEM.md`): semantische Token-Namen
  sind die verbindliche Brücke zwischen SwiftUI und Web.
- **Produkt-Blueprint §18.2**: „gemeinsame API-Verträge und generierte Typen"
  wird durch `supabase gen types` erfüllt.
