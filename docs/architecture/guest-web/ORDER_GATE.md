# ORDER_GATE — Autoritative Bestellgrenze für das Gast-Web

**Stand:** 17. Juli 2026
**Ticket:** KL-WEB-002
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/guest-web-order-gate`
**Vorgaben:** [`ADR-001_GUEST_WEB_STACK.md`](./ADR-001_GUEST_WEB_STACK.md) §6 und §6.3,
`docs/collaboration/DECISIONS.md` (Guest Web), `docs/PRODUCT_BLUEPRINT.md` §6.3 und §16.2

Dieses Dokument beschreibt die technische Umsetzung der autoritativen
Bestellgrenze, des RLS-Zugriffsmodells, des Idempotenz-Vertrags, der bewusst
simulierten Teile und des Teststands. Es erfindet keine Produktentscheidung; die
D6-Entscheidung unten ist ein Implementierungsdetail, kein produktsprachlicher
Eingriff.

---

## 1. Was umgesetzt ist

- **Additive Migration**
  [`supabase/migrations/20260717120000_guest_web_order_gate.sql`](../../../supabase/migrations/20260717120000_guest_web_order_gate.sql).
  Die Basis-Schema-Datei `20260318011000_kitchenlink_core_schema.sql` bleibt
  unangetastet. Die Migration ist wiederholbar (idempotente Seed-INSERTs mit
  festen UUIDs und `on conflict`-Klauseln) und ausschließlich additiv.
- **Sandbox-Seed** deckungsgleich mit
  [`guest-web/src/lib/venue-data.ts`](../../../guest-web/src/lib/venue-data.ts):
  Venue `alte-muehle` („Gasthaus Alte Mühle"), ein Standard-Menü, zwei
  Kategorien (Küche/Getränke) und acht `menu_items` mit identischen
  `price_cents` (690/1150/1490/2180/2350/780/490/450). Die Client-IDs der
  Fixture (`kuerbissuppe` usw.) sind als `menu_items.slug` hinterlegt, damit
  die RPC Client-IDs serverseitig in DB-Preise auflöst.
- **`orders.idempotency_key`** (additiv) + **`unique(venue_id, idempotency_key)`**
  + **`orders.idempotency_payload_hash`** + **`orders.created_by`** (Bezug zum
  anonymen User für die Eigen-Lese-Policy). **`menu_items.slug`** als stabiler
  Bezeichner.
- **Row Level Security** aktiviert auf venues, menus, menu_categories,
  menu_items, orders, order_items (vorher: keine einzige Tabelle hatte RLS,
  jede war unter dem Anon-Key offen).
- **RPC `public.guest_web_submit_order`** als `SECURITY DEFINER` mit fixiertem
  `search_path`: die einzige Schreibstelle für Gastbestellungen.
- **Gast-Web-Verdrahtung:** `supabase-client.ts`, `order-ack.ts`,
  `order-submit.ts`, `order-backend-supabase.ts`; `GuestMenuCard.tsx` ruft beim
  Absenden `signInAnonymously()` + die RPC auf. Visuelles Design (Tokens,
  Layout, Controls) ist unangetastet — es ist eine Datenverdrahtung, kein
  Redesign.

### Wird die Gastkarte auf Supabase-Fetch umgestellt?

**Ja, ab KL-WEB-004.** Die Menüanzeige holt die Venue mit ihrem Menü aus
Supabase (`guest-web/src/lib/menu-loader.ts`), gerendert via ISR
(`revalidate = 60s`): die Seite bleibt statisch cachebar (CDN), aber
DB-Änderungen sind nach max. einer Minute sichtbar. Die lokale Fixture
`guest-web/src/lib/venue-data.ts` bleibt als **Build-Fallback** erhalten —
falls Supabase bei einem Hostinger-Rebuild nicht erreichbar ist, fällt die
Route auf die Fixture zurück, statt den Build rot werden zu lassen.

Die Bestellseite bleibt autoritativ: die RPC `guest_web_submit_order` rechnet
weiterhin **ausschließlich aus DB-Preisen** (`menu_items.price_cents`) und
vertraut dem Client nicht (ADR-001 §6.1). Damit Anzeige und Bestellung
konsistent sind, gilt in `menu-loader.ts` die Invariante
`GuestMenuItem.id = menu_items.slug` (nicht die UUID) — nur so findet
`order-submit.ts:cartToSubmitItems` denselben Slug, den die RPC auflöst.

Die Tag-Pills („beliebt", „vegetarisch") kamen ursprünglich nur aus der Fixture;
KL-WEB-004 ergänzt die `menu_items.tag`-Spalte, sodass sie auch aus der DB
kommen und beim Supabase-Fetch erhalten bleiben (Round-04-Visual-Review).

---

## 2. D6-Entscheidung: PostgreSQL `SECURITY DEFINER` RPC

**Gewählt: Option B — transaktionale PostgreSQL-RPC.**

Begründung:

- **Ein Schreibort, ein Sprungziel.** Die gesamte Bestelllogik lebt in der
  additiven SQL-Migration (mein exklusiver Schreibbereich). Es entsteht kein
  zweiter Laufzeit-Typ (kein Deno-Functions-Verzeichnis) und keine
  Service-Role-Secret-Handhabung im Anwendungscode — die Funktion läuft mit den
  Privilegien ihres Eigentümers, nicht mit einem clientseitig exponierten Key.
- **Idempotenz nativ.** `unique(venue_id, idempotency_key)` plus Payload-Hash
  werden in derselben Transaktion geprüft. Das erzwingt den Idempotenz-Vertrag
  bereits auf Constraint-Ebene, nicht nur im Anwendungscode.
- **„Persistierung erst bei Erfolg" wörtlich.** Preis-/Verfügbarkeitsprüfung
  mit `FOR UPDATE` und INSERT von orders + order_items laufen in einer
  Transaktion. Schlägt eine Prüfung fehl (`raise exception`), wird nichts
  geschrieben.
- **Kleine Angriffsfläche.** Genau ein kontrollierter Endpunkt mit fixiertem
  `search_path` (Supabase-Empfehlung gegen Schema-Spoofing), `revoke` vom
  `public`/`anon` und `grant execute` nur an `authenticated`.

**Akzeptierter Nachteil:** die Prüflogik steht in PL/pgSQL, nicht in
TypeScript. Für die eng umgrenzte, datenbanknahe Aufgabe (Lookup, Sperre,
Berechnung, INSERT) ist das angemessen; die komplexere Ablaufsteuerung
(Idempotenz-Key-Normierung, Fehler-→Ergebnis-Mapping, ACK-Zustände) liegt
weiterhin in getestetem TypeScript (`order-submit.ts`, `order-ack.ts`).

---

## 3. RLS-Zugriffsmodell

Vor dieser Migration war **keine** Tabelle durch RLS geschützt; jede war unter
dem Anon-Key offen. Jetzt gilt:

| Tabelle | `anon` | `authenticated` (anonymous user) | Service Role | Schreiben durch Gast |
|---|---|---|---|---|
| `venues` | SELECT ✓ | SELECT ✓ | voll | — |
| `menus` | SELECT ✓ | SELECT ✓ | voll | — |
| `menu_categories` | SELECT ✓ | SELECT ✓ | voll | — |
| `menu_items` | SELECT ✓ | SELECT ✓ | voll | — |
| `orders` | — | SELECT nur eigene (`created_by = auth.uid()`) | voll | **nur** über `guest_web_submit_order` |
| `order_items` | — | SELECT nur über eigene Bestellung | voll | **nur** über `guest_web_submit_order` |

Regeln:

- **Menü öffentlich lesbar.** `anon` und `authenticated` dürfen die Venue-Karte
  lesen. Das entspricht „Menü via RLS lesbar" (ADR-001 §6.3).
- **Keine direkten Schreib-Policies** auf orders/order_items. Es gibt bewusst
  keine INSERT/UPDATE/DELETE-Policies für die authentifizierte Rolle. Das
  Schreiben erfolgt ausschließlich über `guest_web_submit_order`
  (`SECURITY DEFINER`), die als privilegierter Eigentümer persistiert.
- **Die bloße `anon`-Rolle darf keine Bestellung anfassen.** Sie hat keinen
  `auth.uid()` und scheitert bereits am Identitäts-Check der RPC
  (`guest_web_unauthenticated`). `grant execute` geht nur an `authenticated`.
- **Gast liest nur den eigenen Status.** `orders_owner_read` erlaubt SELECT
  nur für `created_by = auth.uid()`; `order_items_owner_read` vererbt das über
  die zugehörige Bestellung. Ein Gast sieht also ausschließlich seine eigene
  Bestellung, nie die eines anderen.
- **`auth.jwt() ->> 'is_anonymous'`** wird in der RPC ausgewertet, nicht in
  einer Schreib-Policy. In dieser Sandbox akzeptiert die RPC auch dauerhaft
  authentifizierte Nutzer (z. B. Mitarbeiter-Tests); die gastseitige
  Verdrahtung verwendet ausschließlich Supabase Anonymous Sign-in
  (`signInAnonymously()`), wie in DECISIONS.md (Guest Web) freigegeben.

---

## 4. Idempotenz-Vertrag

Verbindlich (ADR-001 §6.1, §5.3):

| Fall | Verhalten |
|---|---|
| **Gleicher Key + gleicher Inhalt** | Die gespeicherte Order wird als **Replay** zurückgegeben (`idempotent_replay = true`), ohne neuen INSERT. Der Client bekommt dasselbe ACK. Doppelabgabe ist ausgeschlossen. |
| **Gleicher Key + anderer Inhalt** | Die RPC raisingt `guest_web_idempotency_conflict`. **Kein** stilles Überschreiben, **kein** neues ACK. Der Client erhält `idempotency_conflict`. |

Umsetzung:

- Der **Idempotenz-Key** wird clientseitig deterministisch gebildet
  (`buildIdempotencyKey`): aus Venue-Slug, Service-Mode, Customer-Note und den
  nach Slug sortierten Positionen. Gleicher Inhalt → gleicher Key, unabhängig
  von der Client-Reihenfolge. Eine Zeitkomponente ist bewusst **nicht**
  enthalten, sodass Netzwerk-Retries sicher idempotent sind.
- Der **Payload-Hash** (SHA-256 über Venue-ID, Key, Mode, Note, normierte
  Items) wird in der RPC deterministisch nachgerechnet und gegen
  `orders.idempotency_payload_hash` verglichen. So bleibt der Vertrag
  serverautoritativ, selbst wenn ein Client denselben Key mit anderem Inhalt
  schickt.
- Der **Unique-Constraint** `unique(venue_id, idempotency_key)` schützt
  zusätzlich vor Concurrent-Doppel-INSERTs (Race zwischen zwei gleichzeitigen
  Requests): der zweite Transaction-Teilnehmer scheitert am Constraint.

---

## 5. Bewusst simulierte Teile

| Aspekt | Simulierter Wert | Bemerkung |
|---|---|---|
| **Öffnungszeit** | „immer offen" | Es gibt keine Bestell-Öffnungszeiten-Prüfung. Die RPC nimmt Bestellungen zu jeder Zeit an. |
| **Bestellkapazität** | „unbegrenzt" | Es gibt keine Kapazitäts-/Stationsgrenze. Die RPC prüft keine Obergrenze pro Venue/Station. |
| **Annahme-Status** | `pending` | Eine erfolgreich persistierte Sandbox-Bestellung erhält den Status `pending`. Eine automatische `accepted`-Logik (Blueprint §6.3) ist nicht Teil dieses Tickets. |

Öffnungszeit und Kapazität sind in der RPC als ausdrückliche „immer offen,
unbegrenzt"-Annahmen markiert (Kommentar in der Migration). Die Druckstellen für
spätere echte Prüfungen sind vorhanden (Venue-Lookup, Artikel-Verfügbarkeit,
Preis-Neuberechnung); Öffnungszeit/Kapazität sind die nächsten, bewusst
offenbleibenden Felder.

Zudem gilt die generelle Sandbox-Regel (Blueprint §20, DECISIONS.md): keine
echten Zahlungen, keine steuerlich gültigen Belege. Das Sandbox-Banner und die
Kein-Echtgeld-Regel im Gast-Web bleiben erhalten.

---

## 6. Frontend-Verdrahtung (ADR-001 §7)

- **`order-ack.ts`** — reine ACK-Logik: Typen, `toOrderAck`, `SubmitUiState`.
  Status entsteht **ausschließlich aus der Serverantwort**, nie optimistisch.
  Der Zustand „submitting" ist ein eigener, eindeutig noch-nicht-bestätigter
  Zustand; es gibt keinen „optimistically accepted"-Fall (ADR-001 §5.3,
  Blueprint §16.2).
- **`order-submit.ts`** — orchestriert Anonymous Sign-in + RPC, normiert Items,
  bildet den Idempotenz-Key, wandelt Backend-Fehler in typisierte
  `SubmitResult`s um. Auth- und RPC-Aufrufe laufen über die injizierbare
  `OrderBackend`-Schnittstelle → reine Logik ist ohne echte Instanz testbar.
- **`order-backend-supabase.ts`** — Produktions-Backend: echte
  `signInAnonymously()`- und `supabase.rpc('guest_web_submit_order', …)`-Aufrufe.
- **`GuestMenuCard.tsx`** — die Bestellaktion im Sheet ruft `submitOrder`
  auf; die Statuszeile zeigt ACK/Fehler/waiting aus der Serverantwort. Das
  visuelle Design (Tokens, Layout, Controls, Zitronenregel) ist unangetastet;
  neu sind nur ein Primär-Button (Zitrone+Traube-Text gemäß §5,§9) und der
  Aktionsblock im Sheet.

---

## 7. Teststand

Ausgeführt in `guest-web/`:

| Schritt | Ergebnis |
|---|---|
| `npm run typecheck` | ✓ sauber |
| `npm run lint` | ✓ sauber (0 Probleme) |
| `npm test` (Vitest) | ✓ 40/40 Tests grün (5 Dateien) |
| `npm run build` | ✓ SSG erfolgreich, `/alte-muehle/menu` wird statisch vorgerendert |

### Was die Unit-Tests beweisen

- **`order-ack.test.ts` (10):** `toOrderAck` übersetzt nur gültige
  Serverantworten; lehnt Antworten ohne `order_id` oder mit `accepted=false` ab
  (kein falsches ACK); markiert idempotente Replays; `SubmitUiState` kennt
  keinen optimistisch-akzeptierten Zustand.
- **`order-submit.test.ts` (12):** Idempotenz-Key ist deterministisch und
  reihenfolgenunabhängig, unterscheidet sich aber bei anderer Menge;
  `backendErrorToResult` erkennt `idempotency_conflict`/`unknown_item`/
  `unavailable_item`/`unauthenticated` und fällt sonst auf `rpc_error`;
  `submitOrder` ruft `signInAnonymously` vor der RPC auf, bricht bei
  SignIn-Fehler ohne RPC ab, gibt das ACK aus der Serverantwort zurück und
  liefert `no_backend`, wenn kein Backend konfiguriert ist.

Alle Submit-/ACK-Tests verwenden einen **Mock-Backend**, nicht die echte
Supabase-Instanz. Sie beweisen die **Verarbeitungslogik**, nicht die Datenbank.

### Was die Unit-Tests NICHT beweisen (ehrliche Abgrenzung)

- **Keine echte RPC-Ausführung.** Die PL/pgSQL-Funktion
  `guest_web_submit_order` ist in dieser Umgebung nicht gegen eine laufende
  Supabase-Instanz gelaufen. Die serverseitige Neubepreisung, die
  `FOR UPDATE`-Sperre, die `raise exception`-Pfade und der Hash-Abgleich sind
  **nicht** durch einen Integrationstest abgedeckt. Sie sind sorgfältig
  geschrieben und kommentiert, aber unbewiesen gegen echtes PostgreSQL.
- **Keine RLS-Durchsetzungs-Tests.** Dass `anon` nicht in orders schreiben
  kann, dass `authenticated` nur die eigene Bestellung liest und dass die
  `SECURITY DEFINER`-Funktion als einziger Schreibpfad funktioniert, ist
  **Policy-Text**, nicht ein Laufzeit-nachgewiesenes Invariant.
- **Keine echte Anonymous-Sign-in-Prüfung.** `signInAnonymously()` und der
  `is_anonymous`-JWT-Pfad sind verdrahtet, aber nicht gegen Supabase Auth
  gelaufen.

### Laufzeitverhalten ohne Supabase-Instanz

Das ist für die Sandbox ausdrücklich in Ordnung: Ohne konfigurierte
`NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_ANON_KEY` liefert
`getSupabase()` `null`, `createSupabaseOrderBackend()` liefert `null`, und
`submitOrder` gibt strukturiert `no_backend` zurück — **kein falsches ACK**.
Die Menüanzeige und SSG laufen über die lokale Fixture weiter, unabhängig von
einer Instanz. Wer die Bestellung Ende-zu-Ende testen will, braucht ein
Sandbox-Supabase-Projekt mit angewendeter Migration und konfigurierter
Anonymous-Sign-in; das ist ein eigener, späterer Schritt (Vercel-Deployment
bzw. lokaler Supabase-Stack).

---

## 8. Offene Punkte und nächste Schritte (keine Produktdisktion)

- **Integrationstests** gegen eine echte Supabase-Instanz (RPC-Verhalten,
  RLS-Durchsetzung, Anonymous-Sign-in-Pfad) sind der größte offene
  Test-Bereich; siehe Abgrenzung oben.
- **Öffnungszeit/Kapazität** sind simulierte Felder (§5); echte Prüfungen sind
  ein Folgeticket.
- **Menü-Fetch via Supabase** ist mit KL-WEB-004 umgesetzt (ISR 60s, Fixture
  als Build-Fallback, `menu_items.tag` für die Pills). Cleanup orphaned anonymous users (DECISIONS.md Guest Web) ist noch nicht
  umgesetzt; betrifft das Supabase-Projekt, nicht diesen Code-Scope.
- **`npm audit`** meldet zwei moderate Findings in Dev-/Transitiv-Abhängigkeiten
  des Scaffolds; für die Sandbox unkritisch, vor Produktion zu prüfen
  (bereits in KL-WEB-001 notiert).
