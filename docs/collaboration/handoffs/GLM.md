# Handoff — GLM (KL-OFFLINE-003 Event-Log-Prototyp)

**Datum:** 2026-07-16
**Agent:** GLM-5.2 via ZCode
**Ticket:** KL-OFFLINE-003 (siehe `docs/collaboration/PARALLEL_MISSIONS_2026-07-16.md`)
**Branch:** `glm/offline-event-log-v2`
**Worktree:** `/Users/test/Developments/kitchenlink-glm-eventlog`
**Status:** Ausführbarer, getesteter Referenzprototyp; `swift test` grün (35/35).

> Dieses Handoff ersetzt den früheren KL-MENU-001-Recherche-Eintrag auf diesem
> Branch. KL-MENU-001-Ergebnisse bleiben unter `docs/discovery/` auf `main`.

## Was in dieser Session erledigt wurde

Vollständige Umsetzung von KL-OFFLINE-003: ein eigenständiges Swift Package
`prototypes/KitchenLinkEventLog/`, das das autoritative lokale
KitchenLink-Ereignisprotokoll und seine Outbox als ausführbaren, getesteten
Referenzprototyp implementiert. Keine App-Abhängigkeit; SQLite direkt über das
systemseitige `SQLite3`-Modul.

### Umfang (Pflichtumfang aus der Mission, alle erfüllt)

- **Gültiges SQLite-Schema + Migrationen** (`EventLogSchema`): `events`,
  `aggregate_revisions`, `outbox`, `schema_meta`. Versioniert, idempotent,
  Downgrade-resistent. Kein `SELECT FOR UPDATE`.
- **WAL + dokumentierte Durability-Policy** (`SQLiteConnection`):
  `journal_mode=WAL`, `synchronous=FULL`, `fullfsync=ON`, `busy_timeout`,
  `foreign_keys=ON`. Kein Stromausfall-Behauptung, der nicht geliefert wird
  (§Durability in `EVENT_LOG_V2.md`).
- **Append in genau einer Transaktion** (`EventStore.append` über
  `connection.transaction { ... }`): Event + `aggregate_revisions`-Upsert +
  Outbox-Zeilen atomar. Pre-TX-Idempotenz-Check + in-TX-Recheck.
- **Idempotenz** über `(venue_id, idempotency_key, request_fingerprint)`:
  gleicher Request → dasselbe Event (`wasReplay`); anderer Payload unter
  gleichem Key → `idempotencyConflict`.
- **Vollständige Event-Felder:** Event-ID, monotone `local_seq`, Aggregate-ID
  und `-Revision, Eventtyp, `payload_version`, kanonischer Payload-BLOB,
  Device-ID, `occurred_at_ms`, `logged_at_ms`.
- **Outbox** mit `unique(event_seq, target)`, `pending/in_flight/acknowledged/
  failed`, Lease-Zeit, Versuchszahl, Backoff-Zeit und
  Wiederaufnahme abgelaufener Leases (`reclaimExpiredLeases`).
- **Atomisches Claiming ohne `UPDATE ... LIMIT`** (SELECT-Kandidaten + UPDATE
  pro PRIMARY KEY unter RESERVED-Sperre).
- **Autoritativer ACK erst nach erfolgreichem Commit**; HTTP-200-allein ist
  kein Persistenznachweis (`OutboxDispatcher` + `OutboxTransport`-Protokoll;
  `EVENT_LOG_V2.md` §ACK-Vertrag).
- **Deterministische Konflikte** bei konkurrierender Aggregate-Revision
  (`optimisticConcurrencyConflict`).
- **Fehler-Injektion** für Rollback/Retry, Reopen nach Commit (Crash/Reopen),
  parallele Duplikate, abgelaufene Lease, doppelten ACK und
  Payload-Schema-Replay — alles als ausführbare Tests.
- **35 aussagekräftige Tests, keine sleeps als Synchronisationslogik.**
  `FakeClock` steuert die Zeit explizit.

## Dateien (exklusiver Schreibbereich)

Neu in dieser Session:

- `prototypes/KitchenLinkEventLog/Package.swift`
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/SQLiteConnection.swift`
  (Low-level-Wrapper, WAL/Durability, `transaction { tx in }`)
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/EventLogSchema.swift`
  (Schema v1 + Migrationen)
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/Types.swift`
  (EventRecord, OutboxEntry, Fingerprint, Clock)
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/EventStore.swift`
  (Append, Idempotenz, Optimistic Concurrency, Reads)
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/Outbox.swift`
  (Claim, NACK, ACK, Lease-Recovery)
- `prototypes/KitchenLinkEventLog/Sources/KitchenLinkEventLog/Transport.swift`
  (OutboxTransport-Protokoll, OutboxDispatcher, InMemoryTransport)
- `prototypes/KitchenLinkEventLog/Tests/KitchenLinkEventLogTests/CoreTests.swift` (20)
- `prototypes/KitchenLinkEventLog/Tests/KitchenLinkEventLogTests/OutboxTests.swift` (15)
- `docs/architecture/offline/EVENT_LOG_V2.md` (Spezifikation)
- `docs/collaboration/handoffs/GLM.md` (dieses Update)

