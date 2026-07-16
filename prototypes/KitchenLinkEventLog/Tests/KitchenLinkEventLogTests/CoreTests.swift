import XCTest
@testable import KitchenLinkEventLog

// MARK: - Test helpers
//
// A fresh in-memory database per test. `:memory:` DBs are disjoint per
// handle (https://www.sqlite.org/inmemorydb.html), so each test is isolated.
// No sleeps are used anywhere as synchronization; the FakeClock advances time
// explicitly.

private func makeStore(clock: FakeClock = FakeClock()) throws -> (SQLiteConnection, EventStore, FakeClock) {
    let conn = try SQLiteConnection(path: ":memory:", wal: false)
    try EventLogSchema.migrate(conn)
    let store = EventStore(connection: conn, clock: clock)
    return (conn, store, clock)
}

private func sampleRequest(idempotencyKey: String = "req-1",
                           venueID: String = "venue-1",
                           aggregateID: String = "order-1",
                           aggregateType: String = "Order",
                           eventType: String = "OrderCreated",
                           payload: Data = Data("[{\"v\":1}]".utf8),
                           payloadVersion: Int = 1,
                           deviceID: String = "device-1",
                           occurredAtMs: Int64? = nil,
                           outboxTargets: [OutboxTarget] = [.cloud]) -> AppendEventRequest {
    let fingerprint = Fingerprint.canonical(
        venueID: VenueID(rawValue: venueID),
        aggregateType: aggregateType,
        aggregateID: AggregateID(rawValue: aggregateID),
        eventType: eventType,
        payloadVersion: payloadVersion,
        payload: payload
    )
    return AppendEventRequest(
        eventID: EventID(),
        venueID: VenueID(rawValue: venueID),
        aggregateID: AggregateID(rawValue: aggregateID),
        aggregateType: aggregateType,
        eventType: eventType,
        payloadVersion: payloadVersion,
        payload: payload,
        requestFingerprint: fingerprint,
        idempotencyKey: IdempotencyKey(rawValue: idempotencyKey),
        deviceID: DeviceID(rawValue: deviceID),
        occurredAtMs: occurredAtMs,
        outboxTargets: outboxTargets
    )
}

// MARK: - CoreTests

final class CoreTests: XCTestCase {

    // 1. Schema migration applies and records the version.
    func testMigrationAppliesAndRecordsVersion() throws {
        let conn = try SQLiteConnection(path: ":memory:", wal: false)
        try EventLogSchema.migrate(conn)
        let version = try conn.scalar("PRAGMA user_version;")
        // user_version is a separate pragma; we store in schema_meta.
        let stored = try conn.query(
            sql: "SELECT value FROM schema_meta WHERE key = 'version';",
            mapper: { $0.int(0) }
        ).first
        XCTAssertEqual(stored, EventLogSchema.currentVersion)
        // Idempotent: running again does not throw and does not change version.
        try EventLogSchema.migrate(conn)
        let stored2 = try conn.query(
            sql: "SELECT value FROM schema_meta WHERE key = 'version';",
            mapper: { $0.int(0) }
        ).first
        XCTAssertEqual(stored2, EventLogSchema.currentVersion)
    }

    // 2. Refuses to downgrade silently.
    func testRefusesDowngrade() throws {
        let conn = try SQLiteConnection(path: ":memory:", wal: false)
        try EventLogSchema.migrate(conn)
        // Manually bump the recorded version beyond currentVersion.
        _ = try conn.execute(
            sql: "UPDATE schema_meta SET value = ? WHERE key = 'version';",
            params: [.integer(EventLogSchema.currentVersion + 1)]
        )
        XCTAssertThrowsError(try EventLogSchema.migrate(conn)) { error in
            guard case EventLogSchema.SchemaError.refuseDowngrade = error else {
                XCTFail("expected refuseDowngrade, got \(error)")
                return
            }
        }
    }

    // 3. Append assigns a monotonic local sequence starting at 1.
    func testAppendAssignsMonotonicSequence() throws {
        let (_, store, _) = try makeStore()
        let r1 = sampleRequest(idempotencyKey: "k1")
        let r2 = sampleRequest(idempotencyKey: "k2", aggregateID: "order-2")
        let r3 = sampleRequest(idempotencyKey: "k3", aggregateID: "order-3")

        let a = try store.append(r1, expectedRevision: 0)
        let b = try store.append(r2, expectedRevision: 0)
        let c = try store.append(r3, expectedRevision: 0)

        XCTAssertEqual(a.event.localSeq, 1)
        XCTAssertEqual(b.event.localSeq, 2)
        XCTAssertEqual(c.event.localSeq, 3)
        XCTAssertEqual(try store.maxLocalSeq(), 3)
    }

