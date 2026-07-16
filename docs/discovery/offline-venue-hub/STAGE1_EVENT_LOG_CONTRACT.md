# Stage 1 Contract: Lokales Event-Log (SQLite / GRDB)

**Zweck:** Minimaler, atomarer, append-only Event-Store ohne Leader Election,
Replikation, Failover oder HTTP-Komponenten. Dies ist der einzige Teil der
GLM-Architektur, der derzeit ein bedingtes Go erhalten hat.

**Geltungsbereich:** Ausschließlich lokaler Speicher auf dem Hub-Gerät.
Kein Netzwerk, kein Transport, keine Synchronisation.

---

## 1. Verbindliche Prinzipien

1. **Ein Event gilt erst als dauerhaft gespeichert, wenn `sqlite3_step` für
   `COMMIT` erfolgreich war und SQLite das `SQLITE_DONE`-Resultat geliefert hat.**
   Erst dann darf ein ACK an den Absender gehen (§16.2 Blueprint).

2. **Event-Insert, Idempotenz-Eintrag und Outbox-Eintrag erfolgen in derselben
   SQLite-Transaktion.** Wenn einer der drei Schritte fehlschlägt, wird die
   gesamte Transaktion zurückgerollt.

3. **Schema-Version ist Teil der SQLite-Datenbank.** Die Version wird beim
   ersten `COMMIT` einer Migration atomar aktualisiert. Es gibt keine
   Schema-Erkennung über Fehler-String-Parsing.

4. **Kein willkürliches Snapshot- oder WAL-Checkpoint-Intervall.**
   (Begründung: siehe §9)

5. **Primärquelle für alle SQLite-Aussagen ist `sqlite.org`.**
   GRDB-spezifische Aussagen werden aus der GRDB-Dokumentation zitiert.

---

## 2. Tabellendefinitionen

### 2.1 `events` (append-only)

```sql
CREATE TABLE IF NOT EXISTS events (
    event_seq      INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    event_id       TEXT    NOT NULL UNIQUE,
    event_type     TEXT    NOT NULL,
    aggregate_id   TEXT    NOT NULL,
    aggregate_type TEXT    NOT NULL,
    venue_id       TEXT    NOT NULL,
    source_device_id TEXT  NOT NULL,
    payload_json   TEXT    NOT NULL,
    client_idempotency_key TEXT,
    created_at     TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_events_aggregate ON events(aggregate_id, event_seq);
CREATE INDEX idx_events_venue    ON events(venue_id, event_seq);
CREATE INDEX idx_events_type     ON events(event_type, event_seq);
```

**Begründung:**
- `event_seq` ist ein monoton steigender INTEGER PRIMARY KEY. SQLite garantiert,
  dass `AUTOINCREMENT` niemals eine Sequenznummer wiederholt (auch nach Rollback
  oder Löschung). Quelle: `https://sqlite.org/autoinc.html`
- `event_id` (TEXT) ist der ULID aus der GLM-Architektur – als UNIQUE-Constraint
  zusätzliche Sicherheit gegen Duplikate.
- `payload_json` (TEXT): JSON ohne Schema-Zwang. Die Interpretation erfolgt
  durch die Anwendung anhand von `event_type`. Kein JSON-Schema-Constraint in
  der DB (SQLite hat `json_valid()` ab 3.38.0, aber das wäre ein zusätzlicher
  Migrationsschritt).
- `created_at` als TEXT im ISO-8601-Format: SQLite hat keinen nativen
  Datetime-Typ. TEXT mit `strftime` ist portabel und sortierbar.
  Quelle: `https://sqlite.org/datatype3.html#date_and_time_datatype`
- Kein `signature`-Feld: HMAC ist Netzwerk-Authentizität, kein
  Event-Log-Contract. HMAC gehört in den Transport-Layer (§3).

### 2.2 `idempotency` (Deduplizierung)