Keine Datei außerhalb des Schreibbereichs wurde berührt. Insbesondere wurden
keine App-Targets, keine `MenuImport/`-, keine Guest-Web-Dateien, keine
`DECISIONS.md` und keine `CURRENT.md` geändert.

## Verification

Befehl (aus `prototypes/KitchenLinkEventLog/`):

```bash
swift test
```

Ergebnis (aktuelles Toolchain: Swift 6.3.3, Xcode 26.6, SQLite 3.51.0):

```
Executed 35 tests, with 0 failures (0 unexpected) in 0.041 (0.041) seconds
```

- CoreTests: 20/20 (Schema/Migration, monotone Seq, Aggregate-Revision,
  Optimistic-Concurrency-Konflikt, Idempotenz-Replay, Idempotenz-Konflikt,
  Venue-Namespacing, Fingerprint-Determinismus, Outbox-Erzeugung,
  Metadaten-Erhaltung, Duplikat-Event-ID, CHECK-Constraint, WAL-Modus,
  Payload-Erhaltung, nil-expectedRevision).
- OutboxTests: 15/15 (Claim/Exklusivität, ACK-Übergang, Double-ACK-No-Op,
  ACK-mit-falschem-Lease, Lease-Recovery, NACK+Backoff+Retry,
  NACK-stale-No-Op, Dispatcher-Happy-Path, Dispatcher-Transient-Failure,
  Payload-Replay-Dedup, Crash/Reopen, parallele Duplikate, Backoff-Policy,
  Multi-Target-Unabhängigkeit).

Keine sleeps als Synchronisation; `FakeClock` advance/setNow steuert die Zeit.
Der Crash/Reopen-Test nutzt eine Datei-DB, schließt die Verbindung und öffnet
sie neu; Event und in_flight-Lease überdauern den Neustart.

SQLite/Swift-Aussagen wurden gegen Primärquellen geprüft (in
`EVENT_LOG_V2.md` §Quellen verlinkt): `BEGIN IMMEDIATE`/Isolation, WAL,
`PRAGMA synchronous`/`fullfsync`, `UPDATE...LIMIT`-Nicht-Standardität,
`WITHOUT ROWID`, Threadsafety, Bind-DESTRUCTOR, Upsert, CryptoKit-SHA256.

## Verbleibendes Risiko / Offenpunkte

- **Kein echter Stromausfallbeweis:** Der Prototyp nutzt
  `synchronous=FULL`+`fullfsync`, was SQLite-Dokumentation als sicherste
  Standardstufe ausweist, aber gegen harten Power-Loss bei verlogenen
  Schreib-Caches keine absolute Garantie ist. Der Prototyp behauptet diese
  Garantie nicht (§Durability). Ein echter Crash-Inject auf Storage-Ebene
  erfordert Kernel-/Hardware-Support und ist bewusst nicht Teil des Prototyps.
- **Single-Handle-Serialisierung:** Die Connection serialisiert über eine
  `DispatchQueue`. echter Multi-Writer-Multi-Thread-Parallelismus über mehrere
  Handles wird nicht multi-threaded getestet (WAL erlaubt es prinzipiell).
- **`Outbox.failed` ist nicht terminal:** Es gibt noch keine
  max-retries-Schranke mit Dead-Letter-Quarantäne. Eine spätere Policy sollte
  definieren, wann `failed` in ein unumkehrbares `dead` übergeht.
- **Keine Event-Kompaktion:** Das Protokoll wächst unbegrenzt;
  Snapshots/Tombstoning sind eine spätere Aufgabe.
- **UUID v4 statt v7:** `EventID()` generiert v4-UUIDs (universell in
  Foundation). UUIDv7 (time-ordered) wäre für Indexlokalität besser, ist aber
  in Foundation nicht direkt verfügbar und für die Prototyp-Invarianten nicht
  erforderlich.
- **iOS-Integration nicht freigegeben:** Das Package aktiviert nichts
  Produktives in der App. Die Integrationsnaht ist in `EVENT_LOG_V2.md` §12
  dokumentiert und bedarf einer separaten Nutzerfreigabe.

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `prototypes/KitchenLinkEventLog/`,
  `docs/architecture/offline/EVENT_LOG_V2.md` und dieses Handoff.
- Kein Produktions-/Domain-Code der App berührt.
- Keine `DECISIONS.md`- oder `CURRENT.md`-Änderung.
- Branch `glm/offline-event-log-v2` war sauber und wird fokussiert committet.

## Empfohlener nächster Schritt

Unabhängiges Review des Prototyps gegen die Acceptance-Gate-Kriterien der
Mission (`swift test` aus dem Package; keine App-/Domain-Datei geändert).
Danach kann die iOS-Integrationsnaht (`EVENT_LOG_V2.md` §12) als separater,
nutzerfreizugebender Milestone entworfen werden.
