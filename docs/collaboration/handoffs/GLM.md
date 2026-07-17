# Handoff — GLM (KL-WEB-002 Bestellgrenze)

**Datum:** 17. Juli 2026
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/guest-web-order-gate` (von aktuellem `main`)
**Ticket:** KL-WEB-002 — autoritative Bestellgrenze, RLS, Anonymous Sign-in
**Status:** Vollständig umgesetzt und verifiziert (typecheck/lint/test/build grün);
committet und gepusht. Bereit für Review.

> Dieses Handoff ersetzt den vorherigen KL-OFFLINE-003-Eintrag auf diesem
> Branch. KL-OFFLINE-003 bleibt unter `docs/architecture/offline/EVENT_LOG_V2.md`
> auf `main` erhalten.

## Kontext

Umsetzung von ADR-001 §6 (autoritative Bestellgrenze) und §6.3 (anon-Rolle vs.
Supabase Anonymous Sign-in), wie vom Nutzer freigegeben (DECISIONS.md, Guest
Web). Vorheriger Stand: statisch generierte Gastkarte auf lokaler Fixture, keine
Supabase-Anbindung, keine Bestellübermittlung, und **keine RLS auf irgendeiner
Tabelle** (jede Tabelle unter dem Anon-Key offen). Hinweis: ADR-001 lag zu
Beginn nur auf dem nie gemergten Branch `glm/guest-web-architecture`; der Nutzer
hat das behoben und ADR-001 + SOURCES.md (Revision 2) auf `main` gemergt, so
dass §6/§6.3 in meinem Arbeitsbaum vorlagen.

## D6-Entscheidung (Implementierungsdetail, keine Produktdisktion)

Gewählt: **Option B — PostgreSQL `SECURITY DEFINER` RPC** statt Edge Function.
Begründung detailliert in `docs/architecture/guest-web/ORDER_GATE.md` §2: gesamte
Logik in der additiven SQL-Migration (mein exklusiver Schreibbereich), kein
zweiter Laufzeit-Typ, keine clientseitige Service-Role-Secret-Handhabung,
Idempotenz nativ über Unique-Constraint + Hash, „Persistierung erst bei Erfolg"
in einer Transaktion. Die komplexere Ablaufsteuerung bleibt in getestetem
TypeScript.

## Umgesetzte Dateien (alle im exklusiven Schreibbereich)

- `supabase/migrations/20260717120000_guest_web_order_gate.sql` (neu, additiv;
  `20260318011000_kitchenlink_core_schema.sql` unangetastet):
  - Sandbox-Seed deckungsgleich mit `guest-web/src/lib/venue-data.ts`
    (1 Venue, 1 Menü, 2 Kategorien, 8 `menu_items` mit identischen Preisen;
    feste UUIDs, `on conflict` idempotent).
  - `orders.idempotency_key` + `unique(venue_id, idempotency_key)` +
    `orders.idempotency_payload_hash` + `orders.created_by`; `menu_items.slug`.
  - **RLS aktiviert** auf venues, menus, menu_categories, menu_items, orders,
    order_items (vorher: keine). Menü öffentlich lesbar (anon + authenticated);
    orders/order_items ohne direkte Schreib-Policies; orders Eigen-Lese-Policy
    `created_by = auth.uid()`.
  - RPC `public.guest_web_submit_order` (`SECURITY DEFINER`, fixierter
    `search_path`): Anonymous-Identitäts-Check (`auth.uid()`, JWT
    `is_anonymous`), Venue-Lookup über Slug, `FOR UPDATE` auf menu_items,
    serverseitige Neubepreisung aus `price_cents`, Ablehnung fremder/inaktiver
    Items, Idempotenz-Prüfung (gleich+gleich=Replay; gleich+anders=Konflikt),
    atomarer INSERT orders+order_items, ACK-Rückgabe. `revoke` von public/anon,
    `grant execute` nur an authenticated.
- `guest-web/src/lib/order-ack.ts` (neu): reine ACK-Logik, `toOrderAck`,
  `SubmitUiState`. Status ausschließlich aus Serverantwort, nie optimistisch.
- `guest-web/src/lib/order-submit.ts` (neu): `submitOrder` orchestriert
  Anonymous Sign-in + RPC; deterministischer Idempotenz-Key;
  Fehler-→Ergebnis-Mapping; `OrderBackend`-Schnittstelle (injizierbar für Tests).
- `guest-web/src/lib/order-backend-supabase.ts` (neu): Produktions-Backend mit
  echten `signInAnonymously()`- und `supabase.rpc('guest_web_submit_order')`-
  Aufrufen.
- `guest-web/src/lib/supabase-client.ts` (neu): Browser-Client aus
  `NEXT_PUBLIC_SUPABASE_*`.
- `guest-web/src/components/GuestMenuCard.tsx` (Datenverdrahtung, **Design
  unangetastet**): Bestellaktion im Sheet ruft `submitOrder`, Statuszeile zeigt
  ACK/Fehler/waiting aus Serverantwort. Sandbox-Banner + Kein-Echtgeld-Regel
  bleiben.
- `guest-web/src/app/globals.css`: zwei neue Klassen (`kl-sheet-actions`,
  `kl-primary-button`) im Sheet; Tokens/Layout/Controls unverändert.
- `guest-web/__tests__/order-ack.test.ts` (neu, 10 Tests),
  `guest-web/__tests__/order-submit.test.ts` (neu, 12 Tests).
- `guest-web/.env.example` (neu, keine Secrets) + `.gitignore`-Ausnahme
  `!.env.example`.
- `guest-web/package.json`/`package-lock.json`: `@supabase/supabase-js`.
- `docs/architecture/guest-web/ORDER_GATE.md` (neu): D6, RLS-Modell,
  Idempotenzvertrag, Simulationen, Teststand.

## Verifikation (in `guest-web/`)

- `npm run typecheck`: ✓ sauber.
- `npm run lint`: ✓ sauber (0 Probleme).
- `npm test` (Vitest): ✓ 40/40 Tests grün (5 Dateien; die 22 neuen Submit-/ACK-
  Tests plus die 18 bestehenden).
- `npm run build`: ✓ SSG erfolgreich, `/alte-muehle/menu` wird weiterhin statisch
  vorgerendert (Fixture erhalten).

## Menü-Fetch: Fixture bleibt (dokumentiert)

Die lokale Fixture `venue-data.ts` bleibt für Menüanzeige/SSG bestehen
(bewusste Naht aus KL-WEB-001, kein Redesign, kein Risiko). Der Supabase-Seed
existiert parallel, damit die RPC aus DB-Preisen rechnet. Ein späteres Ticket
tauscht nur `getVenueBySlug` gegen einen Supabase-Fetch. In ORDER_GATE.md §1
explizit festgehalten.

## Bewusst simulierte Teile

Öffnungszeit = „immer offen", Bestellkapazität = „unbegrenzt"; beide als
ausdrückliche Annahmen in der RPC kommentiert und in ORDER_GATE.md §5
dokumentiert. Generelle Sandbox-Regel: keine echten Zahlungen, keine
steuerlich gültigen Belege; Sandbox-Banner und Kein-Echtgeld-Regel bleiben.

## Restrisiken / Offenpunkte (ehrlich)

- **Keine echte RPC-Ausführung / kein RLS-Integrationstest.** In dieser
  Umgebung ist keine Supabase-Instanz verfügbar. Die Unit-Tests (mit Mock-
  Backend) beweisen die Verarbeitungslogik (Idempotenz-Key-Normierung,
  Fehler-Mapping, „kein falsches ACK"), **nicht** die PL/pgSQL-RPC, die
  `FOR UPDATE`-Sperre, die `raise exception`-Pfade, den Hash-Abgleich und
  **nicht** die RLS-Durchsetzung gegen echtes PostgreSQL. ORDER_GATE.md §7
  grenzt das explizit ab.
- **`signInAnonymously()` und der `is_anonymous`-JWT-Pfad sind verdrahtet,
  aber nicht gegen Supabase Auth gelaufen.**
- **Laufzeit ohne Instanz:** ohne `NEXT_PUBLIC_SUPABASE_*` liefert
  `submitOrder` strukturiert `no_backend` (kein falsches ACK); Menü/SSG laufen
  weiter. Ende-zu-Ende-Test braucht ein Sandbox-Supabase-Projekt mit
  angewendeter Migration + Anonymous-Sign-in.
- **Cleanup orphaned anonymous users** (DECISIONS.md Guest Web) noch nicht
  umgesetzt; betrifft das Supabase-Projekt, nicht diesen Code-Scope.
- **`npm audit`:** zwei moderate Findings in Dev-/Transitiv-Abhängigkeiten des
  Scaffolds (bereits aus KL-WEB-001 bekannt); Sandbox-unkritisch.
- **Annahme-Status `pending`:** erfolgreich persistierte Sandbox-Bestellungen
  erhalten `pending`; eine automatische `accepted`-Logik (Blueprint §6.3) ist
  nicht Teil dieses Tickets.

## Schreibbereich & Kollisionsfreiheit

Nur `guest-web/`, die neue additive Migration
`supabase/migrations/20260717120000_guest_web_order_gate.sql` (`20260318011000_…`
unangetastet), `docs/architecture/guest-web/ORDER_GATE.md` und diese Handoff-
Datei. Keine Berührung von PR-#7-/#8-Scopes, nichts außerhalb. `.zcode/` im
Repo-Wurzel liegt außerhalb meines Bereichs und wurde bewusst nicht committet.
Keine `DECISIONS.md`/`CURRENT.md`-Edits (keine neue Nutzerentscheidung; D6 ist
Implementierungsdetail, in ORDER_GATE.md begründet).

## Empfohlener nächster Schritt

Review von KL-WEB-002 (Peer oder Nutzer). Danach in getrennten Scopes:
Integrationstests gegen eine echte Supabase-Instanz, Menü-Fetch via Supabase,
Öffnungszeit-/Kapazitäts-Prüfungen, Vercel-Sandbox-Deployment.