```sql
CREATE TABLE IF NOT EXISTS idempotency (
    client_idempotency_key TEXT NOT NULL PRIMARY KEY,
    event_seq              INTEGER NOT NULL REFERENCES events(event_seq),
    created_at             TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
```

**Verhalten:**
- `INSERT OR IGNORE` auf `client_idempotency_key`. Bei Duplikat wird die
  vorhandene `event_seq` zurückgegeben – der Aufrufer erhält dieselbe Antwort
  wie beim ersten Mal (idempotent).
- Der `client_idempotency_key` muss vom externen Aufrufer gestellt werden
  (vom Gast-Browser, vom Staff-Gerät). Der Event-Log prüft nur, er erzeugt
  keine eigenen Keys.

### 2.3 `outbox` (Transactional Outbox)

```sql
CREATE TABLE IF NOT EXISTS outbox (
    outbox_seq   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    event_seq    INTEGER NOT NULL REFERENCES events(event_seq),
    target       TEXT    NOT NULL DEFAULT 'supabase',
    status       TEXT    NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'sending', 'sent', 'permanent_failure')),
    retry_count  INTEGER NOT NULL DEFAULT 0,
    last_error   TEXT,
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    sent_at      TEXT
);

CREATE INDEX idx_outbox_status ON outbox(status, outbox_seq);
```

**Verhalten:**
- `status = 'pending'`: noch nicht an Supabase gesendet
- `status = 'sending'`: aktuell im Übertragungsversuch (verhindert
  Doppelsendung durch parallele Sync-Aufrufe) – geprüft per `UPDATE outbox
  SET status = 'sending' WHERE status = 'pending' LIMIT 50` (GRDB-Transaktion)
- `status = 'sent'`: erfolgreich an Supabase übertragen; Bestätigung von
  Supabase (HTTP 200/201) liegt vor
- `status = 'permanent_failure'`: Supabase hat den Event abgelehnt (z.B.
  Validation Error) – erfordert manuelle Prüfung
- `retry_count`: wird bei jedem Fehlschlag inkrementiert; kein automatischer
  Abbruch bei Überschreitung (Entscheidung dem SyncCoordinator überlassen)

### 2.4 `schema_version` (Migrations-Tracking)

```sql
CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER NOT NULL PRIMARY KEY,
    description TEXT    NOT NULL,
    applied_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
```

**Migrationen** werden via GRDB `migrator` ausgeführt. Jede Migration ist eine
reine SQL-Transaktion. Die `schema_version` wird in derselben Transaktion
aktualisiert wie die Schema-Änderung:

```
migrator.registerMigration("v1_initial") { db in
    try db.execute(sql: CREATE TABLE events (...))
    try db.execute(sql: CREATE TABLE idempotency (...))
    try db.execute(sql: CREATE TABLE outbox (...))
    // schema_version wird automatisch von GRDB migrator gesetzt
}
```

Quelle: `https://swiftpackageindex.com/groue/GRDB.swift/main/documentation/grdb/migrations`

---

## 3. Atomic Append Contract

Der zentrale Vorgang: ein Event persistieren, Idempotenz prüfen und Outbox
vorbereiten – in einer Transaktion.

```
func appendEvent(_ event: VenueEvent) throws -> EventAppendResult {
    // 1. Prüfe client_idempotency_key in idempotency-Tabelle
    if let key = event.clientIdempotencyKey {
        if let existingSeq = try db.read { db in
            try IdempotencyRecord.fetchOne(db, key: key)?.eventSeq
        } {
            return .duplicate(eventSeq: existingSeq)
        }
    }

    // 2. Transaktion: Event + Idempotenz + Outbox
    let eventSeq = try db.write { db in
        // 2a. Event einfügen
        try event.insert(db)

        // 2b. Idempotenz-Eintrag (falls Key vorhanden)
        if let key = event.clientIdempotencyKey {
            try IdempotencyRecord(key: key, eventSeq: event.eventSeq).insert(db)
        }

        // 2c. Outbox-Eintrag
        try OutboxRecord(eventSeq: event.eventSeq, target: "supabase").insert(db)

        return event.eventSeq
        // COMMIT erfolgt beim Verlassen von db.write
    }

    // 3. Erst jetzt: ACK ist erlaubt
    return .accepted(eventSeq: eventSeq)
}
```

