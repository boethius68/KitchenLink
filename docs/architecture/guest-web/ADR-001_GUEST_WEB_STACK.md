# ADR-001: KitchenLink Gast-Web-Stack und Hosting

**Status:** Proposed
**Datum:** 2026-07-16 (Revision 2 nach Review)
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-WEB-001A
**Entscheidungssteller:** Nutzer (produktsprachliche Freigabe offen)

Diese Architecture Decision Record (ADR) vergleicht Lösungsstapel für das
KitchenLink Gast-Web. Sie erfindet keine Produktentscheidungen und enthält keine
Implementierung. Tragende technische Aussagen sind durch Primärquellen belegt;
Quellenverweise `[Sxx]` verweisen auf [`SOURCES.md`](./SOURCES.md).

> **Änderung zur Revision 1:** Die Hostingentscheidung zwischen Vercel und
> Cloudflare wird bewusst **offen gehalten** und über eine PoC-Matrix (§8)
> entschieden. `@cloudflare/next-on-pages` ist vollständig entfernt; Cloudflare
> wird aktuell über **Workers + `@opennextjs/cloudflare`** beschrieben. Direkte
> Tabellen-INSERTs aus dem Gastbrowser sind durch eine autoritative
> Bestellgrenze (Edge Function oder PostgreSQL-RPC) ersetzt. Die anonyme Rolle
> wird zwischen `anon` (unauthenticated) und Supabase Anonymous Sign-in
> (`authenticated` + `is_anonymous`) unterschieden. Responsive Beta und
> PWA-/Offline-Shell sind getrennt. Unbelegte kommerzielle Aussagen sind entfernt.

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
verwaltetes Hosting erfolgen. Gleichzeitig müssen folgende Spannungen aufgelöst
werden:

| Spannung | Beschreibung |
|----------|--------------|
| **QR-Performance vs. Interaktivität** | QR-Erstladung muss schnell sein (Gast wartet am Tisch), aber Warenkorb/Checkout brauchen Interaktivität |
| **Statisch vs. dynamisch** | Menü ist weitgehend statisch (gut für SEO/Cache), Bestellung ist dynamisch und erfordert serverseitige Autorität |
| **Hosting-Optionen offen** | Vercel und Cloudflare Workers sind beide valide; die Entscheidung erfordert einen PoC (§8), keinen Vorab-Vorschlag |
| **Responsive-Beta vs. PWA/Offline** | die erste Beta ist eine responsive Website; PWA-/Offline-Fähigkeit ist eine spätere, getrennte Stufe (§7) |
| **Autoritative Bestellgrenze** | der Browser darf Bestellungen nicht direkt in Tabellen schreiben; eine serverseitige Grenze prüft Preis, Verfügbarkeit, Öffnungszeit, Kapazität und Idempotenz (§6) |
| **Anonyme Identität** | die bloße `anon`-Rolle (unauthenticated) unterscheidet sich technisch von Supabase Anonymous Sign-in (`authenticated` + `is_anonymous`); die Wahl ist produktsprachlich offen (§6.3) |

---

## 2. Framework-Empfehlung: Next.js (App Router)

### 2.1 Gewähltes Framework

**Empfehlung: Next.js mit App Router und React.**

Begründung, bezogen auf die drei diskutierten Frameworks:

| Aspekt | Next.js | Astro | SvelteKit |
|--------|---------|-------|-----------|
| Interaktiver Warenkorb + Checkout | ✅ nativ (Client Components) | ⚠️ erfordert React/Vue/Svelte-Inseln | ✅ nativ |
| Hybrides Rendering (SSG + SSR) | ✅ eingebaut | ✅ statisch + Inseln | ✅ mit Adapter |
| Supabase-DX | ✅ `@supabase/ssr`, reifes Ökosystem | ⚠️ mehr Eigenleistung | ⚠️ Auth komplexer als Next.js [S10] |
| Anbindung lokaler Venue-Hub | ✅ Route Handler / API-Routen | ⚠️ statisch-zentriert | ✅ möglich |