    // 4. Aggregate revision is 1-based and increments per aggregate.
    func testAggregateRevisionIncrements() throws {
        let (_, store, _) = try makeStore()
        let agg = "order-1"
        let r1 = sampleRequest(idempotencyKey: "k1", aggregateID: agg, eventType: "Created")
        let r2 = sampleRequest(idempotencyKey: "k2", aggregateID: agg, eventType: "Accepted")
        let r3 = sampleRequest(idempotencyKey: "k3", aggregateID: agg, eventType: "Prepared")

        let a = try store.append(r1, expectedRevision: 0)
        let b = try store.append(r2, expectedRevision: 1)
        let c = try store.append(r3, expectedRevision: 2)

        XCTAssertEqual(a.event.aggregateRev, 1)
        XCTAssertEqual(b.event.aggregateRev, 2)
        XCTAssertEqual(c.event.aggregateRev, 3)
        XCTAssertEqual(try store.currentRevision(forAggregate: AggregateID(rawValue: agg)), 3)
    }

    // 5. Optimistic concurrency conflict: wrong expectedRevision fails.
    func testOptimisticConcurrencyConflict() throws {
        let (_, store, _) = try makeStore()
        let agg = "order-1"
        let r1 = sampleRequest(idempotencyKey: "k1", aggregateID: agg)
        _ = try store.append(r1, expectedRevision: 0)

        // Pretend a second device thinks the rev is still 0; it must fail.
        let r2 = sampleRequest(idempotencyKey: "k2", aggregateID: agg, eventType: "Accepted")
        XCTAssertThrowsError(try store.append(r2, expectedRevision: 0)) { error in
            guard case EventStore.AppendError.optimisticConcurrencyConflict(
                    let id, let expected, let actual) = error else {
                XCTFail("expected optimisticConcurrencyConflict, got \(error)")
                return
            }
            XCTAssertEqual(id, AggregateID(rawValue: agg))
            XCTAssertEqual(expected, 0)
            XCTAssertEqual(actual, 1)
        }
    }

    // 6. Optimistic concurrency: expecting a revision on a non-existent
    // aggregate fails.
    func testExpectedRevisionOnMissingAggregateFails() throws {
        let (_, store, _) = try makeStore()
        let r = sampleRequest(idempotencyKey: "k1", aggregateID: "ghost")
        XCTAssertThrowsError(try store.append(r, expectedRevision: 1)) { error in
            guard case EventStore.AppendError.optimisticConcurrencyConflict = error else {
                XCTFail("expected optimisticConcurrencyConflict, got \(error)")
                return
            }
        }
    }

    // 7. Idempotency: same request returns the SAME event (wasReplay = true).
    func testIdempotentReplayReturnsSameEvent() throws {
        let (_, store, _) = try makeStore()
        let req = sampleRequest(idempotencyKey: "k1")
        let first = try store.append(req, expectedRevision: 0)
        let second = try store.append(req, expectedRevision: 0)

        XCTAssertFalse(first.wasReplay)
        XCTAssertTrue(second.wasReplay)
        XCTAssertEqual(first.event.eventID, second.event.eventID)
        XCTAssertEqual(first.event.localSeq, second.event.localSeq)
        XCTAssertEqual(try store.maxLocalSeq(), 1)  // only one row
    }

    // 8. Idempotency conflict: same key, different payload -> conflict.
    func testIdempotencyConflictOnDifferentPayload() throws {
        let (_, store, _) = try makeStore()
        let req1 = sampleRequest(idempotencyKey: "k1",
                                 payload: Data("[\"a\"]".utf8))
        _ = try store.append(req1, expectedRevision: 0)

        // Same key, different payload -> different fingerprint -> conflict.
        let req2 = sampleRequest(idempotencyKey: "k1",
                                 payload: Data("[\"b\"]".utf8))
        XCTAssertThrowsError(try store.append(req2, expectedRevision: 0)) { error in
            guard case EventStore.AppendError.idempotencyConflict(
                    let venue, let key, _) = error else {
                XCTFail("expected idempotencyConflict, got \(error)")
                return
            }
            XCTAssertEqual(venue, VenueID(rawValue: "venue-1"))
            XCTAssertEqual(key, IdempotencyKey(rawValue: "k1"))
        }
    }

    // 9. Idempotency key namespace is per venue: same key+payload under a
    // different venue is a separate, valid event.
    func testIdempotencyIsNamespacedPerVenue() throws {
        let (_, store, _) = try makeStore()
        // Different venues AND different aggregates (venue partitioning
        // implies the same logical aggregate id belongs to different venues).
        let req1 = sampleRequest(idempotencyKey: "k1", venueID: "venue-a", aggregateID: "order-a")
        let req2 = sampleRequest(idempotencyKey: "k1", venueID: "venue-b", aggregateID: "order-b")
        // Different venue means different canonical fingerprint, so the two
        // are distinct logical requests even with the same key.
        let a = try store.append(req1, expectedRevision: 0)
        let b = try store.append(req2, expectedRevision: 0)
        XCTAssertNotEqual(a.event.eventID, b.event.eventID)
        XCTAssertEqual(try store.maxLocalSeq(), 2)
    }

