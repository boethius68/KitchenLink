# KitchenLink Parallel Missions - 16 July 2026

These missions are intentionally disjoint from Claude's active work on
`KL-MENU-004` and the `KL-WEB-001` stack decision. Each model works in its own
worktree and branch. Do not edit another mission's write scope.

All agents must first read, in this order:

1. `AGENTS.md`
2. `docs/collaboration/CURRENT.md`
3. `docs/collaboration/DECISIONS.md`
4. `docs/PRODUCT_BLUEPRINT.md`
5. This mission file

Common constraints:

- KitchenLink remains an internal sandbox. Keep every demo and simulation path.
- Do not deploy, enable live payments or add secrets.
- Do not edit `docs/collaboration/DECISIONS.md`.
- Do not edit `docs/collaboration/CURRENT.md`; the integrator owns it.
- Do not touch `kitchenlink/Features/MenuImport/` or any guest-web stack files.
- Use primary sources for technical claims and link them directly.
- Commit and push the assigned branch. Update only the assigned handoff file.
- Report exact verification commands, results and unresolved risks.

## GLM 5.2 - KL-OFFLINE-003

**Branch:** `glm/offline-event-log-v2`
**Worktree:** `/Users/test/Developments/kitchenlink-glm-eventlog`
**Exclusive write scope:**

- `prototypes/KitchenLinkEventLog/`
- `docs/architecture/offline/EVENT_LOG_V2.md`
- `docs/collaboration/handoffs/GLM.md`

### Copy-ready prompt

```text
Bearbeite KL-OFFLINE-003 vollstaendig in deinem vorhandenen Worktree und Branch.
Du bist nicht allein im Repository. Veraendere oder revertiere nichts ausserhalb
deines exklusiven Schreibbereichs. Claude arbeitet parallel an KL-MENU-004 und
KL-WEB-001; diese Bereiche sind tabu.

Ziel ist kein weiteres Konzeptpapier, sondern ein ausfuehrbarer, getesteter
Referenzprototyp fuer das autoritative lokale KitchenLink-Ereignisprotokoll und
seine Outbox. Nutze ein eigenstaendiges Swift Package unter
prototypes/KitchenLinkEventLog/. Es darf SQLite direkt oder ueber eine im Package
klar deklarierte, begruendete Abstraktion verwenden, aber keine Abhaengigkeit in
die iOS-App einbauen.

Pflichtumfang:
- Gueltiges SQLite-Schema und Migrationen; kein SELECT FOR UPDATE.
- WAL plus explizite, dokumentierte Durability-Policy. Behaupte keinen
  Stromausfallschutz, den der Prototyp nicht nachweislich liefert.
- Append innerhalb genau einer Transaktion. Idempotenz ist mindestens durch
  venue_id + idempotency_key + request_fingerprint abgesichert: gleicher Request
  liefert dasselbe Ergebnis, anderer Payload unter gleichem Key muss als Konflikt
  scheitern.
- Event-ID, monotone lokale Sequenz, Aggregate-ID und -Revision, Eventtyp,
  payload_version, kanonischer Payload, Device-ID und Zeitstempel.
- Outbox mit unique(event_seq, target), pending/in_flight/acknowledged,
  Lease-Zeit, Versuchszahl, Backoff-Zeit und Wiederaufnahme abgelaufener Leases.
- Atomisches Claiming ohne UPDATE ... LIMIT-Annahme.
- Autoritativer ACK erst nach erfolgreichem Commit; HTTP 200 allein ist kein
  Persistenznachweis.
- Deterministische Konflikte bei konkurrierender Aggregate-Revision.
- Fehler-Injektion fuer Rollback, Reopen nach Commit, parallele Duplikate,
  abgelaufene Lease, doppelten ACK und Payload-Schema-Replay.
- Mindestens 20 aussagekraeftige Tests; keine sleeps als Synchronisationslogik.

EVENT_LOG_V2.md beschreibt Invarianten, Schema, Transaktionsgrenzen,
Zustandsautomat, ACK-Vertrag, Migrationsstrategie, Grenzen des Prototyps und die
spaetere iOS-Integrationsnaht. Pruefe jede SQLite-/Swift-Aussage an Primaerquellen.
Fuehre swift test aus. Committe und pushe. Aktualisiere nur handoffs/GLM.md mit
Dateien, Tests und Rest-Risiken. Wenn eine Anforderung technisch nicht haltbar
ist, belege das und liefere eine sichere Alternative statt sie zu simulieren.
```