Astro ist für inhaltslastige, statische Seiten stark, aber ein interaktiver
Warenkorb würde seinen Hauptvorteil (minimales JS) aufheben. SvelteKit ist
valide, hat aber eine weniger reife Supabase-Auth-DX als Next.js [S10]. Next.js
bietet die beste Balance und bleibt Hosting-neutral.

### 2.2 Hosting bleibt offen (Vercel vs. Cloudflare Workers)

Das Framework Next.js läuft auf **beiden** Hosting-Optionen ohne Codeänderung.
Die Hostingentscheidung wird daher **nicht vorab** getroffen, sondern über die
PoC-Matrix in §8 abgesichert. Beide Optionen sind gleichrangige Kandidaten:

| Hosting | Next.js-Support | Hinweis |
|---------|-----------------|---------|
| **Vercel** | nativ (Mutterfirma) | nahtloseste DX; Preview-Deployments out-of-the-box |
| **Cloudflare Workers** | via `@opennextjs/cloudflare` | Worker-Runtime, Node.js-Kompatibilität; siehe §2.3 |

### 2.3 Cloudflare: aktuell Workers + `@opennextjs/cloudflare`

Cloudflare wird in dieser ADR als **Cloudflare Workers** beschrieben, nicht als
Pages. Der aktuelle Adapter, um Next.js auf Cloudflare Workers zu betreiben, ist
**`@opennextjs/cloudflare`** (OpenNext for Cloudflare) [S34][S35].

Verifizierte Fakten (Primärquellen, Abruf 2026-07-16):

- `@opennextjs/cloudflare` ist der aktuelle, von Cloudflare empfohlene Adapter,
  um Next.js auf **Cloudflare Workers** bereitzustellen [S34][S36].
- Er nutzt die Next.js-Node.js-Runtime in Cloudflares **workerd**-Laufzeit über
  die Workers-Node.js-Kompatibilitätsschicht [S35].
- Er hat den älteren `@cloudflare/next-on-pages`-Adapter abgelöst, der nur die
  „Edge"-Runtime unterstützte; `@opennextjs/cloudflare` unterstützt die volle
  Node.js-Runtime [S34].
- Cloudflare selbst routet Next.js-on-Cloudflare-Traffic auf diesen Adapter
  (`npm create cloudflare@latest --framework=next --platform=workers`) [S36].

> **Hinweis:** `@cloudflare/next-on-pages` ist in dieser ADR vollständig
> entfernt. Alle früheren Bezugnahmen auf Pages/`next-on-pages` wurden durch
> Workers/`@opennextjs/cloudflare` ersetzt.

---

## 3. Architekturdiagramm

