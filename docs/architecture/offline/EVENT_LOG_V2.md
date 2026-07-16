# KitchenLink Event Log v2 — Authoritative Local Log & Outbox

**Ticket:** KL-OFFLINE-003
**Branch:** `glm/offline-event-log-v2`
**Status:** Ausführbarer, getesteter Referenzprototyp (Swift Package)
**Datum:** 16. Juli 2026

Dieses Dokument beschreibt den Referenzprototyp für das autoritative lokale
KitchenLink-Ereignisprotokoll und seine Outbox. Es ist **kein** Konzeptpapier,
sondern die Spezifikation eines lauffähigen Swift-Package unter
`prototypes/KitchenLinkEventLog/`. Es ersetzt keine Produktionsfreigabe; die
Integration in die iOS-App ist eine spätere, getrennt freizugebende Naht (§iOS).

> **Statusgrenze:** Der Prototyp beweist die Invarianten und Zustandsautomaten
> lokal und deterministisch. Er behauptet keinen Stromausfallschutz, den er
> nicht nachweislich liefert (§Durability). Primärquellen für jede SQLite-
> und Swift-Aussage sind inline verlinkt und in §Quellen zusammengefasst.

---

## 1. Ziel und Nicht-Ziele

### Ziel

- Ein eigenständiges Swift Package, das das autoritative lokale Ereignisprotokoll
  für kritische Vorgänge (Bestellungen, Zahlungen, Kassenereignisse, Bestand)
  und eine Outbox für idempotente Zustellung an Ziele (Cloud, Peer-Geräte)
  implementiert.
- Das Protokoll ist append-only, deterministisch konfliktbehandelnd und
  crash-sicher im Rahmen der dokumentierten Durability-Policy.
- Alle Invarianten, Konflikte und Wiederanlaufpfade sind ausführbare Tests,
  keine Prosa.

### Nicht-Ziele

- Keine Abhängigkeit in die iOS-App (das Package hat keinen App-Bezug).
- Keine echte Netzwerk- oder Cloud-Anbindung; der Referenztransport ist
  deterministisch und in-Process.
- KeineBehauptung von Stromausfallschutz über das hinaus, was WAL +
  `synchronous=FULL` + `fullfsync` nachweislich liefern.
- Keine echte Mehrgeräte-Replikation; die Outbox modelliert die Zustellung,
  der Prototyp implementiert keinen P2P-Transport.

---

## 2. Invarianten