    // 10. Fingerprint is deterministic and payload-sensitive.
    func testFingerprintDeterminism() {
        let f1 = Fingerprint.canonical(
            venueID: VenueID(rawValue: "v"),
            aggregateType: "Order",
            aggregateID: AggregateID(rawValue: "o"),
            eventType: "Created",
            payloadVersion: 1,
            payload: Data("[1]".utf8)
        )
        let f2 = Fingerprint.canonical(
            venueID: VenueID(rawValue: "v"),
            aggregateType: "Order",
            aggregateID: AggregateID(rawValue: "o"),
            eventType: "Created",
            payloadVersion: 1,
            payload: Data("[1]".utf8)
        )
        XCTAssertEqual(f1, f2)
        XCTAssertEqual(f1.count, 64)  // SHA-256 hex

        let f3 = Fingerprint.canonical(
            venueID: VenueID(rawValue: "v"),
            aggregateType: "Order",
            aggregateID: AggregateID(rawValue: "o"),
            eventType: "Created",
            payloadVersion: 1,
            payload: Data("[2]".utf8)  // different payload
        )
        XCTAssertNotEqual(f1, f3)
    }

    // 11. Append creates exactly one outbox row per target.
    func testAppendCreatesOutboxRows() throws {
        let (conn, store, _) = try makeStore()
        let targets = [OutboxTarget.cloud, OutboxTarget(rawValue: "peer:7")]
        let req = sampleRequest(idempotencyKey: "k1", outboxTargets: targets)
        _ = try store.append(req, expectedRevision: 0)

        let count = try conn.query(
            sql: "SELECT COUNT(*) FROM outbox WHERE event_seq = 1;",
            mapper: { $0.int(0) }
        ).first ?? 0
        XCTAssertEqual(count, 2)
    }

    // 12. Append with no outbox targets creates no outbox rows.
    func testAppendWithNoTargetsCreatesNoOutbox() throws {
        let (conn, store, _) = try makeStore()
        let req = sampleRequest(idempotencyKey: "k1", outboxTargets: [])
        _ = try store.append(req, expectedRevision: 0)
        let count = try conn.query(
            sql: "SELECT COUNT(*) FROM outbox;",
            mapper: { $0.int(0) }
        ).first ?? 0
        XCTAssertEqual(count, 0)
    }

    // 13. Events are readable by aggregate and by venue.
    func testReadingEvents() throws {
        let (_, store, _) = try makeStore()
        _ = try store.append(sampleRequest(idempotencyKey: "k1", aggregateID: "o1", eventType: "A"), expectedRevision: 0)
        _ = try store.append(sampleRequest(idempotencyKey: "k2", aggregateID: "o2", eventType: "B"), expectedRevision: 0)
        _ = try store.append(sampleRequest(idempotencyKey: "k3", aggregateID: "o1", eventType: "C"), expectedRevision: 1)

        let o1 = try store.events(forAggregate: AggregateID(rawValue: "o1"))
        XCTAssertEqual(o1.map(\.eventType), ["A", "C"])

        let venueEvents = try store.events(forVenue: VenueID(rawValue: "venue-1"))
        XCTAssertEqual(venueEvents.count, 3)
    }

    // 14. Device id, occurred_at and logged_at are preserved.
    func testMetadataPreserved() throws {
        let clock = FakeClock(startMs: 5_000)
        let (_, store, _) = try makeStore(clock: clock)
        let req = sampleRequest(idempotencyKey: "k1", deviceID: "iPad-9", occurredAtMs: 1_000)
        let res = try store.append(req, expectedRevision: 0)
        XCTAssertEqual(res.event.deviceID, DeviceID(rawValue: "iPad-9"))
        XCTAssertEqual(res.event.occurredAtMs, 1_000)
        XCTAssertEqual(res.event.loggedAtMs, 5_000)
    }

