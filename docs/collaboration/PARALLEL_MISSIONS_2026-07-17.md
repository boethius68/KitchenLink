# KitchenLink Parallel Missions - 17 July 2026

These missions are intentionally disjoint from Claude's active work (PR #7/#8
review). Each model works in its own worktree and branch, both already created
and pushed from the current `origin/main` (`433d70b`). Do not edit another
mission's write scope.

All agents must first read, in this order:

1. `AGENTS.md`
2. `docs/collaboration/CURRENT.md`
3. `docs/collaboration/DECISIONS.md`
4. `docs/PRODUCT_BLUEPRINT.md`
5. This mission file

Common constraints:

- KitchenLink remains an internal sandbox. Keep every demo and simulation path.
- Do not deploy, enable live payments or add secrets to the repository.
- Do not edit `docs/collaboration/DECISIONS.md`.
- Do not edit `docs/collaboration/CURRENT.md`; the integrator owns it.
- Do not touch `kitchenlink/Features/MenuImport/`, `kitchenlink/Features/Today/`,
  `kitchenlink/Features/Kitchen/` or files owned by another active mission.
- Use primary sources for technical claims and link them directly.
- Commit and push the assigned branch. Update only the assigned handoff file.
- Report exact verification commands, results and unresolved risks.

## GLM 5.2 - KL-WEB-002

**Branch:** `glm/guest-web-order-gate`
**Worktree:** `/Users/test/Developments/kitchenlink-glm-web`
**Exclusive write scope:**

- `guest-web/` (continuing the merged KL-WEB-001 foundation)
- new additive migration files under `supabase/migrations/` (the existing
  `20260318011000_kitchenlink_core_schema.sql` must not be edited; only new
  files that `alter table ... add column if not exists ...` or `create table
  if not exists ...`)
- `docs/architecture/guest-web/`
- `docs/collaboration/handoffs/GLM.md`

### Context you need before writing code

- `guest-web/` already has a statically generated `/[venueSlug]/menu` guest
  card (Next.js App Router) over a **local** sandbox fixture
  (`guest-web/src/lib/venue-data.ts`, one venue "Gasthaus Alte Mühle", 8
  items). It has no Supabase client and no order submission yet — the "order"
  button only opens a local summary sheet.
- The existing Supabase schema (`supabase/migrations/20260318011000_kitchenlink_core_schema.sql`)
  already has `venues`, `tables`, `menus`, `menu_categories`, `menu_items`,
  `qr_tokens`, `table_sessions`, `orders`, `order_items`. **There is currently
  no `idempotency_key` column and no Row Level Security at all** — every
  table is wide open under the anon key today (this is what the iOS app's
  `OrderRelayService` currently relies on). Your job includes closing this
  gap for the guest-web path, not just adding a function next to it.
- `docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md` (your own earlier
  work) already specifies the target shape in §6 (authoritative order gate)
  and §6.3 (Anonymous Sign-in vs. the bare `anon` role). The user approved
  Anonymous Sign-in specifically (`DECISIONS.md`, Guest Web).

### Goal

Implement ADR-001 §6 and §6.3 for real: a guest can place an order through
the existing guest card, the order is validated and persisted server-side —
never trusted from the client — and the guest sees "received" only after a
genuine server ACK.

### Required scope

- **Seed data:** an additive migration that inserts one sandbox venue and its
  8 menu items into the existing `venues`/`menu_items` tables, matching
  `guest-web/src/lib/venue-data.ts` in name and price. Decide and document in
  `docs/architecture/guest-web/ORDER_GATE.md` whether the guest-web menu route
  switches to fetching this from Supabase in this same ticket, or intentionally
  keeps the local fixture for now with the seed existing only so the order
  gate has real prices to validate against. Either is acceptable — just be
  explicit and give a reason.
- **Idempotency:** add `idempotency_key` (and any supporting unique
  constraint, e.g. `unique(venue_id, idempotency_key)`) to `orders` via a new
  additive migration file. A retried submission with the same key must return
  the same result; a different payload under the same key must fail as a
  conflict, not silently overwrite.