**Garantie:** Wenn `db.write` erfolgreich ist, sind alle drei Einträge
dauerhaft in SQLite geschrieben. Ein Absturz während `db.write` rollt die
Transaktion zurück – keine teilweise persistierten Events.

**Quelle:** `https://sqlite.org/atomiccommit.html` – SQLite garantiert
atomares Commit für einzelne Transaktionen.

---

## 4. Schema-Versionierung

### 4.1 Version 1 (initial)

```sql
-- Siehe §2 Tabellendefinitionen
-- GRDB migrator setzt schema_version auf 1
```

### 4.2 Zukünftige Migrationen

Jede Migration:
1. Ist eine reine SQL-Transaktion in einer GRDB-Migration
2. Ändert das Schema (ALTER TABLE, CREATE INDEX, etc.)
3. Wird atomar mit der schema_version-Aktualisierung committet
4. Hat einen eindeutigen Namen (z.B. `v2_add_event_signature`)
5. Wird von GRDB automatisch auf bereits migrierte Versionen geprüft

**Keine** Schema-Erkennung über Fehler-String-Parsing (wie im aktuellen
OrderRelayService `shouldFallbackToLegacySchema`). Die Version steht in der
Datenbank.

---

## 5. Replay / Recovery

### 5.1 Kaltstart (App-Start nach Beenden)

1. GRDB öffnet die Datenbank (`DatabasePool` oder `DatabaseQueue`)
2. GRDB führt alle ausstehenden Migrationen aus
3. Anwendung liest alle Events mittels `events ORDER BY event_seq ASC`
4. Anwendung replayt Events in Reihenfolge, um Aggregate-Zustand aufzubauen
5. Anwendung prüft Outbox auf `pending`-Einträge und startet SyncCoordinator

### 5.2 Replay nach Absturz

SQLite überlebt App-Abstürze:
- Während einer Transaktion: SQLite `journal`- oder `wal`-Datei enthält
  die unvollständige Transaktion. Beim nächsten Öffnen führt SQLite
  automatisch Recovery durch (Rollback der unvollständigen Transaktion).
- Quelle: `https://sqlite.org/howtocorrupt.html` – "SQLite is very robust.
  Applications that follow simple guidelines are very unlikely to experience
  database corruption."

Replay nach Absturz ist identisch zu Kaltstart: Events in Reihenfolge lesen,
Aggregate neu aufbauen, Outbox auf pending prüfen.

### 5.3 Wiederherstellung nach Datenverlust (Gerät defekt / gestohlen)

**Außerhalb des Stage-1-Contracts.** Datenverlust durch physischen
Geräteverlust oder Speicherdefekt ist nicht durch SQLite heilbar. Die
Wiederherstellung erfordert entweder:
- Cloud-Replikation (Stage 5 bei GLM)
- Synchrone Replikation auf zweites Gerät (nicht in Stage 1)

---

## 6. ACK-Regel

```
Event von externem Absender empfangen
  └→ appendEvent() aufrufen
       ├─ db.write() fehlschlägt → Fehler an Absender → KEIN ACK
       └─ db.write() erfolgreich
            └→ event_seq ist in SQLite committet
                 └→ ACK mit event_seq an Absender senden

Der Absender erhält das ACK erst, NACHDEM sqlite3_step(COMMIT) erfolgreich war.
Dies erfüllt Blueprint §16.2:
"Die App darf nie eine Bestellung als angekommen bestätigen,
 bevor mindestens ein autoritativer Venue-Knoten sie dauerhaft gespeichert hat."
```