    // 15. Duplicate event_id is rejected.
    func testDuplicateEventIDRejected() throws {
        let (_, store, _) = try makeStore()
        let sharedID = EventID(rawValue: "fixed-id")
        var req1 = sampleRequest(idempotencyKey: "k1")
        var req2 = sampleRequest(idempotencyKey: "k2", aggregateID: "o2")
        // Force the same eventID by reconstructing.
        req1 = AppendEventRequest(
            eventID: sharedID, venueID: req1.venueID, aggregateID: req1.aggregateID,
            aggregateType: req1.aggregateType, eventType: req1.eventType,
            payloadVersion: req1.payloadVersion, payload: req1.payload,
            requestFingerprint: req1.requestFingerprint, idempotencyKey: req1.idempotencyKey,
            deviceID: req1.deviceID, occurredAtMs: req1.occurredAtMs, outboxTargets: req1.outboxTargets)
        req2 = AppendEventRequest(
            eventID: sharedID, venueID: req2.venueID, aggregateID: req2.aggregateID,
            aggregateType: req2.aggregateType, eventType: req2.eventType,
            payloadVersion: req2.payloadVersion, payload: req2.payload,
            requestFingerprint: req2.requestFingerprint, idempotencyKey: req2.idempotencyKey,
            deviceID: req2.deviceID, occurredAtMs: req2.occurredAtMs, outboxTargets: req2.outboxTargets)

        _ = try store.append(req1, expectedRevision: 0)
        XCTAssertThrowsError(try store.append(req2, expectedRevision: 0)) { error in
            guard case EventStore.AppendError.duplicateEventID = error else {
                XCTFail("expected duplicateEventID, got \(error)")
                return
            }
        }
    }

    // 16. Events table is append-only: no UPDATE/DELETE helpers exist and
    // a raw attempt to DELETE is left to the integrator; we verify the schema
    // rejects revising an aggregate's rev backwards via the CHECK constraint
    // path indirectly (aggregate_revisions.current_rev CHECK >= 0).
    func testAggregateRevisionCheckConstraint() throws {
        let (conn, _, _) = try makeStore()
        // Direct negative insert into aggregate_revisions must fail.
        XCTAssertThrowsError(
            try conn.execute(
                sql: "INSERT INTO aggregate_revisions (aggregate_id, aggregate_type, venue_id, current_rev, current_seq) VALUES ('x','T','v',-1,1);",
                params: [])
        )
    }

    // 17. WAL mode can be enabled for file-backed DBs and reports 'wal'.
    func testWALModeOnFileDB() throws {
        let tmp = NSTemporaryDirectory()
            + "kleventlog-wal-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let conn = try SQLiteConnection(path: tmp, wal: true)
        try EventLogSchema.migrate(conn)
        let mode = try conn.scalar("PRAGMA journal_mode;")
        XCTAssertEqual(mode, "wal")
    }

    // 18. Payload bytes are preserved verbatim (no reserialization).
    func testPayloadPreservedVerbatim() throws {
        let (_, store, _) = try makeStore()
        let payload = Data([0x00, 0xFF, 0x0A, 0x0D, 0x7F, 0x80])
        let req = sampleRequest(idempotencyKey: "k1", payload: payload)
        let res = try store.append(req, expectedRevision: 0)
        XCTAssertEqual(res.event.payload, payload)
        let readBack = try store.event(eventID: res.event.eventID)
        XCTAssertEqual(readBack?.payload, payload)
    }

    // 19. Fingerprint ignores idempotency key (key labels the request, not
    // the operation). Same operation with two different keys yields the same
    // fingerprint but two distinct events (different keys, same aggregate).
    func testFingerprintIgnoresIdempotencyKey() throws {
        let (_, store, _) = try makeStore()
        // Same operation (same venue/aggregate/type/payload), different keys.
        let req1 = sampleRequest(idempotencyKey: "key-A", aggregateID: "o1")
        let req2 = sampleRequest(idempotencyKey: "key-B", aggregateID: "o1")
        XCTAssertEqual(req1.requestFingerprint, req2.requestFingerprint,
                       "fingerprint depends on operation, not on key")
        // Both append fine: distinct idempotency keys under the same venue,
        // and the second is a new revision of the same aggregate.
        _ = try store.append(req1, expectedRevision: 0)
        _ = try store.append(req2, expectedRevision: 1)
    }

    // 20. Multiple events on the same aggregate under expectedRevision=nil
    // still produce strictly increasing revisions.
    func testNilExpectedRevisionStillIncrements() throws {
        let (_, store, _) = try makeStore()
        let agg = "o1"
        let r1 = sampleRequest(idempotencyKey: "k1", aggregateID: agg)
        let r2 = sampleRequest(idempotencyKey: "k2", aggregateID: agg, eventType: "X")
        let r3 = sampleRequest(idempotencyKey: "k3", aggregateID: agg, eventType: "Y")
        let a = try store.append(r1, expectedRevision: nil)
        let b = try store.append(r2, expectedRevision: nil)
        let c = try store.append(r3, expectedRevision: nil)
        XCTAssertEqual([a.event.aggregateRev, b.event.aggregateRev, c.event.aggregateRev], [1, 2, 3])
    }
}