- **Authoritative order gate:** a Supabase Edge Function or a
  `security definer` PostgreSQL RPC (your choice, document the reasoning —
  this is ADR-001's open decision D6). It must, server-side and in one
  transaction:
  - re-price every line from `menu_items.price_cents`, never from the
    request body;
  - reject items that do not belong to the resolved venue or are inactive;
  - reject when the idempotency key conflicts as above;
  - insert into `orders`/`order_items` only on success and return the
    persisted order (id, status, total) as the ACK payload.
  - Opening-hours and capacity checks may be stubbed as "always open,
    unlimited capacity" for the sandbox, but say so explicitly in
    `ORDER_GATE.md` rather than silently omitting them.
- **Row Level Security:** enable RLS on `venues`, `menu_items`, `orders`,
  `order_items` (at least). `menu_items`/`venues` are readable by `anon` for
  the guest menu view. `orders`/`order_items` must not be writable directly by
  `anon` or by an authenticated-but-not-owning session — the only write path
  is the gate function/RPC (which runs with elevated privilege), and a guest
  may only *read* their own order status.
- **Supabase Anonymous Sign-in:** wire `supabase.auth.signInAnonymously()` in
  the guest-web app before order submission; the resulting `authenticated` +
  `is_anonymous` session is what RLS checks for the guest's own read access
  (`auth.jwt() ->> 'is_anonymous'`), per ADR-001 §6.3. Do not use the bare
  `anon` role for anything that touches an order.
- **Client wiring:** `guest-web/src/lib/order-submit.ts` (calls the gate,
  carries the idempotency key) and `guest-web/src/lib/order-ack.ts` (status
  comes only from the server response/poll, never optimistic), per ADR-001
  §7's proposed folder structure. The existing `GuestMenuCard.tsx` summary
  sheet should call this instead of just closing on "Zurück zur Karte" — but
  do not change its visual design (tokens, layout, controls); this is a data
  wiring change, not a redesign.
- **Sandbox banner and no-payment rule stay.** No live payment, no removal of
  sandbox labeling.

### Tests

- Vitest for `order-submit.ts`/`order-ack.ts` logic (idempotency key
  generation/reuse, ACK-only status transitions, error mapping).
- If you can run the gate function/RPC against a local Supabase instance,
  add a focused integration test for re-pricing and the idempotency conflict
  case. If that is not feasible in this environment, say so plainly in
  `ORDER_GATE.md` and document exactly what is proven by unit tests alone
  versus what still needs a real Supabase-backed test — do not claim
  coverage you do not have.

`ORDER_GATE.md` documents: the D6 choice and why, the RLS policies added and
their intended access model, the idempotency contract, what is stubbed
(opening hours/capacity), and what the tests do and do not prove.

### Copy-ready prompt

```text
Bearbeite KL-WEB-002 vollstaendig in deinem vorhandenen Worktree
(/Users/test/Developments/kitchenlink-glm-web) auf dem bereits gepushten
Branch glm/guest-web-order-gate (von aktuellem main erstellt). Du bist nicht
allein im Repository. Veraendere oder revertiere nichts ausserhalb deines
exklusiven Schreibbereichs: guest-web/, neue additive Migrationsdateien unter
supabase/migrations/ (20260318011000_kitchenlink_core_schema.sql bleibt
unangetastet), docs/architecture/guest-web/ und handoffs/GLM.md. Claude
arbeitet parallel am Review von PR #7 und PR #8; diese Bereiche sind tabu.

guest-web/ enthaelt bereits eine statisch generierte Gastkarte auf einer rein
lokalen Sandbox-Fixture (guest-web/src/lib/venue-data.ts). Es gibt noch keine
Supabase-Anbindung und keine Bestelluebermittlung. Die bestehende
Supabase-Schema-Datei hat schon venues/menu_items/orders/order_items etc.,
aber keinen idempotency_key und ueberhaupt keine Row Level Security - jede
Tabelle ist heute unter dem anon-Key offen. Das ist Teil deines Auftrags, nicht
nur eine Randnotiz.

Setze ADR-001 (docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md) Section
6 und 6.3 technisch um, so wie der Nutzer es freigegeben hat
(DECISIONS.md, Guest Web):

Pflichtumfang:
- Additive Migration: Sandbox-Venue + 8 Menue-Items in die bestehenden
  venues/menu_items-Tabellen einpflegen, deckungsgleich mit
  guest-web/src/lib/venue-data.ts. Dokumentiere in ORDER_GATE.md explizit, ob
  die Gastkarte in diesem Ticket auf Supabase-Fetch umgestellt wird oder die
  lokale Fixture vorerst bestehen bleibt.
- Additive Migration: idempotency_key auf orders plus Unique-Constraint
  (z.B. unique(venue_id, idempotency_key)). Gleicher Key + gleicher Inhalt =
  gleiches Ergebnis; gleicher Key + anderer Inhalt = Konflikt, kein stilles
  Ueberschreiben.
- Autoritative Bestellgrenze als Edge Function oder security-definer-RPC
  (deine Wahl, begruende sie als D6): serverseitige Neubepreisung aus
  menu_items.price_cents (nie aus dem Request), Ablehnung fremder/inaktiver
  Items, Idempotenz-Pruefung, Persistierung erst bei Erfolg, Rueckgabe der
  gespeicherten Order als ACK. Oeffnungszeit/Kapazitaet duerfen als
  "immer offen, unbegrenzt" simuliert werden, aber das muss explizit
  dokumentiert sein.
- Row Level Security auf venues, menu_items, orders, order_items aktivieren.
  Menue oeffentlich lesbar fuer anon; orders/order_items nur ueber die
  Bestellgrenze schreibbar, ein Gast darf nur seinen eigenen Bestellstatus
  lesen.
- Supabase Anonymous Sign-in im Gast-Web verdrahten (signInAnonymously vor
  der Bestellung); RLS prueft auth.jwt() ->> 'is_anonymous'. Die blosse
  anon-Rolle darf keine Bestellung anfassen.
- guest-web/src/lib/order-submit.ts und order-ack.ts nach ADR-001 §7; Status
  ausschliesslich aus der Serverantwort, nie optimistisch. Die bestehende
  GuestMenuCard.tsx ruft das beim Absenden auf, ihr visuelles Design
  (Tokens, Layout, Controls) bleibt unveraendert - das ist eine
  Daten-Verdrahtung, kein Redesign.
- Sandbox-Banner und Kein-Echtgeld-Regel bleiben.

Vitest fuer die Submit-/ACK-Logik. Wenn eine echte Supabase-Instanz fuer
Integrationstests hier nicht verfuegbar ist, sag das explizit in
ORDER_GATE.md und grenze klar ab, was die Unit-Tests beweisen und was nicht -
behaupte keine Abdeckung, die nicht existiert.

ORDER_GATE.md dokumentiert D6-Entscheidung und Begruendung, die RLS-Policies
und ihr Zugriffsmodell, den Idempotenz-Vertrag, bewusst simulierte Teile und
den Teststand. Fuehre npm run typecheck, npm run lint, npm test und npm run
build in guest-web/ aus. Committe und pushe. Aktualisiere nur handoffs/GLM.md
mit Dateien, Tests und Restrisiken.
```

### Acceptance gate

- `npm run typecheck`, `npm run lint`, `npm test`, `npm run build` all pass in
  `guest-web/`.
- The existing card's visual design (`GuestMenuCard.tsx`, `tokens.css`,
  `design-tokens.ts`) is unchanged except for the new submit/ack wiring.