---

## 7. Outbox-Verarbeitung (SyncCoordinator)

### 7.1 Lesen der Outbox

```sql
BEGIN;
SELECT * FROM outbox
WHERE status = 'pending'
ORDER BY outbox_seq ASC
LIMIT 50
FOR UPDATE;
```

`FOR UPDATE` sperrt die gelesenen Zeilen und verhindert, dass ein paralleler
SyncCoordinator dieselben Events liest (GRDB `DatabasePool` – nur ein Writer
zur Zeit, aber Sicherheit für zukünftige `DatabaseQueue`-Nutzung).

### 7.2 Senden an Supabase

Nach erfolgreichem HTTP-Request:

```sql
UPDATE outbox
SET status = 'sent', sent_at = strftime(...)
WHERE outbox_seq IN (...);
```

Bei Network-Error:

```sql
UPDATE outbox
SET retry_count = retry_count + 1,
    last_error = ?,
    status = 'pending'
WHERE outbox_seq IN (...);
```

Bei Supabase-Validation-Error (kein Network-Error):

```sql
UPDATE outbox
SET status = 'permanent_failure',
    last_error = ?,
    retry_count = retry_count + 1
WHERE outbox_seq IN (...);
```

### 7.3 Reihenfolgegarantie

Events werden **immer in aufsteigender `outbox_seq`-Reihenfolge** an Supabase
gesendet. Dies stellt sicher, dass die Reihenfolge der lokalen Events auch in
der Cloud erhalten bleibt. Ein Event wird erst als `sent` markiert, wenn das
vorherige `sent` ist (oder `permanent_failure` – in diesem Fall wird die
Sync-Pipeline blockiert und erfordert manuellen Eingriff).

---

## 8. Thread-Sicherheit

GRDB `DatabasePool` (WAL-Modus) erlaubt:
- **Mehrere gleichzeitige Reader** (uneingeschränkt)
- **Ein Writer zur Zeit** (weitere Writer warten)

Quelle: `https://github.com/groue/GRDB.swift#database-pools`

Der `appendEvent`-Vorgang verwendet `db.write`, das exklusiven Zugriff auf den
Writer erfordert. Alle Lesevorgänge (Replay, Outbox-Abfrage) verwenden
`db.read`.

**Kein zusätzliches Locking erforderlich.** GRDB serialisiert Write-Zugriffe
automatisch.

---

## 9. WAL-Checkpointing und Snapshotting

### 9.1 WAL-Checkpointing

GLM_ARCHITECTURE.md erwähnt kein Checkpointing. Der Stage-1-Contract enthält
kein willkürliches Intervall. Stattdessen:

- **SQLite WAL-Checkpoint-Modus:** `PRAGMA wal_autocheckpoint(1000)` (SQLite-
  Default). SQLite führt automatisch einen Checkpoint durch, wenn die WAL
  1000 Seiten erreicht (~4 MB bei 4KB-Seiten).
- Quelle: `https://sqlite.org/pragma.html#pragma_wal_autocheckpoint`
- **Gemessene Anpassung:** Nach ersten Lasttests (siehe §10) wird
  `wal_autocheckpoint` auf einen gemessenen Wert gesetzt, der WAL-Größe und
  Write-Performance optimiert. Kein willkürlicher Wert vor dem Test.

### 9.2 Snapshotting

Der GLM-Architektur zufolge soll der aktuelle Zustand durch Replay der
Events abgeleitet werden (§3.1: "Event Sourcing").

**Stage-1-Contract:** Replay beim Kaltstart ist der einzig garantierte
Mechanismus. Snapshots (materialisierte Aggregate-Zustände) sind optional und
dürfen erst eingeführt werden, wenn:

1. Eine gemessene Kaltstart-Zeit von >2s pro 1000 Events vorliegt (Ziel:
   Restaurant-Start in <1s bei einer 8h-Schicht mit ~500 Events)