| # | Invariante | Durchsetzung |
|---|---|---|
| I1 | Das Ereignisprotokoll ist append-only. Keine `UPDATE`/`DELETE` auf `events` wird jemals vom Prototyp ausgeführt. | API bietet keinen Mutationspfad; Tests verifizieren Row-Count. |
| I2 | Genau eine Transaktion pro append. `events`, `aggregate_revisions` und `outbox` werden atomar committed. | `EventStore.append` nutzt `connection.transaction { ... }`. |
| I3 | `local_seq` ist monoton und eindeutig (PRIMARY KEY). | Schema `PRIMARY KEY (local_seq)`; `nextLocalSeqInTX` = `MAX+1`. |
| I4 | `aggregate_rev` ist 1-basiert und pro Aggregat streng monoton. | `aggregate_revisions.current_rev` + CHECK ≥ 0; Optimistic Concurrency. |
| I5 | Idempotenz: `(venue_id, idempotency_key, request_fingerprint)` ist eindeutig. Gleicher Request liefert dasselbe Event; anderer Payload unter gleichem Key scheitert als Konflikt. | UNIQUE-Index `idx_events_idempotency`; pre-TX-Check + in-TX-Recheck. |
| I6 | Kein `SELECT ... FOR UPDATE`. Schreibtransaktionen nutzen `BEGIN IMMEDIATE`. | Ref: [lang_transaction.html](https://www.sqlite.org/lang_transaction.html). |
| I7 | Die Outbox ist eine Projektion; sie referenziert `events`, editiert sie nie. | FK `event_seq REFERENCES events(local_seq) ON DELETE RESTRICT`. |
| I8 | Autoritativer ACK erst nach erfolgreichem Commit des Ziels; HTTP 200 allein ist kein Persistenznachweis. | `OutboxDispatcher.tick` ACKt nur bei `TransportResult.acknowledged`. |

---

## 3. Schema

### 3.1 `events` — das autoritative Protokoll

```sql
CREATE TABLE events (
    event_id            TEXT    NOT NULL,             -- UUID-String, client-generiert, global eindeutig
    local_seq           INTEGER NOT NULL,             -- monotone lokale Sequenz (1..)
    venue_id            TEXT    NOT NULL,
    aggregate_id        TEXT    NOT NULL,
    aggregate_type      TEXT    NOT NULL,
    aggregate_rev       INTEGER NOT NULL,             -- 1-basierte Revision nach diesem Event
    event_type          TEXT    NOT NULL,
    payload_version     INTEGER NOT NULL,             -- Schema-Version des Payload-BLOB
    payload             BLOB    NOT NULL,             -- kanonische, deterministisch kodierte Bytes
    request_fingerprint TEXT    NOT NULL,             -- SHA-256 (Hex) des kanonischen Requests
    idempotency_key     TEXT    NOT NULL,             -- client-seitig, eindeutig pro logischem Request
    device_id           TEXT    NOT NULL,
    occurred_at_ms      INTEGER NOT NULL,             -- fachliche Zeit (Domain)
    logged_at_ms        INTEGER NOT NULL,             -- lokale Persistenzzeit
    PRIMARY KEY (local_seq)
) WITHOUT ROWID;
```

Indizes:
- `idx_events_event_id` UNIQUE auf `event_id` — Lesezugriff + Duplikatschutz.
- `idx_events_idempotency` UNIQUE auf `(venue_id, idempotency_key, request_fingerprint)` — Idempotenz.
- `idx_events_aggregate` auf `(aggregate_id, aggregate_rev)` — Historie pro Aggregat.
- `idx_events_venue` auf `(venue_id, local_seq)` — Venu-weiter Lesezugriff.

`WITHOUT ROWID` macht `local_seq` zum echten Cluster-Key (keine verborgene
rowid). Ref: [withoutrowid.html](https://www.sqlite.org/withoutrowid.html).

### 3.2 `aggregate_revisions` — Optimistic-Concurrency-Cache

```sql
CREATE TABLE aggregate_revisions (
    aggregate_id    TEXT    NOT NULL,
    aggregate_type  TEXT    NOT NULL,
    venue_id        TEXT    NOT NULL,
    current_rev     INTEGER NOT NULL CHECK (current_rev >= 0),
    current_seq     INTEGER NOT NULL,
    PRIMARY KEY (aggregate_id)
) WITHOUT ROWID;
```

Ermöglicht O(1)-Konfliktprüfung. Wird in derselben Transaktion wie der
`events`-Insert per `INSERT ... ON CONFLICT DO UPDATE` gepflegt. Der
CHECK-Constraint verhindert negative Revisionen auf Datenebene.

### 3.3 `outbox` — Zustellungsprojektion

```sql
CREATE TABLE outbox (
    event_seq        INTEGER NOT NULL REFERENCES events(local_seq) ON DELETE RESTRICT,
    target           TEXT    NOT NULL,
    state            TEXT    NOT NULL DEFAULT 'pending'
                       CHECK (state IN ('pending','in_flight','acknowledged','failed')),
    attempts         INTEGER NOT NULL DEFAULT 0,
    lease_owner      TEXT,                              -- Token des aktuellen Claims; NULL bei pending
    lease_expires_ms INTEGER,                           -- Ablauf der in_flight-Lease; NULL bei pending
    next_attempt_ms  INTEGER,                           -- früherster nächster Versuch (Backoff)
    last_error       TEXT,
    ack_token        TEXT,                              -- bei erfolgreicher ACK gesetztes Token
    updated_at_ms    INTEGER NOT NULL,
    PRIMARY KEY (event_seq, target)
) WITHOUT ROWID;
```

Indizes:
- `idx_outbox_in_flight_lapsed` (partiell, `WHERE state = 'in_flight'`) auf
  `(state, lease_expires_ms)` — Lease-Recovery.
- `idx_outbox_pending` (partiell, `WHERE state IN ('pending','failed')`) auf
  `(state, next_attempt_ms)` — Dispatcher-Scan.

### 3.4 `schema_meta` — Migrationsversion

```sql
CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL) WITHOUT ROWID;
```

Speichert `version`. Ein Downgrade (`storedVersion > currentVersion`) wird
explizit zurückgewiesen, anstatt stillschweigend zu degraded.

---

## 4. Transaktionsgrenzen

Jede mutierende Operation läuft in **genau einer** Transaktion:

| Operation | Transaktionsinhalt |
|---|---|
| `EventStore.append` | pre-TX-Idempotenz-Reads (read-only) → `BEGIN IMMEDIATE` → in-TX-Recheck, `aggregate_revisions`-Read, `events`-Insert, `aggregate_revisions`-Upsert, `outbox`-Inserts → `COMMIT` |
| `Outbox.claim` | `BEGIN IMMEDIATE` → SELECT-Kandidaten (ORDER BY `next_attempt_ms` LIMIT n) → UPDATE pro PK auf `in_flight` → `COMMIT` |
| `Outbox.nack` | `BEGIN IMMEDIATE` → Read `attempts` → UPDATE (nur wenn `lease_owner` matcht) → `COMMIT` |
| `Outbox.ack` | `BEGIN IMMEDIATE` → Read `state` → UPDATE auf `acknowledged` (nur wenn `lease_owner` matcht) → `COMMIT` |
| `Outbox.reclaimExpiredLeases` | `BEGIN IMMEDIATE` → SELECT abgelaufene `in_flight` → UPDATE zurück auf `pending` → `COMMIT` |

**Warum `BEGIN IMMEDIATE`:** Es akquiriert die RESERVED-Sperre vorab, sodass
konkurrierende Schreiber deterministisch `SQLITE_BUSY` erhalten statt später
`SQLITE_BUSY_SNAPSHOT` unter einem deferred `BEGIN`.
Ref: [lang_transaction.html](https://www.sqlite.org/lang_transaction.html),
[isolation.html](https://www.sqlite.org/isolation.html).

**Kein `SELECT ... FOR UPDATE`:** SQLite bietet diese Syntax nicht an; die
Sicherheit entsteht durch die RESERVED-Sperre der gesamten Transaktion.

**Kein `UPDATE ... LIMIT`:** SQLite unterstützt `UPDATE ... LIMIT` nur, wenn
mit `SQLITE_ENABLE_UPDATE_DELETE_LIMIT` kompiliert ([lang_update.html
#update_limit](https://www.sqlite.org/lang_update.html#update_limit)), was
kein Standard ist. Der Prototyp verwendet stattdessen SELECT-Kandidaten +
UPDATE-by-PRIMARY-KEY, was portabel und row-reihenfolgenunabhängig ist.
(Hinweis: das lokale `sqlite3`-CLI 3.51.0 unterstützt LIMIT, aber iOS/macOS
SDK-Builds tun dies nicht verlässlich; der Prototyp verlässt sich nicht
darauf.)

---

## 5. Idempotät und Konflikte

### 5.1 Idempotät-Tripel

`(venue_id, idempotency_key, request_fingerprint)` ist der Idempotätschlüssel.

- **Gleicher Request (gleiches Tripel):** `append` liefert dasselbe Event
  zurück, `wasReplay == true`. Es wird keine zweite Zeile eingefügt.
- **Gleicher Key, anderer Payload (anderer Fingerprint):** scheitert als
  `AppendError.idempotencyConflict`. Der Prototyp simuliert niemals Erfolg.

### 5.2 Kanonischer Fingerprint

`request_fingerprint = SHA-256(canonical_input)` (Hex, 64 Zeichen). Kanonisch:
```
venue_id \n aggregate_type \n aggregate_id \n event_type \n payload_version \n payload-bytes
```

`idempotency_key` ist bewusst NICHT Teil des Fingerprints: der Key *benennt*
den logischen Request, der Fingerprint *beschreibt*, was der Request tut. So
kann der Store „gleicher Key, anderer Payload" als echten Konflikt erkennen.

Ref für SHA-256-Determinismus: Apple CryptoKit `SHA256.hash` ist eine reine
Funktion über die Eingabebytes.

### 5.3 Optimistic Concurrency (Aggregate-Revision)

`expectedRevision`-Semantik:
- `nil` — keine Prüfung; Revision auto-inkrementiert.
- `0` — das Aggregat darf noch nicht existieren (erstes Event).
- `N > 0` — `current_rev` muss genau `N` sein.

Bei Missverhältnis: `AppendError.optimisticConcurrencyConflict(aggregateID,
expected, actual)`. Deterministisch, da die Prüfung innerhalb der
RESERVED-locked Transaktion erfolgt.

---

## 6. Outbox-Zustandsautomat

```
                 claim()                       ack()
   pending ─────────────────► in_flight ─────────────────► acknowledged
      ▲                           │
      │ nack() / lease-recovery   │
      └───────────────────────────┘
                 │
                 ▼
             failed ──(claim nach backoff)──► in_flight
```

Zustände und Übergänge:

| Von | Nach | Aktion | Bedingung |
|---|---|---|---|
| pending | in_flight | `claim` | `next_attempt_ms <= now` |
| failed | in_flight | `claim` | `next_attempt_ms <= now` (nach Backoff) |
| in_flight | acknowledged | `ack` | `lease_owner` matcht |
| in_flight | failed | `nack` | `lease_owner` matcht; Backoff auf `next_attempt_ms` |
| in_flight | pending | `reclaimExpiredLeases` | `lease_expires_ms < now` |

**Claiming ist atomar und ohne `UPDATE ... LIMIT`:**
1. `SELECT event_seq, attempts FROM outbox WHERE target=? AND state IN ('pending','failed') AND next_attempt_ms <= ? ORDER BY ... LIMIT ?` — unter RESERVED-Sperre.
2. `UPDATE outbox SET state='in_flight', attempts=attempts+1, lease_owner=?, lease_expires_ms=? WHERE event_seq=? AND target=?` — pro PK.

Da die RESERVED-Sperre für die gesamte Transaktion gehalten wird, kann kein
zweiter Worker dieselben Zeilen zwischen SELECT und UPDATE klauen.

### 6.1 Backoff

`BackoffPolicy(baseMs, maxMs, multiplier)`. Default: 500 ms Basis, 60 s Max,
Faktor 2. `delayMs(forAttempt: n) = min(maxMs, baseMs * multiplier^(n-1))`.

### 6.2 Lease-Recovery

`reclaimExpiredLeases` findet alle `state='in_flight' AND lease_expires_ms < now`
und setzt sie zurück auf `pending` mit `last_error='lease_expired'` und einem
Backoff auf `next_attempt_ms`. `attempts` bleibt erhalten, sodass der nächste
Claim `attempts+1` ist.

---

## 7. ACK-Vertrag

> Der Transport darf `Outbox.ack` erst aufrufen, nachdem das Ziel das Event
> **dauerhaft** übernommen hat. Ein bloßer HTTP 200 ist **kein**
> Persistenznachweis.

Der Referenztransport `InMemoryTransport.deliver` gibt
`TransportResult.acknowledged(remoteToken:)` zurück, was im Prototyp
„dauerhaft übernommen" modelliert. Ein `Behavior.ackWithoutProof`-Flag
existiert, um den Fall „HTTP 200 ohne dauerhaften Beweis" zu demonstrieren;
der Dispatcher ACKt dennoch, aber der Vertrag dokumentiert, dass ein echter
Transport dies nicht tun darf.

ACK ist idempotent:
- Erster ACK → `.acknowledged(ackToken)`, Übergang `in_flight → acknowledged`.
- Zweiter ACK → `.alreadyAcknowledged(ackToken)` mit dem Original-Token, sicherer No-Op.
- ACK mit falschem/stale Lease-Token → `OutboxError.leaseNotOwned`. Der
  Transport darf Arbeit, die er nicht mehr hält, nicht ACKen.

---

## 8. Durability-Policy (ehrlich)

Der Prototyp konfiguriert pro Handle:

```sql
PRAGMA journal_mode = WAL;     -- nur für Datei-DBs; :memory: ignoriert es
PRAGMA synchronous  = FULL;    -- stärkste nicht-EXTRA-Stufe; sichert Commit
PRAGMA fullfsync    = ON;      -- macOS/iOS: erzwingt F_FULLFSYNC
PRAGMA busy_timeout = 5000;    -- kooperativ mit möglichen Peer-Writern
PRAGMA foreign_keys = ON;
```

**Was das nachweislich liefert:**
- Nach einem erfolgreichen `COMMIT` und Rückkehr aus `append`/`claim`/`ack`
  ist die Änderung gemäß SQLite-Dokumentation dauerhaft gegen
  *Anwendungsabbruch* und *sauberes Herunterfahren*.
- WAL + `synchronous=FULL` stellt sicher, dass der WAL-Frame vor Commit
  geschrieben wird. Ref: [wal.html](https://www.sqlite.org/wal.html),
  [pragma.html#pragma_synchronous](https://www.sqlite.org/pragma.html#pragma_synchronous).

**Was das NICHT garantiert (und vom Prototyp nicht behauptet wird):**
- Gegen *harten* Stromausfall oder Kernel-Panic kann selbst
  `synchronous=FULL` + `fullfsync` auf Geräten mit verlogenen Schreib-Caches
  Daten verlieren. Die einzige absolute Sicherheit wäre ein
  Battery-Backed-Cache oder ein alternatives Speichermedium. Der Prototyp
  simuliert diese Garantie nicht und behauptet sie nicht.
- Der Prototyp führt keinen echten Crash-Inject auf Storage-Ebene durch
  (das erfordert Kernel-/Hardware-Support). Der „Crash/Reopen"-Test
  (`testCrashReopenPreservesEventsAndOutbox`) schließt die Verbindung und
  öffnet die Datei neu; das beweist Persistenz über Prozessneustart, nicht
  über Stromausfall.

Ref: [forensics.html](https://www.sqlite.org/forensics.html),
[howtocorrupt.html](https://www.sqlite.org/howtocorrupt.html).

---

## 9. Migration

- Versioniert via `schema_meta.version`. Aktuell: `1`.
- `EventLogSchema.migrate(_:)` ist idempotent und läuft auf neuer wie
  bestehender Datenbank.
- Ein Downgrade (`storedVersion > currentVersion`) wirft
  `SchemaError.refuseDowngrade` — kein stilles Degradieren.
- künftige Versionen fügen diskrete `if storedVersion < N { applyVN(...) }`
  Blöcke hinzu. Jede Migration MUSS innerhalb einer Transaktion laufen;
  `applyV1` nutzt heute eine einzelne multi-statement `exec`.

---

## 10. Fehler-Injektion und Tests

Die Pflicht-Fehlerinjektionen sind ausführbare Tests (keine sleeps als
Synchronisation; `FakeClock` steuert die Zeit explizit):

| Szenario | Test | Mechanismus |
|---|---|---|
| Rollback nach fehlgeschlagener Zustellung | `testDispatcherTransientFailureThenRetry` | `InMemoryTransport.Behavior.failOnAttempt[1]` → nack → Backoff → Retry |
| Crash/Reopen (Prozessneustart) | `testCrashReopenPreservesEventsAndOutbox` | Datei-DB schließen, neu öffnen; Event + in_flight-Lease überdauern |
| Parallele Duplikate | `testParallelDuplicateAppendsCollapse`, `testIdempotentReplayReturnsSameEvent` | Gleiches Tripel → genau ein Event, `wasReplay` |
| Abgelaufene Lease | `testExpiredLeaseRecovery` | Lease ablaufen lassen → `reclaimExpiredLeases` → `pending` → re-claimbar |
| Doppel-ACK | `testDoubleAckIsSafeNoOp` | Zweiter ACK → `.alreadyAcknowledged`, sicherer No-Op |
| Payload-Schema-Replay | `testPayloadSchemaReplayDedup` | Gleiches Event-ID/Key/Fingerprint → Dedup, keine Outbox-Duplikation |
| ACK mit stale Lease | `testAckWithWrongLeaseRefused` | Falsches Lease-Token → `leaseNotOwned` |

**35 Tests** gesamt (20 Core, 15 Outbox), alle grün, 0 Failures.

---

## 11. Grenzen des Prototyps

1. **Single-Handle-Serialisierung:** Die Connection serialisiert Zugriff über
   eine serielle `DispatchQueue`. echter Multi-Writer-Parallelismus über
   mehrere Handles auf dieselbe Datei ist möglich (WAL erlaubt das), wird aber
   vom Prototyp nicht multi-threaded getestet; `busy_timeout` kooperiert mit
   möglichen Peers.
2. **Keine echte Replikation:** Die Outbox modelliert Zustellung; es gibt
   keinen echten Cloud- oder Multipeer-Transport.
3. **Kein Stromausfallbeweis:** siehe §8.
4. **Outbox `failed` ist noch nicht terminal-policiert:** Es gibt keine
   max-retries-Schranke mit Dead-Letter-Quarantäne. Eine spätere Policy sollte
   definieren, wann `failed` in ein unumkehrbares `dead` übergeht.
5. **Keine Event-Kompaktion/Tombstoning:** Das Protokoll wächst unbegrenzt.
   Snapshots/Kompaktion sind eine spätere Aufgabe.
6. **Payload ist opak (`Data`):** Der Prototyp kennt keine Payload-Semantik;
   Leser müssen `payload_version` selbst interpretieren.

---

## 12. iOS-Integrationsnaht (später, freizugeben)

Der Prototyp ist ein Swift Package ohne App-Bezug. Die spätere Integration:

- Package als Abhängigkeit in das KitchenLink-App-Target aufnehmen.
- Eine App-seitige Schicht (`EventLogCoordinator` o.ä.) bildet
  Domain-Operationen auf `AppendEventRequest` ab und liefert den kanonischen
  Payload (z. B. stabil sortiertes JSON).
- Ein produktiver `OutboxTransport` implementiert das Protokoll gegen
  Supabase/Cloud; der Dispatcher läuft als Hintergrund-Task.
- Die Datei-DB lebt im App-Sandbox-`Application Support`, eine DB pro Venue.
- Diese Integration ist ein eigener Milestone und bedarf einer separaten
  Nutzerfreigabe gemäß `DECISIONS.md`. Der Prototyp aktiviert nichts
  Produktives.

---

## 13. Quellen (Primär)

- SQLite C/C++ Interface — https://www.sqlite.org/c3ref/intro.html
- Transaction-Befehle (`BEGIN IMMEDIATE`) — https://www.sqlite.org/lang_transaction.html
- Isolation und Sperrmodell — https://www.sqlite.org/isolation.html
- WAL-Modus — https://www.sqlite.org/wal.html
- `PRAGMA synchronous` — https://www.sqlite.org/pragma.html#pragma_synchronous
- `PRAGMA fullfsync` — https://www.sqlite.org/pragma.html#pragma_fullfsync
- `UPDATE ... LIMIT` (nicht standardmäßig) — https://www.sqlite.org/lang_update.html#update_limit
- `WITHOUT ROWID` — https://www.sqlite.org/withoutrowid.html
- Autoincrement / monotone Keys — https://www.sqlite.org/autoinc.html
- Threadsafety (NOMUTEX) — https://www.sqlite.org/threadsafe.html
- In-Memory-DBs (Disjunktheit) — https://www.sqlite.org/inmemorydb.html
- Bind-Funktionen (TRANSIENT vs STATIC) — https://www.sqlite.org/c3ref/bind_blob.html
- Korruptions-/Forensik-Grenzen — https://www.sqlite.org/howtocorrupt.html
- Upsert (`ON CONFLICT DO UPDATE`) — https://www.sqlite.org/lang_conflict.html
- Apple CryptoKit `SHA256` — https://developer.apple.com/documentation/cryptokit/sha256
- Apple SQLite3-Modul — https://developer.apple.com/documentation/foundation/cgdatasourceref (SQLite3 in iOS/macOS SDKs)