- No table gets a client-writable path to `orders`/`order_items` other than
  through the gate function/RPC.
- The migration files are additive; the existing core schema file is
  untouched.

## MiniMax or DeepSeek - KL-INVENTORY-001

**Branch:** `minimax/inventory-domain` (rename to `deepseek/inventory-domain`
with `git branch -m` if DeepSeek picks this up instead — the worktree below
works either way)
**Worktree:** `/Users/test/Developments/kitchenlink-minimax-inventory`
**Exclusive write scope:**

- `kitchenlink/Features/Inventory/`
- `kitchenlinkTests/KitchenLinkInventoryDomainTests.swift`
- `docs/domain/INVENTORY_MODEL.md`
- `docs/collaboration/handoffs/MINIMAX.md` (or `handoffs/DEEPSEEK.md` if
  DeepSeek picks this up — update only the file matching whichever agent
  actually does the work)

This ticket was assigned to MiniMax once before and never delivered (no
branch, no commit existed on `origin`). The branch and worktree above are
freshly created from the current `main` (`433d70b`), which now includes the
merged guest-web foundation — unrelated to this ticket, but worth knowing the
base is current.

### Copy-ready prompt

```text
Bearbeite KL-INVENTORY-001 vollstaendig in deinem vorhandenen Worktree und
Branch. Du bist nicht allein im Repository. Veraendere oder revertiere nichts
ausserhalb deines exklusiven Schreibbereichs. Keine UI, Persistenz, Cloud,
Buchhaltung oder Lieferanten-API. Andere Agenten arbeiten parallel an
KL-WEB-002 und an Reviews; diese Bereiche sind tabu.

Baue eine isolierte Swift-Domaenengrundlage fuer die in PRODUCT_BLUEPRINT
Abschnitt 11 verpflichtende Warenwirtschaft. Ziel ist ein exakt testbarer
Bestandskern, nicht eine weitere Bildschirmattrappe.

Pflichtumfang:
- Zutaten, Verkaufsartikel-zu-Rezept-Zuordnung, Rezeptkomponenten, Lagerorte,
  Lieferant und optionaler Einkaufspreis als getrennte Fachobjekte.
- Dimensionssichere Mengen fuer Masse, Volumen und Stueck. Unterstuetze
  mindestens g/kg, ml/l und count; nutze Decimal und dokumentierte Rundung.
- Append-only Bestandsbewegungen fuer Wareneingang, Verbrauch, Verderb,
  Korrektur, Transfer, Reservierung, Freigabe und Storno/Gegenbuchung.
- Idempotenzschluessel fuer aus Bestellungen erzeugte Bewegungen. Wiederholung
  derselben Bestellung darf nie doppelt abbuchen; anderer Inhalt unter gleichem
  Schluessel muss als Konflikt scheitern.
- Rezeptaufloesung fuer mehrere Bestellpositionen und Mengen.
- Projektion von physischem, reserviertem und verfuegbarem Bestand je Lagerort.
- Erklaerbare Fehlbestandswarnung und Bestellvorschlag anhand konfigurierbarem
  Mindest-/Zielbestand; kein stilles Abschneiden negativer Werte.
- Transfers und Gegenbuchungen muessen referenziell ausgeglichen und gegen
  doppelte Umkehrung geschuetzt sein.
- Deterministische Sandbox-Fixture mit mindestens zehn Zutaten, vier Rezepten,
  zwei Lagerorten, Wareneingang, Verkauf, Verderb und Transfer.
- Codable, Equatable und Sendable soweit fachlich sinnvoll.
- Mindestens 25 Tests fuer Einheiten, Rundung, Idempotenz, Projektion,
  Reservierung, Rezeptverbrauch, Transfer, Gegenbuchung und Fehlbestand.

INVENTORY_MODEL.md dokumentiert Invarianten, Rundung, Ledger-Semantik,
Idempotenz, bewusst vertagte Bewertung/FIFO/Steuerfragen und spaetere
Persistenznaht. Fuehre die fokussierten Tests und die gesamte Unit-Suite aus.
Committe und pushe. Aktualisiere nur deine Handoff-Datei (MINIMAX.md oder
DEEPSEEK.md, je nachdem wer diesen Auftrag tatsaechlich ausfuehrt).
```

### Acceptance gate

- The domain compiles without changing existing app files.
- At least 25 deterministic tests pass.
- Stock is always derived from ledger movements; no second mutable truth is
  introduced.