```
┌──────────────────────────────────────────────────────────────────┐
│                          Gast-Gerät                               │
│  Safari / Chrome (iPhone, Android, Desktop)                      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Responsive Gast-Web-Beta  (Stage 1, kein Service Worker)│    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │    │
│  │  │  Menü-Ansicht│  │ Warenkorb    │  │ Checkout /     │  │    │
│  │  │  (statisch,  │  │ (client-seitig│  │ Bestellung     │  │    │
│  │  │   SSG)       │  │  interaktiv) │  │ → Edge Func    │  │    │
│  │  └─────────────┘  └──────────────┘  └────────────────┘  │    │
│  └──────────────────────────────────────────────────────────┘    │
│  [Stage 2 später: optionale PWA-Shell via Service Worker, §7]    │
└───────────────┬──────────────────────────────┬───────────────────┘
                │ HTTPS                        │ HTTPS
                │ (statische Assets +          │ (aufruf Edge Function /
                │  Next.js SSR/SSG)            │  PostgreSQL-RPC)
                │                              │
   ┌────────────▼──────────────────┐  ┌────────▼───────────────────┐
   │  Vercel ODER Cloudflare Workers│  │     Supabase               │
   │  (Hosting offen, §8)           │  │     (EU-Region Frankfurt)  │
   │                                │  │                            │
   │  • Next.js App Router          │  │  • PostgreSQL + RLS        │
   │  • ggf. @opennextjs/cloudflare │  │  • Auth (anon / anonymous  │
   │    (falls Cloudflare)          │  │    sign-in, §6.3)          │
   │  • Preview-Deployments         │  │  • Edge Functions (Deno):  │
   │  • CDN                         │  │    autoritative Bestell-   │
   │                                │  │    grenze [S37][S38]       │
   │                                │  │  • generierte TS-Typen     │
   └────────────────────────────────┘  └────────────────────────────┘
                                            ▲
                │ später (Blueprint §16)    │ Outbox/Inbox-Sync
                │                           │ lokaler Venue-Hub
   ┌────────────▼──────────────────┐        │ (iPhone/iPad, offline)
   │   Restaurant-WLAN             │────────┘
   │   ┌──────────────────┐        │  • Bestell-ACK erst nach
   │   │  Venue Hub        │        │    dauerhaftem Commit
   │   │  (iPad/iPhone)    │────────┼─▶ (Blueprint §16.2)
   │   └──────────────────┘        │
   └────────────────────────────────┘
```

### Datenfluss — normale Online-Bestellung (autoritativ)

```
1. Gast scannt QR → Browser öffnet die Venue-Menüroute
2. Hosting (Vercel/CF Workers) liefert statisch generierte Menüseite (SSG, CDN)
3. Gast fügt Artikel hinzu (client-seitig; Menü via RLS lesbar)
4. Gast sendet Bestellung → Supabase Edge Function ODER PostgreSQL-RPC
   (NICHT direkt in eine Tabelle — siehe §6 autoritative Bestellgrenze)
5. Edge Function/RPC prüft serverseitig:
     Preis (aus DB, nicht aus Client), Verfügbarkeit, Öffnungszeit,
     Kapazität, Idempotenz-Key
6. Bei Erfolg: transaktionale Persistierung + Idempotenz-Eintrag → ACK
7. Realtime-Notify → Business-App sieht Bestellung
8. Gast-Web zeigt „Eingegangen" erst nach ACK (§7)
```

---

## 4. Deploymentfluss

### 4.1 CI/CD-Pipeline (GitHub-basiert, hosting-neutral)

```
Feature-Branch (push)
        │
        ▼
GitHub Actions auslösen
        │
        ├──▶ npm ci && npm run lint && npm run typecheck
        ├──▶ npm run test (Vitest)
        ├──▶ npm run build (next build)
        ├──▶ Hosting: Preview-Deployment pro Branch
        │     (Vercel ODER CF Workers, je nach §8-Ergebnis)
        │     → eindeutige Preview-URL
        └──▶ supabase gen types (bei Schema-Änderung) [S22][S24]
        │
        ▼
Pull Request mit Preview-URL im Kommentar
        │
        ▼
Review (Peer-Workflow) → Merge nach main
        │
        ▼
Production-Deployment (Vercel ODER CF Workers)
```

### 4.2 Umgebungen

| Umgebung | Zweck | Supabase-Projekt | Sichtbarkeit |
|----------|-------|------------------|--------------|
| **Preview** (pro Branch) | Review, Tests | Entwicklungs-Supabase | nur PR-Reviewer |
| **Staging** (main-pre-merge) | Integrationstest | Sandbox-Supabase | intern |
| **Production** | echte Gäste | Produktions-Supabase (EU) | öffentlich, nach Freigabe |

> Blueprint §18.3 fordert getrennte Supabase-Projekte für Entwicklung, Sandbox
> und Produktion. Das Gast-Web-Hosting spiegelt das mit drei Deployment-Umgebungen.

---