### Acceptance gate

- `swift test` passes from the prototype package.
- Retry, crash/reopen, lease recovery and idempotency conflict behavior are
  executable tests, not prose examples.
- No app target or existing production/domain file changed.

## DeepSeek - KL-QA-002

**Branch:** `deepseek/offline-e2e-smoke`
**Worktree:** `/Users/test/Developments/kitchenlink-deepseek-e2e`
**Exclusive write scope:**

- `kitchenlinkTests/KitchenLinkOfflineOrderFlowTests.swift`
- `kitchenlinkTests/Support/OfflineOrderTestSupport.swift`
- `docs/test-plans/OFFLINE_ORDER_FLOW.md`
- `docs/collaboration/handoffs/DEEPSEEK.md`

### Copy-ready prompt

```text
Bearbeite KL-QA-002 vollstaendig in deinem vorhandenen Worktree und Branch. Du
bist nicht allein im Repository. Veraendere oder revertiere nichts ausserhalb
deines exklusiven Schreibbereichs. Produktionscode darf nicht angepasst werden.
Claude arbeitet parallel an KL-MENU-004 und KL-WEB-001; diese Bereiche sind tabu.

Schliesse die bekannte Testluecke fuer den bestehenden Sandbox-Pfad: eine
Gastbestellung muss ohne Cloudzugriff ueber die regulaere Repository-/Relay-
Domaene beim Owner ankommen, durch die Kuechenstatus laufen und nach einem
Neustart weiterhin vorhanden sein. Dies ist bewusst ein Regressionstest des
heutigen lokalen Demo-Backends und noch kein Beweis fuer den spaeteren Venue Hub.

Pflichtumfang:
- Zwei getrennte OrderRelayService-Instanzen fuer Gast und Owner, mit getrennten
  LocalDemoRepository-Instanzen auf demselben isolierten UserDefaults-Suite.
- Gast sendet eine echte LiveOrderMessage; Owner sieht pending.
- Gueltige Kette pending -> accepted -> preparing -> ready -> served wird ueber
  die vorhandene API ausgefuehrt und vom Gast-Tracker beobachtet.
- Ungueltige Uebergaenge werden abgelehnt, ohne den gespeicherten Zustand zu
  veraendern.
- Relay/Repository werden neu erzeugt; Bestellung, Positionen, Betrag, Tisch,
  Notiz und letzter Status bleiben erhalten.
- Abbruch und Neustart waehrend Polling/Tracking hinterlassen keine Tasks oder
  Testdaten fuer andere Tests.
- Deterministische Eventually-Helfer mit hartem Timeout; keine blinden Sleeps.
- Tabellengetriebene Abdeckung der erlaubten und verbotenen Statusuebergaenge.
- OFFLINE_ORDER_FLOW.md grenzt exakt ab, was getestet ist und was erst der echte
  SQLite-/Netzwerk-Venue-Hub beweisen kann.

Fuehre den neuen Test gezielt und danach die vollstaendige Unit-Suite auf einem
fest benannten Simulator aus. Falls die vorhandene API einen testbaren E2E-Lauf
wirklich verhindert, dokumentiere den kleinsten benoetigten Seam mit Beleg und
stoppe, statt Produktionscode ausserhalb des Scopes zu veraendern. Committe und
pushe. Aktualisiere nur handoffs/DEEPSEEK.md.
```

### Acceptance gate

- The focused test passes repeatedly without network access or timing flakes.
- The full unit suite remains green.
- The documentation does not present shared `UserDefaults` as a real venue hub.

## Kimi - KL-WORKFORCE-001

**Branch:** `kimi/workforce-domain`
**Worktree:** `/Users/test/Developments/kitchenlink-kimi-workforce`
**Exclusive write scope:**

- `kitchenlink/Features/Workforce/`
- `kitchenlinkTests/KitchenLinkWorkforceDomainTests.swift`
- `docs/domain/WORKFORCE_MODEL.md`
- `docs/collaboration/handoffs/KIMI.md`

