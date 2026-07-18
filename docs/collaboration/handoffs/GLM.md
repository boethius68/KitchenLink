# Handoff — GLM (KL-WEB-004 Menü aus Supabase)

**Datum:** 18. Juli 2026
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/web-menu-from-supabase` (von `origin/main`, `b0cb443`)
**Ticket:** KL-WEB-004 — Menü-Anzeige aus Supabase (ISR) statt lokaler Fixture
**Status:** Vollständig umgesetzt und verifiziert (typecheck/lint/test/build +
8/8 Integrationstests gegen echte Instanz); bereit für Review und Merge.

## Was dieser Strang tut

Schließt die Menü-Quell-Inkonsistenz aus KL-WEB-002/003: die Gastkarte holte
ihr Menü bisher aus der lokalen Fixture `guest-web/src/lib/venue-data.ts`,
während die Bestellung serverseitig aus der DB validiert wurde — DB-seitige
Menü-Änderungen wären im Live-Produkt unsichtbar gewesen. Die Fixture war in
KL-WEB-001 explizit als Naht für genau diesen Wechsel dokumentiert.

**Entscheidungen (mit Nutzer geklärt):** Rendering = **ISR `revalidate=60s`**
(minimalinvasive Abweichung von ADR-001 §3 „SSG+CDN"; Seite bleibt cachebar,
DB-Änderungen nach max. 1 min sichtbar). Tag-Pills = **additive
`menu_items.tag`-Spalte**, Seed gepflegt, damit das Round-04-visuelle Ergebnis
(„beliebt"/„vegetarisch") beim Supabase-Fetch erhalten bleibt.

## Umgesetzte Dateien (alle im exklusiven Schreibbereich)

- `supabase/migrations/20260719000000_menu_items_tag.sql` (neu, additiv):
  nullable `menu_items.tag`-Spalte + idempotente Updates für die 8 Sandbox-
  Items (deckungsgleich mit `venue-data.ts`). Angewendet auf die Remote-Instanz.
- `guest-web/src/lib/menu-loader.ts` (neu): Supabase-Lese-Schicht.
  `mapVenueRowToGuestVenue` (reiner Mapper, testbar) + `fetchVenueBySlugFromSupabase`.
  **Lastende Invariante: `GuestMenuItem.id = menu_items.slug` (nicht die UUID)** —
  `order-submit.ts:cartToSubmitItems` schickt `item.id` an die RPC, die über
  `menu_items.slug` auflöst. Filter: nur aktive Menüs, nur `available=true`.
- `guest-web/src/app/[venueSlug]/menu/page.tsx` (umgestellt): `revalidate = 60`,
  `dynamicParams = true`, `generateStaticParams` holt Slugs aus Supabase mit
  **Fallback auf Fixture** (Hostinger-Rebuild bei DB-Ausfall fällt nicht rot).
  `resolveVenue` probiert Supabase, fällt auf `getVenueBySlug` zurück.
- `guest-web/__tests__/menu-loader.test.ts` (neu, 10 Tests): reiner Mapper
  gegen Mock — beweist id=slug-Invariante, Tag-Übernahme, available-Filter,
  defensives Verwerfen ungültiger Items, Sortierung.
- `guest-web/__tests__/integration/menu-loader.integration.test.ts` (neu,
  4 Tests): echter Lese-Pfad gegen die Nutzer-Instanz — 8 Items ohne SignIn,
  korrekte DB-Preise, Tag-Pills, null bei unbekannter Venue. Skippt ohne
  `KL_INTEGRATION=1`.
- `docs/architecture/guest-web/ORDER_GATE.md`: §1 „Wird die Gastkarte auf
  Supabase-Fetch umgestellt?" aktualisiert (Ja, ab KL-WEB-004); offene Punkte
  korrigiert.
- `docs/collaboration/CURRENT.md`, `WORK_QUEUE.md`, dieses Handoff: KL-WEB-004
  eingetragen.

## Verifikation

- `npm run typecheck`, `npm run lint`: sauber.
- `npm test` (Unit): ✓ 50/50 (10 neue menu-loader + 40 bestehende).
- `KL_INTEGRATION=1 npm run test:integration`: ✓ 8/8 gegen die echte Instanz.
- `npm run build`: ✓ `next build` meldet `Revalidate 1m, Expire 1y` auf
  `/[venueSlug]/menu`, `/alte-muehle/menu` vorab generiert.

## Was bewusst NICHT getan wurde

- Kein SSR pro Request (ADR-001 §3 hält am SSG/CDN-Modell; ISR ist die
  minimalinvasive Variante).
- `venue-data.ts` wird **nicht gelöscht** — bleibt als Build-Fallback und für
  bestehende Unit-Tests (`cart.test.ts`, `order-submit.test.ts`,
  `venue-data.test.ts`), die alle weiterhin grün sind.
- Keine Menü-Editor-UI (operatorseitige `tag`-Pflege = eigenes Ticket).
- Keine Änderung an `order-submit.ts`/RPC (Bestellseite bleibt autoritativ).
- Keine neuen Tokens / kein visuelles Delta.

## Restrisiken / Offenpunkte

- **Build-Zeit-Abhängigkeit auf Supabase:** `generateStaticParams` versucht
  zur Bauzeit einen Supabase-Fetch; schlägt er fehl, fällt er auf die Fixture
  („alte-muehle") zurück. Der Build rotiert also nicht, aber bei DB-Ausfall
  werden zur Bauzeit nur die Fixture-Slugs vorab generiert (andere Slugs per
  ISR zur Runtime). Auf Hostinger sind die Env-Vars laut `SANDBOX_SETUP.md`
  gesetzt; kein akutes Risiko.
- **Tag-Spalte ist optional** — die meisten Artikel haben `NULL`. Das ist
  beabsichtigt (nur „beliebt"/„vegetarisch"); die Pflege erfolgt heute über
  Migrationen, eine UI fehlt noch.
- **Visuelle Identität nur per Test, nicht per Screenshot bewiesen** — die
  ISR-Seite sieht identisch aus (gleiche `GuestVenue`-Form), aber ein echter
  visueller Side-by-Side-Vergleich lokal-vs-DB steht noch aus. Der Nutzer
  macht den Live-Smoke-Test nach Merge.

## Schreibbereich & Kollisionsfreiheit

`guest-web/`, die neue additive Migration (`20260719000000_…`; die übrigen
Migrationen unangetastet), `docs/architecture/guest-web/ORDER_GATE.md`,
`docs/collaboration/CURRENT.md`, `WORK_QUEUE.md` und diese Handoff-Datei. Keine
Berührung von iOS-Code/PR-#7-#8-Scopen; nichts außerhalb. Keine
`DECISIONS.md`-Änderung (ISR-vs-SSG und tag-Spalte sind Implementierungsdetails
innerhalb der vom Nutzer freigegebenen ADR-001-Richtung).

## Empfohlener nächster Schritt

Review + Merge nach `main` → Hostinger auto-deploy → Live-Smoke-Test durch den
Nutzer (`kitchenlink.luneq.eu/alte-muehle/menu`: visuell identisch, aber nun
DB-gebunden; nach einer Menü-Änderung im Supabase-Dashboard max. 60s warten und
die Änderung live sehen).

---

# Vorheriger Strang: KL-WEB-003 (Gast-Web-Sandbox in Betrieb)

**Datum:** 18. Juli 2026
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/web-next` (von aktuellem `main`, `4f65ac2`)
**Ticket:** KL-WEB-003 — Gast-Web zur laufenden Sandbox (Deploy + echte Tests)
**Status:** Vollständig umgesetzt, gemergt (PR #10/#12/#13) und live.

> KL-WEB-002 (autoritative Bestellgrenze) ist zuvor gemergt worden
> (`1cfd253`, inkl. Claude-Review-Fix). Dieser Strang macht jene Logik
> lauffähig. Der alte `glm/guest-web-order-gate`-Branch war nach dem Merge
> divergiert und wurde auf Nutzerwunsch gelöscht; die Arbeit liegt vollständig
> auf `main`.

## Anlass und Entscheidung

Nachdem alle aktiven Tickets gemergt waren, hat der Nutzer als nächsten Strang
„Gast-Web deployen & echt testen" gewählt — die KL-WEB-002-Logik war nie gegen
eine echte Supabase-Instanz gelaufen und nicht deployt. Im Repo war dazu noch
nichts Konkretes angelegt (kein `config.toml`, keine Projektverknüpfung, keine
`.env`, keine Vercel-Konfig.; Secrets nirgends hartcodiert). Für das Hosting
wurde „Vercel jetzt vorbereiten" gewählt, bewusst **ohne** die Hosting-
Entscheidung D4 (ADR-001 §8 PoC) vorwegzunehmen.

## Umgesetzte Dateien (alle im exklusiven Schreibbereich)

- `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql`
  (neu, additiv): redefiniert `guest_web_submit_order` so, dass der INSERT in
  einen `EXCEPTION WHEN unique_violation`-Subblock eingebettet ist. Schließt
  das dokumentierte, nicht behobene Restrisiko aus KL-WEB-002: eine enge Race
  bei zwei gleichzeitigen Sendungen mit demselben Idempotenz-Key wird jetzt
  sauber auf Replay (gleicher Payload) bzw. Konflikt (anderer Payload)
  abgebildet, statt als generisches `rpc_error` nach oben zu reichen. Keine
  Tabellen-/Policy-Änderung; grants bleiben wie gehabt.
- `supabase/config.toml` (neu): Supabase-CLI-Initialisierung für `supabase
  link`/`db push`, ohne Secrets und ohne feste `project_id`.
- `guest-web/__tests__/integration/guest-web-submit-order.integration.test.ts`
  (neu): echte RPC-End-to-End-Tests (Anonymous Sign-in → Bestellung → ACK →
  Replay → Konflikt → RLS-Anon-Ablehnung). Skippt sauber, wenn keine Instanz
  konfiguriert ist (`KL_INTEGRATION=1` + Env-Variablen).
- `guest-web/vitest.config.ts`: `__tests__/integration/**` aus dem Unit-Run
  ausgeschlossen (Unit bleibt instanzfrei).
- `guest-web/vitest.integration.config.ts` (neu): eigene Config für
  Integrationstests (Timeout 30 s für echte Netz-Aufrufe).
- `guest-web/package.json`: `npm run test:integration` hinzugefügt.
- `guest-web/README.md`: Stand auf KL-WEB-003 korrigiert (Bestellgrenze ist da,
  nicht mehr „noch nicht enthalten"); Kommandos + „In Betrieb nehmen"-Verweis.
- `docs/architecture/guest-web/SANDBOX_SETUP.md` (neu): Schritt-für-Schritt-
  Leitfaden für den Nutzer — Supabase-Projekt (EU-Frankfurt), Anonymous-Sign-in
  aktivieren, drei Migrationen anwenden, `.env.local`, Vercel-Deployment,
  Integrationstests, Smoke-Check, Fehler-Checkliste.
- `docs/collaboration/WORK_QUEUE.md` (dieser Eintrag): KL-WEB-003 dokumentiert.

## Verifikation (in `guest-web/`)

- `npm run typecheck`: ✓ sauber.
- `npm run lint`: ✓ sauber (0 Probleme).
- `npm test` (Vitest Unit): ✓ 40/40 Tests (Integrationstests ausgeschlossen).
- `npm run test:integration`: ✓ skippt sauber (4 skipped) ohne konfigurierte
  Instanz — kein falsches Rot, kein falsches Grün.
- `npm run build`: ✓ SSG intakt, `/alte-muehle/menu` statisch vorgerendert.

## Was dieser Strang bewusst NICHT tut

- Keine Hosting-Entscheidung D4 (Vercel = erster Sandbox-Deploy; CF-PoC aus
  ADR-001 §8 bleibt offen). Keine `vercel.json`-Lock-in-Datei.
- Kein PWA/Offline-Shell (Stage 2, Entscheidung D5).
- Keine Menü-Fetch-Umstellung auf Supabase (Folgeticket; Fixture bleibt für
  SSG/Anzeige).
- Keine Secrets im Repo; kein Anlegen von Cloud-Ressourcen durch den Agent.

## Offen für den Nutzer (nicht für den Agent)

`SANDBOX_SETUP.md` führt Schritt für Schritt: Supabase-Projekt anlegen
(EU-Frankfurt), **Anonymous Sign-in aktivieren** (sonst scheitert jede
Bestellung), drei Migrationen anwenden (`supabase db push` oder SQL-Editor),
`guest-web/.env.local` befüllen (gitignore-geschützt), Repo in Vercel
verbinden mit `NEXT_PUBLIC_SUPABASE_*` als Env-Variablen. Ist die Instanz
konfiguriert, laufen `KL_INTEGRATION=1 npm run test:integration` echte Aussagen
(siehe `ORDER_GATE.md` §7 Abgrenzung).

## Update 18.07. (Abend): Echte Instanz steht — zwei RPC-Bugs gefunden und behoben

Der Nutzer hat ein Supabase-Sandbox-Projekt (Ref `rjxlzqtaxqstctrrlqre`,
EU-Region) angelegt, Anonymous Sign-in aktiviert und die drei Migrationen per
`supabase db push` angewendet. `.env.local` (gitignore-geschützt) liegt vor.
Erstmaliger Lauf `KL_INTEGRATION=1 npm run test:integration` gegen die echte
Instanz — und die Tests **fanden zwei echte Bugs in der gemergten KL-WEB-002-
RPC** `guest_web_submit_order`, die die Unit-Tests nicht finden konnten, weil
diese nie gegen echtes PostgreSQL liefen (genau die Abgrenzung aus
`ORDER_GATE.md` §7, jetzt mit Leben gefüllt):

1. **`digest()` nicht gefunden (SQLSTATE 42883).** Supabase installiert
   `pgcrypto` im Schema `extensions`, nicht `public`; der `search_path` der
   Funktion (`public, pg_temp`) schließt `extensions` nicht ein. Fix:
   schema-qualifizierter Aufruf `extensions.digest(...)` statt den `search_path`
   zu erweitern (sicherer gegen Schema-Spoofing).
2. **Mehrdeutige Spaltenreferenz `status`/`total_cents`/`currency` (SQLSTATE
   42702).** Die `SELECT ... INTO v_existing`-Blöcke referenzierten diese Namen
   ohne Tabellen-Alias, aber sie sind auch `RETURNS TABLE`-Spaltennamen der
   Funktion. Fix: Alias `o.` und `from public.orders o`.

Beide Fixes sind in die `20260718010000_…_race_fix.sql` eingeflossen (Header-
Kommentar dokumentiert sie) und wurden direkt auf die Remote-Instanz angewendet.
Danach: **4/4 Integrationstests grün** gegen die echte Instanz
(Anonymous Sign-in → Bestellung → ACK mit korrektem DB-Preis 690 → Idempotenz-
Replay → Konflikt bei geändertem Payload → RLS-Anon-Ablehnung).

**Konsequenz für `main`:** die dort gemergte KL-WEB-002-RPC (`20260717120000`)
enthält beide Bugs — ohne die Race-Fix-Migration `20260718010000` ist eine echte
Bestellung auf einer frischen Supabase-Instanz **nicht möglich**. Das ist kein
Merge-Blocker für KL-WEB-003 (die Race-Fix-Migration ist ja gerade Teil dieses
Strangs), aber `CURRENT.md`/`ORDER_GATE.md` sollten nach Integration darauf
hinweisen, dass die drei Migrationen nur zusammen lauffähig sind.

## Restrisiken / Offenpunkte (ehrlich)

- **Integrationstests laufen jetzt echt (4/4 grün)** gegen die
  Nutzer-Instanz. Was sie beweisen: RPC-Ausführung, serverseitige Neubepreisung,
  Idempotenz (seriell), Konflikt, RLS-Durchsetzung, Anonymous-Sign-in-Pfad. Was
  sie **nicht** beweisen: die echte *Concurrent*-Race (zwei gleichzeitige
  Requests mit demselben Key) — das wäre ein eigenes Last-Test-Szenario. Der
  serielle Replay- und der Konflikt-Test decken die Logik ab; die
  Unique-Constraint-Durchsetzung selbst ist Postgres-Standard.
- **Instanz ist ein echtes Cloud-Projekt des Nutzers** (kein Test-Fixture im
  Repo). Die Integrationstests sind nur mit dessen `.env.local` + `KL_INTEGRATION=1`
  reproduzierbar; CI würde sie ohne Secrets skippen. Das ist bewusst so.
- **`npm audit`:** unverändert zwei moderate Findings in Dev-/Transitiv-
  Abhängigkeiten des Scaffolds (KL-WEB-001 notiert); Sandbox-unkritisch.
- **Cleanup orphaned anonymous users** (DECISIONS.md Guest Web) noch nicht
  umgesetzt; Supabase-Projekt-Konfiguration, kein Code-Scope.

## Schreibbereich & Kollisionsfreiheit

`guest-web/`, `supabase/` (nur neue additive Dateien; bestehende Migrationen
unangetastet), `docs/architecture/guest-web/SANDBOX_SETUP.md`, dieser
`WORK_QUEUE.md`-Eintrag und diese Handoff-Datei. Keine Berührung von
PR-#7/#8-Scopes oder iOS-Code; nichts außerhalb. Keine `DECISIONS.md`/
`CURRENT.md`-Edits (keine neue Nutzerentscheidung; D4 bleibt dem Nutzer).
`.zcode/` im Repo-Wurzel liegt außerhalb meines Bereichs und wurde bewusst
nicht committet.

## Empfohlener nächster Schritt

Review von KL-WEB-003 (Peer oder Nutzer). Danach führt der Nutzer die
Account-Schritte aus `SANDBOX_SETUP.md` aus; sobald eine Instanz steht, laufen
die Integrationstests echte Aussagen und das Vercel-Deployment kann live
getestet werden. Erst danach: D4-Hosting-PoC (Vercel vs. Cloudflare Workers)
als eigenes Ticket.
