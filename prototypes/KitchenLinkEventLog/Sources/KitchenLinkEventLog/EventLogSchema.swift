import Foundation

// MARK: - EventLogSchema
//
// Versioned schema + migration runner for the KitchenLink authoritative local
// event log.
//
// Principles (see EVENT_LOG_V2.md §Schema):
//   * There is ONE append-only events table that is the source of truth.
//   * The outbox is a projection referencing events; it never edits an event.
//   * Idempotency is enforced by a UNIQUE index over
//     (venue_id, idempotency_key, request_fingerprint).
//   * Aggregate revisions are tracked in `aggregate_revisions` with a CHECK
//     constraint so that optimistic-concurrency conflicts are deterministic at
//     the data layer.
//   * We use AUTOINCREMENT on events.seq to keep the monotonic local sequence
//     monotonically increasing even across deletes of the highest row.
//     Ref: https://www.sqlite.org/autoinc.html
//
// NO `SELECT ... FOR UPDATE` is used anywhere. Write transactions are opened
// with `BEGIN IMMEDIATE`, which acquires a RESERVED lock; concurrent writers
// deterministically receive SQLITE_BUSY. Ref:
//   https://www.sqlite.org/lang_transaction.html
//   https://www.sqlite.org/isolation.html
//
public enum EventLogSchema {

    /// Current schema version. Bumped on every breaking change.
    public static let currentVersion: Int64 = 1

    /// Applies all migrations up to `currentVersion`. Idempotent: safe to call
    /// on an existing database; a `schema_meta` row records the applied
    /// version. If the stored version is higher than `currentVersion`, this
    /// throws (refuse to downgrade silently).
    public static func migrate(_ connection: SQLiteConnection) throws {
        try connection.exec("""
        CREATE TABLE IF NOT EXISTS schema_meta (
            key TEXT PRIMARY KEY,
            value INTEGER NOT NULL
        ) WITHOUT ROWID;
        """)

        let storedVersion: Int64
        if case .integer(let v) = try rawMeta(connection, key: "version", default: 0) {
            storedVersion = v
        } else {
            storedVersion = 0
        }
        guard storedVersion <= currentVersion else {
            throw SchemaError.refuseDowngrade(found: storedVersion, max: currentVersion)
        }
        if storedVersion == currentVersion { return }

        // --- Migration v1: initial schema ---------------------------------
        if storedVersion < 1 {
            try applyV1(connection)
        }

        try setMeta(connection, key: "version", value: currentVersion)
    }

    public enum SchemaError: Error, Equatable {
        case refuseDowngrade(found: Int64, max: Int64)
    }

    // MARK: - v1