### Copy-ready prompt

```text
Bearbeite KL-WORKFORCE-001 vollstaendig in deinem vorhandenen Worktree und
Branch. Du bist nicht allein im Repository. Veraendere oder revertiere nichts
ausserhalb deines exklusiven Schreibbereichs. Keine UI, Persistenz, Cloud oder
Benachrichtigungen. Claude arbeitet parallel an KL-MENU-004 und KL-WEB-001.

Baue die isolierte, produktionsfaehig testbare Swift-Domaenengrundlage fuer die
in PRODUCT_BLUEPRINT Abschnitt 9 verpflichtende Schichtplanung. Betriebsschicht,
geplante Arbeitsschicht und tatsaechlicher Zeiteintrag muessen getrennte
Fachobjekte bleiben.

Pflichtumfang:
- Mitarbeiterprofil, Venue-Zuordnung, Rollen, Qualifikationen und Stationen.
- Verfuegbarkeit, Abwesenheit, Schichtvorlage und geplante Schicht.
- Entwurf/Veroeffentlichung sowie Annahme, Ablehnung und Tauschanfrage als
  explizite Zustaende und validierte Uebergaenge.
- Sollbesetzung pro Station und erklaerbare Unterbesetzungswarnungen.
- Ein-/Ausstempeln, Pausen, Korrekturantrag, Freigabe und unveraenderbarer
  Audit-Eintrag als getrennte Zeiterfassungsobjekte.
- Validatoren fuer ungueltige Zeitraeume, Ueberschneidungen, genehmigte
  Abwesenheit, fehlende Qualifikation, Verfuegbarkeit, Stationsbesetzung und
  inkonsistente Pausen.
- Zeitzone explizit modellieren. Tests fuer Europe/Berlin, Uebernachtschichten
  und beide DST-Wechsel. Keine lokalzeitbasierte Dauerberechnung ohne Zeitzone.
- Deterministische Sandbox-Wochenfixture fuer ein Restaurant mit Service,
  Kueche und Bar.
- Codable, Equatable und Sendable soweit fachlich sinnvoll.
- Mindestens 25 fokussierte Tests, darunter Zustandsautomaten und Fehlerfaelle.

Keine gesetzlichen Arbeitszeitgrenzen hart codieren. Solche Regeln sind spaeter
konfigurierbare Policy und rechtlich zu pruefen. WORKFORCE_MODEL.md dokumentiert
Invarianten, Objektgrenzen, Zeitmodell, bewusst vertagte Policies und die spaetere
UI-/Persistenznaht. Fuehre die fokussierten Tests und die gesamte Unit-Suite aus.
Committe und pushe. Aktualisiere nur handoffs/KIMI.md.
```

### Acceptance gate

- The domain compiles in the app target without changing existing files.
- At least 25 deterministic tests pass, including DST and overnight cases.
- No legal rule is silently encoded as an immutable product decision.

## MiniMax - KL-INVENTORY-001

**Branch:** `minimax/inventory-domain`
**Worktree:** `/Users/test/Developments/kitchenlink-minimax-inventory`
**Exclusive write scope:**

- `kitchenlink/Features/Inventory/`
- `kitchenlinkTests/KitchenLinkInventoryDomainTests.swift`
- `docs/domain/INVENTORY_MODEL.md`
- `docs/collaboration/handoffs/MINIMAX.md`

### Copy-ready prompt

```text
Bearbeite KL-INVENTORY-001 vollstaendig in deinem vorhandenen Worktree und
Branch. Du bist nicht allein im Repository. Veraendere oder revertiere nichts
ausserhalb deines exklusiven Schreibbereichs. Keine UI, Persistenz, Cloud,
Buchhaltung oder Lieferanten-API. Claude arbeitet parallel an KL-MENU-004 und
KL-WEB-001.

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
Persistenznaht. Fuehre fokussierte Tests und die gesamte Unit-Suite aus. Committe
und pushe. Aktualisiere nur handoffs/MINIMAX.md.
```

### Acceptance gate

- The domain compiles without changing existing app files.
- At least 25 deterministic tests pass.
- Stock is always derived from ledger movements; no second mutable truth is
  introduced.