2. Ein konkreter Snapshot-Mechanismus definiert ist:
   - `snapshots`-Tabelle mit `aggregate_id`, `aggregate_type`, `event_seq`
     (letztes verarbeitetes Event), `state_json`
   - Snapshot wird **nicht** nach willkürlicher Event-Anzahl erstellt, sondern
     nur bei explizitem Bedarf (z.B. vor dem Schließen der App) oder nach
     einer gemessenen Überschreitung der Replay-Zeit (z.B. >500ms)

---

## 10. Gemessene Grenzen (müssen vor Stage 2 ermittelt werden)

Folgende Werte sind keine Annahmen, sondern müssen auf Zielgeräten gemessen
werden:

| Messung | Erwarteter Bereich | Gerät |
|---|---|---|
| Maximale Write-IOPS (Events/s) auf iPad Pro M4 | TBD | iPad |
| Maximale Write-IOPS auf iPhone 15 | TBD | iPhone |
| Kaltstart-Replay-Zeit für 500 Events | TBD | iPad + iPhone |
| WAL-Größe nach 500 Events | TBD | iPad |
| Maximale Datenbankgröße bei 10.000 Events | TBD | iPad |
| `COMMIT`-Dauer unter Last (parallele Lese-Zugriffe) | TBD | iPad |
| WAL-Checkpoint-Dauer (Auto, 1000 Seiten) | TBD | iPad |

**Alle Messungen werden mit XCTest-Performance-Metriken auf echten Geräten
durchgeführt**, nicht auf Simulatoren.

---

## 11. Abgrenzung zu Stage 2+

| Feature | Stage 1 (dieser Contract) | Stage 2+ (GLM) |
|---|---|---|
| Event-Log | ✅ Atomarer Append | ✅ Erweitert |
| Idempotenz | ✅ client_idempotency_key | ✅ Gleich |
| Outbox | ✅ Transactional Outbox | ✅ SyncCoordinator |
| Schema-Version | ✅ GRDB-Migrationen | ✅ Gleich |
| Replay/Recovery | ✅ Kaltstart + Absturz | ✅ + Cloud-Recovery |
| HTTP-Server | ❌ Nicht enthalten | ❌ (No-Go) |
| Leader Election | ❌ Nicht enthalten | ❌ (No-Go) |
| SWIM-Gossip | ❌ Nicht enthalten | ❌ (No-Go) |
| Supabase-Sync | ❌ Nur Outbox-Tabelle | ✅ SyncCoordinator |
| Snapshots | ❌ Nur bei gemessener Notwendigkeit | ✅ Optional |

---

## 12. Primärquellen

| Thema | Quelle | Abruf |
|---|---|---|
| SQLite Atomic Commit | `https://sqlite.org/atomiccommit.html` | 2026-07-16 |
| SQLite WAL Mode | `https://sqlite.org/wal.html` | 2026-07-16 |
| SQLite AUTOINCREMENT | `https://sqlite.org/autoinc.html` | 2026-07-16 |
| SQLite Datatypes (TEXT für ISO8601) | `https://sqlite.org/datatype3.html` | 2026-07-16 |
| SQLite PRAGMA Statements | `https://sqlite.org/pragma.html` | 2026-07-16 |
| SQLite Robustness / Corruption | `https://sqlite.org/howtocorrupt.html` | 2026-07-16 |
| GRDB DatabasePool | `https://github.com/groue/GRDB.swift` | 2026-07-16 |
| GRDB Migrations | `https://swiftpackageindex.com/groue/GRDB.swift/main/documentation/grdb/migrations` | 2026-07-16 |
| GRDB Concurrency | `https://github.com/groue/GRDB.swift#database-pools` | 2026-07-16 |
| Transactional Outbox Pattern | `https://microservices.io/patterns/data/transactional-outbox.html` | 2026-07-16 |