    /// Initial schema. Column meanings are documented in
    /// EVENT_LOG_V2.md §Schema.
    private static func applyV1(_ connection: SQLiteConnection) throws {
        try connection.exec("""

        -- ----------------------------------------------------------------
        -- events: the authoritative append-only local event log.
        -- ONE row per accepted business event. Never UPDATEd or DELETEd.
        -- ----------------------------------------------------------------
        CREATE TABLE IF NOT EXISTS events (
            event_id          TEXT    NOT NULL,            -- UUID v7 string; client-generated, globally unique
            local_seq         INTEGER NOT NULL,            -- monotonic local sequence (1..)
            venue_id          TEXT    NOT NULL,
            aggregate_id      TEXT    NOT NULL,
            aggregate_type    TEXT    NOT NULL,
            aggregate_rev     INTEGER NOT NULL,            -- 1-based revision of this aggregate after this event
            event_type        TEXT    NOT NULL,
            payload_version   INTEGER NOT NULL,            -- schema version of the payload blob
            payload           BLOB    NOT NULL,            -- canonical, deterministically-encoded payload
            request_fingerprint TEXT  NOT NULL,            -- SHA-256 of canonical request (see Fingerprint)
            idempotency_key   TEXT    NOT NULL,            -- client-supplied; unique per logical request
            device_id         TEXT    NOT NULL,
            occurred_at_ms    INTEGER NOT NULL,            -- when the event logically occurred (domain time)
            logged_at_ms      INTEGER NOT NULL,            -- when the local log persisted it
            PRIMARY KEY (local_seq)
        ) WITHOUT ROWID;

        -- Natural key for reading events by id.
        CREATE UNIQUE INDEX IF NOT EXISTS idx_events_event_id ON events(event_id);

        -- Idempotency: same (venue, key, fingerprint) MUST map to the same
        -- event. A different payload under the same key+venue is a CONFLICT
        -- and the UNIQUE index will reject it (caught by the store as
        -- IdempotencyConflict).
        CREATE UNIQUE INDEX IF NOT EXISTS idx_events_idempotency
            ON events(venue_id, idempotency_key, request_fingerprint);

        -- Reading an aggregate's history in order.
        CREATE INDEX IF NOT EXISTS idx_events_aggregate
            ON events(aggregate_id, aggregate_rev);

        CREATE INDEX IF NOT EXISTS idx_events_venue
            ON events(venue_id, local_seq);

        -- ----------------------------------------------------------------
        -- aggregate_revisions: tracks the latest known revision + seq per
        -- aggregate, enabling O(1) optimistic concurrency checks. Maintained
        -- by the store inside the same transaction as the event append.
        -- ----------------------------------------------------------------
        CREATE TABLE IF NOT EXISTS aggregate_revisions (
            aggregate_id    TEXT    NOT NULL,
            aggregate_type  TEXT    NOT NULL,
            venue_id        TEXT    NOT NULL,
            current_rev     INTEGER NOT NULL CHECK (current_rev >= 0),
            current_seq     INTEGER NOT NULL,
            PRIMARY KEY (aggregate_id)
        ) WITHOUT ROWID;

        -- ----------------------------------------------------------------
        -- outbox: a projection of events that still need delivery to a
        -- target (e.g. cloud sync, or another device). One row per
        -- (event_seq, target) pair. Never the source of truth for events.
        -- ----------------------------------------------------------------
        CREATE TABLE IF NOT EXISTS outbox (
            event_seq       INTEGER NOT NULL REFERENCES events(local_seq) ON DELETE RESTRICT,
            target          TEXT    NOT NULL,
            state           TEXT    NOT NULL DEFAULT 'pending'
                                    CHECK (state IN ('pending','in_flight','acknowledged','failed')),
            attempts        INTEGER NOT NULL DEFAULT 0,
            lease_owner     TEXT,                           -- token of the current claim; NULL when pending
            lease_expires_ms INTEGER,                       -- when an in_flight lease lapses; NULL when pending
            next_attempt_ms INTEGER,                        -- earliest next attempt, computed by backoff
            last_error      TEXT,
            ack_token       TEXT,                           -- authoritative token returned on successful ACK
            updated_at_ms   INTEGER NOT NULL,
            PRIMARY KEY (event_seq, target)
        ) WITHOUT ROWID;

        -- Recovery: find lapsed leases.
        CREATE INDEX IF NOT EXISTS idx_outbox_in_flight_lapsed
            ON outbox(state, lease_expires_ms)
            WHERE state = 'in_flight';

        -- Dispatcher scan: pending entries due for a claim.
        CREATE INDEX IF NOT EXISTS idx_outbox_pending
            ON outbox(state, next_attempt_ms)
            WHERE state IN ('pending','failed');

        """)
    }

    // MARK: - meta helpers
    private static func rawMeta(_ c: SQLiteConnection, key: String, default def: Int64) throws -> SQLValue {
        let rows = try c.query(
            sql: "SELECT value FROM schema_meta WHERE key = ?;",
            params: [.text(key)],
            mapper: { row in row.int(0) }
        )
        guard let value = rows.first else { return .integer(def) }
        return .integer(value)
    }

    private static func setMeta(_ c: SQLiteConnection, key: String, value: Int64) throws {
        _ = try c.execute(
            sql: "INSERT INTO schema_meta (key, value) VALUES (?, ?) " +
                 "ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            params: [.text(key), .integer(value)]
        )
    }
}