## 5. Offline-App-Shell vs. bestätigte Bestellung — phasentrennung

### 5.1 Stage 1: Responsive Gast-Web-Beta (kein Service Worker)

Die erste Ausbaustufe ist eine **responsive Website ohne PWA/Offline-Fähigkeit**.
Sie funktioniert in jedem modernen Browser (Safari, Chrome, Desktop), erfordert
aber Netzverbindung für Bestellung und Menü. Es gibt keinen Service Worker, kein
App-Shell-Caching. Dies entspricht dem minimalen Produktbedarf „Gast bestellt im
Browser" (DECISIONS.md, Blueprint §3.1) ohne zusätzliche PWA-Komplexität.

### 5.2 Stage 2: PWA-/Offline-Shell (später, getrennt)

Erst in einer späteren, **eigenen** Stufe wird das Gast-Web um eine PWA-Shell
ergänzt (Service Worker, Manifest, App-Shell-Caching). Dies dient der
Zweitlade-Performance und der Menü-Ansicht bei schlechtem Netz. Diese Stufe ist
produktsprachlich und technisch von der Beta getrennt und braucht eine eigene
Entscheidung (siehe D5).

### 5.3 Die kritische Trennung: Offline-Shell ≠ bestätigte Bestellung

Diese Trennung ist produktsprachlich zwingend (Blueprint §16.2: „Die App darf
nie eine Bestellung als angekommen bestätigen, bevor mindestens ein
autoritativer Venue-Knoten sie dauerhaft gespeichert hat").

| Aspekt | App-Shell (Stage 2, PWA) | Bestellannahme |
|--------|--------------------------|----------------|
| **Was** | UI-Hülle (HTML/CSS/JS/Menü-Template) cachen | tatsächliche, dauerhafte Persistierung |
| **Darf offline?** | ja (zweite Ladung instant, Menü bei schlechtem Netz) | **nein** ohne autoritativen Knoten |
| **Bestätigung** | zeigt nur lokal gepufferten Zustand | „Eingegangen" erst nach ACK des autoritativen Knoten |

Drei Betriebsfälle für eine Bestellung:

| Fall | Mechanismus | Status für Gast |
|------|-------------|-----------------|
| **Online** | Bestellung → Edge Function/RPC (§6) → dauerhafter Commit → ACK | „Eingegangen" (bestätigt) |
| **Internet aus, Venue-Hub im WLAN** | Bestellung → lokaler Venue-Hub (HTTP) → dauerhafter SQLite-Commit → ACK | „Eingegangen" (bestätigt durch Hub) |
| **Internet aus, kein Venue-Hub** | Bestellung kann **nicht** bestätigt werden | „Offline — noch nicht übermittelt" — **kein falsches ACK** |

**Background Sync** (falls in Stage 2 genutzt) ist ausschließlich eine
Retry-Hilfe für die Übermittlung [S29][S31]; sie liefert kein ACK. Der Gast darf
„Eingegangen" erst sehen, wenn das ACK vom autoritativen Knoten tatsächlich
eintrifft. Bis dahin gilt ein eindeutiger Pending-/Wartet-Status
(Design-System §6).

---

## 6. Autoritative Bestellgrenze und anonyme Identität

### 6.1 Keine direkten Tabellen-INSERTs aus dem Browser

**Änderung zur Revision 1:** Der Gastbrowser schreibt Bestellungen **nicht mehr
direkt** in Supabase-Tabellen über eine RLS-Policy. Stattdessen verläuft jede
Bestellung durch eine **autoritative serverseitige Grenze**, die vor
Persistierung prüft (Blueprint §6.3 „Preis, Verfügbarkeit, Öffnungszeit und
Bestellkapazität werden vor Annahme … lokal-authoritativ geprüft"):

| Prüfung | Beschreibung |
|---------|--------------|
| **Preis** | serverseitig aus der DB, niemals aus dem Client-Request |
| **Verfügbarkeit** | Artikel aktiv und nicht ausverkauft |
| **Öffnungszeit** | Bestellung innerhalb der Bestell-Öffnungszeiten |
| **Kapazität** | Bestellkapazität der Venue/Station nicht überschritten |
| **Idempotenz** | Idempotenz-Key prüfen, Doppelabgabe verhindern |

### 6.2 Zwei Implementierungs-Optionen (in der ADR offen)

| Option | Mechanismus | Quelle |
|--------|-------------|--------|
| **A: Supabase Edge Function** | Deno-Funktion; nutzt `ctx.supabaseAdmin` für privilegierte Operationen, die RLS umgeht; prüft + persistiert + bestätigt idempotent | [S37][S38] |
| **B: PostgreSQL-RPC (transaktional)** | `pg`-Funktion (`SECURITY DEFINER`) mit `FOR UPDATE`-Sperren, atomarer Preis-/Kapazitätsprüfung und Idempotenz-Tabelle in einer Transaktion | [S20] |

Beide Optionen halten das Service-Role-Geheimnis serverseitig und exponieren
dem Browser nur einen kontrollierten Endpunkt. Die Wahl zwischen Edge Function
und RPC ist eine spätere Implementierungsentscheidung und nicht Teil dieser ADR.

### 6.3 Anonyme Identität: `anon`-Rolle vs. Anonymous Sign-in

Supabase unterscheidet zwei Konzepte, die nicht verwechselt werden dürfen
(Primärquelle [S40], „Anonymous user vs the anon key"):

| Konzept | Rolle | JWT/User | Eignung |
|---------|-------|----------|---------|
| **`anon`-Rolle (unauthenticated)** | Postgres `anon`-Rolle | kein User, nur Projekt-API-Key | öffentlicher Lesezugriff (z.B. Menü); schreibend nur über sehr offene Policies — **nicht** für autoritative Bestellungen empfohlen |
| **Supabase Anonymous Sign-in** | Postgres **`authenticated`**-Rolle | echte `auth.users`-Zeile mit `is_anonymous = true`, gültiges JWT mit `is_anonymous`-Claim | anonyme Bestellung mit identifizierbarer (aber temporärer) Session; RLS-Policy kann `is_anonymous` prüfen; später konvertierbar in permanenten Account |

**Verifizierte Fakten (Supabase-Doku, Abruf 2026-07-16):**

- Anonymous Sign-in erzeugt einen echten Benutzer in `auth.users`, verhält sich
  „like a permanent user", außer daß die Session nach Sign-out/Device-Wechsel
  verloren ist [S40].
- Ein anonym eingeloggt User erhält die **`authenticated`**-Rolle für RLS,
  genau wie ein permanenter User [S40].
- Das JWT enthält den **`is_anonymous`**-Claim, den RLS-Policies via
  `auth.jwt() ->> 'is_anonymous'` prüfen können [S40].
- Dies ist verschieden vom `anon`-API-Key, der **keinen** User anlegt und die
  `anon`-Rolle verwendet [S40].

**Empfehlung für die autoritative Bestellung:** Anonymous Sign-in
(`authenticated` + `is_anonymous`) kombiniert mit der Edge Function/RPC-Grenze
aus §6.2. So bleibt die Bestellung einer identifizierbaren (wenn auch
anonymen) Session zugeordnet, ohne daß der Browser direkten Schreibzugriff
braucht. Die endgültige produktsprachliche Wahl bleibt dem Nutzer vorbehalten
(Entscheidung D2).

---

## 7. Vorgeschlagene Ordnerstruktur

```
guest-web/                          (neues Top-Level-Verzeichnis, getrennt vom iOS-Projekt)
├── package.json
├── next.config.js                  (App Router; hosting-neutral)
├── tsconfig.json
├── supabase/
│   └── generated-types.ts          (via `supabase gen types`, CI-aktualisiert) [S22][S24]
├── public/
│   └── icons/                      (App-Icons; manifest erst in Stage 2)
├── src/
│   ├── app/                        (Next.js App Router)
│   │   ├── layout.tsx              (Root, lädt Design-Tokens)
│   │   ├── [venueSlug]/
│   │   │   ├── menu/
│   │   │   │   └── page.tsx        (statisch generierte Menüseite)
│   │   │   └── checkout/
│   │   │       └── page.tsx        (dynamischer Checkout → Edge Function/RPC)
│   │   └── api/                    (Route Handler; später Venue-Hub-Proxy)
│   ├── components/
│   │   ├── MenuCard.tsx
│   │   ├── Cart.tsx
│   │   └── OrderStatusBadge.tsx
│   ├── lib/
│   │   ├── supabase-client.ts      (createClient<Database> mit generierten Typen)
│   │   ├── design-tokens.ts        (semantische Namen aus DESIGN_SYSTEM.md)
│   │   ├── order-ack.ts            (ACK-Logik: Status nur aus Server-Antwort)
│   │   └── order-submit.ts         (ruft Edge Function/RPC auf, nie direkten INSERT)
│   └── styles/
│       └── tokens.css              (CSS-Variablen, Traube/Zitrone semantisch)
│   # sw/ (Service Worker) ERST in Stage 2 (PWA), nicht in der Beta
├── __tests__/                      (Vitest)
│   ├── order-ack.test.ts
│   ├── order-submit.test.ts
│   └── cart.test.ts
└── e2e/                            (Playwright)
    └── guest-order.spec.ts
```

### Begründung

- **`guest-web/` als eigenes Verzeichnis**, getrennt vom `kitchenlink/`-iOS-Projekt
  und der späteren `admin-web/`-Browser-Verwaltung (Blueprint §3.3).
- **Keine hosting-spezifische Konfiguration** (`wrangler.toml`/`vercel.json`)
  in Stage 1; sie wird erst nach der PoC-Entscheidung (§8) hinzugefügt.
- **`order-submit.ts`** kapselt den Aufruf der autoritativen Grenze (§6); der
  Browser hat keinen direkten Tabellen-Schreibpfad.
- **`sw/` bewusst nicht vorhanden** in Stage 1; die Beta bleibt eine responsive
  Website ohne Service Worker (§5.1).

---

## 8. PoC-Matrix: Vercel vs. Cloudflare Workers

Da die Hostingentscheidung offen gehalten wird, schlägt diese ADR eine kleine
Proof-of-Concept-Matrix vor, die beide Anbieter anhand derselben Kriterien
mit realen Messungen vergleicht. Erst das PoC-Ergebnis führt zur
Hosting-Entscheidung.

| PoC-Kriterium | Was gemessen wird | Vercel | Cloudflare Workers |
|---------------|-------------------|--------|-------------------|
| **Next.js-Kompatibilität** | Menü-Route (SSG) + einfache Supabase-Lesung baut und läuft | nativ | via `@opennextjs/cloudflare` [S34] |
| **Edge Function / API-Route** | autoritative Bestellgrenze aus §6 funktioniert | Route Handler / Server Action | Workers-Funktion via OpenNext |
| **Preview-Deployment pro Branch** | automatische Preview-URL pro PR | out-of-the-box | Cloudflare-Preview (Workers) |
| **QR-Erstladung (mobil)** | LCP / TTFB einer frischen Menüseite (Safari, 4G-Drosselung) | messen | messen |
| **EU-Region** | Frontend-Edge in EU; Supabase bleibt in Frankfurt (`eu-central-1`) [S25] | EU-Region verfügbar | EU-Rechenzentren vorhanden |
| **Kosten-Modell** | Free-Tier-Grenzen (Builds, Requests, Bandbreite) anhand der aktuellen Preisseiten beider Anbieter | laut aktueller Vercel-Preisseite prüfen | laut aktueller Cloudflare-Preisseite prüfen |
| **DSGVO-Aufwände** | AVV/DPA-Verfügbarkeit, Auftragsverarbeiter-Status, DatenverarbeitungsOrte | laut Vercel-Dokumentation prüfen | laut Cloudflare-Dokumentation prüfen |

> **Quellen-Disziplin:** konkrete Zahlen (Kosten, Bandbreitenlimits,
> DSGVO-Status) werden **nicht** aus kommerziellen Vergleichsseiten Dritter
> übernommen, sondern im PoC direkt gegen die offiziellen Preis- und
> Rechtsseiten von Vercel und Cloudflare verifiziert. Diese ADR enthält keine
> unbelegten Pauschalaussagen (wie „X % günstiger" oder „EU-freundlicher")
> zugunsten eines Anbieters.

### PoC-Auswertung

Das PoC-Ergebnis geht als Empfehlung in eine Folgedokumentation ein und wird dem
Nutzer als Entscheidung D4 vorgelegt. Bis dahin bleibt die Architektur
hosting-neutral.

---

## 9. Bootstrap-Schritte (Implementierung folgt nach Freigabe)

Diese Schritte sind **keine Implementierung**, sondern ein Vorschlag für die
Umsetzung nach Nutzerfreigabe.

1. **Projektgerüst:** `create-next-app` (App Router, TypeScript). Eigenes
   Verzeichnis, eigene `package.json`. Hosting-neutral (keine Vercel/CF-Bindung).
2. **PoCHosting (§8) parallel:** identische App auf Vercel und Cloudflare
   Workers (`@opennextjs/cloudflare`) deployen und messen.
3. **Supabase-Anbindung:** `@supabase/ssr` installieren,
   `createClient<Database>` mit generierten Typen [S22], EU-Frankfurt-Projekt.
4. **Design-Tokens:** `design-tokens.ts` und `tokens.css` aus
   `DESIGN_SYSTEM.md`; Traube/Zitrone semantisch, Zitronenregel (nur eine
   Primäraktion).
5. **Menü-Route:** statisch generierte `[venueSlug]/menu`-Seite, RLS-lesbar.
6. **Autoritative Bestellgrenze (§6):** Edge Function oder PostgreSQL-RPC mit
   Preis-, Verfügbarkeits-, Öffnungszeit-, Kapazitäts- und Idempotenzprüfung;
   `order-submit.ts` im Frontend ruft nur diese Grenze auf.
7. **ACK-Logik:** `order-ack.ts` — Status ausschließlich aus Server-Antwort;
   Offline-Pending-Status.
8. **Tests:** Vitest (Unit: ACK, Bestell-Submit, Warenkorb) + Playwright
   (E2E: QR → Bestellung).
9. **Sandbox-Banner:** sichtbares Sandbox-Label auf jeder Gast-Seite
   (Blueprint §20).
10. **Stage 2 (später, eigene Entscheidung):** PWA-Shell, Service Worker,
    Manifest — getrennt von der Beta.

---

## 10. Konsequenzen

### Positive Konsequenzen

- **Hosting-neutral:** Next.js läuft auf Vercel und Cloudflare Workers; die
  Entscheidung wird datengetrieben (§8) statt vorab getroffen.
- **Autoritative Bestellgrenze** schließt Preismanipulation und unkontrollierte
  Direkt-INSERTs aus dem Browser aus (Blueprint §6.3).
- **Klare Anonymitäts-Unterscheidung** zwischen `anon` und Anonymous Sign-in
  vermeidet RLS-Fehlkonfigurationen.
- **Phasentrennung:** die responsive Beta bleibt schlank; PWA-/Offline-Komplexität
  kommt erst später.
- **Typsicherheit End-to-End** durch generierte Supabase-Typen [S22][S23][S24].
- **EU-Region** für Supabase (Frankfurt, `eu-central-1`) [S25]; Frontend-Hosting
  EU-Fähigkeit wird im PoC gemessen.

### Negative Konsequenzen / Akzeptierte Nachteile

- **Adapter-Risiko bei Cloudflare:** `@opennextjs/cloudflare` ist eine
  Übersetzungsschicht; die Node.js-Kompatibilität in workerd kann Lücken
  aufweisen [S35]. Das PoC (§8) muß dies früh verifizieren. Vercel bleibt der
  Zero-Adapter-Fallback mit identischem Code.
- **Mehr serverseitiger Aufwand:** die autoritative Grenze (Edge Function/RPC)
  ist aufwändiger als direkte RLS-INSERTs, aber produktsprachlich erforderlich.
- **Zwei Build-Pipelines:** iOS (Xcode) und Web (npm/Next.js) erhöhen die
  Repository-Komplexität.
- **Hosting-Offenheit bindet Kapazität:** bis zur PoC-Entscheidung müssen beide
  Pfade kurzfristig nachverfolgt werden.

---

## 11. Offene Produktentscheidungen (dem Nutzer vorzulegen)

Diese ADR kann folgende Entscheidungen nicht selbst treffen und behält sie dem
Nutzer vor (DECISIONS.md-Governance):

| # | Entscheidung | Warum offen | Einfluss |
|---|--------------|-------------|----------|
| D1 | **Domain-Strategie** — Subdomain (`<venue>.kitchenlink.app`) oder Pfad (`kitchenlink.app/<venue>`)? | Produkt/Branding | DNS, SSL, QR-Generierung |
| D2 | **Anonyme Identität** — `anon`-Rolle (unauthenticated) oder Supabase Anonymous Sign-in (`authenticated` + `is_anonymous`)? Empfohlen wird letzteres (§6.3). | Datenschutz/Produkt | RLS-Policy-Design, GoBD |
| D3 | **Custom-Domain pro Restaurant** — darf ein Restaurant eine eigene Domain zeigen? | Produkt/Vertrieb | Hosting-Konfiguration, SSL |
| D4 | **Hosting-Wahl nach PoC** — Vercel oder Cloudflare Workers (§8)? | Kosten/DX/DSGVO | Hosting-Provider |
| D5 | **PWA-/Offline-Shell (Stage 2)** — wird sie gebaut, und wie tief (nur Shell oder auch Menüdaten)? | Datenschutz/Performance | Service-Worker-Strategie |
| D6 | **Bestellgrenze: Edge Function oder RPC** — welche Implementierungsvariante aus §6.2? | Architektur | Supabase-Funktion vs. SQL |

---

## 12. Compliance- und Sicherheitsnotizen

- **RLS muß auf allen Tabellen** des exponierten `public`-Schemas aktiv sein
  [S20]. Die `anon`-Rolle darf nur über explizite, restriktive Policies lesen.
- **Kein direkter Schreibzugriff** aus dem Browser auf Bestelltabellen; alle
  Bestellungen laufen durch die autoritative Grenze (§6).
- **Service-Role / `ctx.supabaseAdmin`** nur server-seitig in der Edge
  Function/RPC, niemals im Browser [S38].
- **Supabase EU-Region Frankfurt** (`eu-central-1`) für produktive Projekte
  [S25].
- **DPA** mit Supabase abschließen, bevor produktive Personendaten fließen [S26].
- **Hosting-DPA:** mit dem gewählten Hosting-Anbieter (nach §8) ebenfalls.
- **Sandbox-Banner** auf jeder Gast-Seite, solange nicht produktiv freigegeben
  (Blueprint §20).
- **Keine echten Zahlungen** bis zur Payment-Freigabe (DECISIONS.md).
- **Keine externen Font-/Farbdienste zur Laufzeit** (DESIGN_SYSTEM.md §11).

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
- **Produkt-Blueprint §6.3**: die autoritative Bestellgrenze (§6) setzt die
  Annahmeprüfung produktsprachlich um.
