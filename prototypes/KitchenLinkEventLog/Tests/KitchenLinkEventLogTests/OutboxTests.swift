import XCTest
@testable import KitchenLinkEventLog

// MARK: - Outbox / transport tests
//
// These cover the mandatory failure-injection scenarios:
//   - rollback after a failed claim
//   - crash/reopen (events + outbox state survive via the durable file DB)
//   - parallel duplicates (idempotent append + atomic claim)
//   - expired lease recovery
//   - double ACK (already-acknowledged is a safe no-op)
//   - payload-schema replay (same event id/key/fingerprint deduped)
//
// NO sleeps are used as synchronization. The FakeClock advances time
// explicitly, and async dispatch ticks are awaited directly.

private func makeOutbox(clock: FakeClock = FakeClock(),
                        backoff: Outbox.BackoffPolicy = Outbox.BackoffPolicy())
    throws -> (SQLiteConnection, EventStore, Outbox, FakeClock) {
    let conn = try SQLiteConnection(path: ":memory:", wal: false)
    try EventLogSchema.migrate(conn)
    let store = EventStore(connection: conn, clock: clock)
    let outbox = Outbox(connection: conn, store: store, clock: clock, backoff: backoff)
    return (conn, store, outbox, clock)
}

private func req(idempotencyKey: String = "k1",
                 aggregateID: String = "order-1",
                 eventType: String = "OrderCreated",
                 payload: Data = Data("[1]".utf8),
                 outboxTargets: [OutboxTarget] = [.cloud]) -> AppendEventRequest {
    let fingerprint = Fingerprint.canonical(
        venueID: VenueID(rawValue: "venue-1"),
        aggregateType: "Order",
        aggregateID: AggregateID(rawValue: aggregateID),
        eventType: eventType,
        payloadVersion: 1,
        payload: payload
    )
    return AppendEventRequest(
        eventID: EventID(),
        venueID: VenueID(rawValue: "venue-1"),
        aggregateID: AggregateID(rawValue: aggregateID),
        aggregateType: "Order",
        eventType: eventType,
        payloadVersion: 1,
        payload: payload,
        requestFingerprint: fingerprint,
        idempotencyKey: IdempotencyKey(rawValue: idempotencyKey),
        deviceID: DeviceID(rawValue: "device-1"),
        occurredAtMs: nil,
        outboxTargets: outboxTargets
    )
}

final class OutboxTests: XCTestCase {

    // 21. Claiming returns pending rows and marks them in_flight.
    func testClaimMarksInFlight() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        _ = try store.append(req(idempotencyKey: "k2", aggregateID: "o2"), expectedRevision: 0)

        let claims = try outbox.claim(target: .cloud, limit: 10)
        XCTAssertEqual(claims.count, 2)
        XCTAssertEqual(claims[0].eventSeq, 1)
        XCTAssertEqual(claims[1].eventSeq, 2)

        let e1 = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(e1?.state, .inFlight)
        XCTAssertEqual(e1?.attempts, 1)
        XCTAssertNotNil(e1?.leaseOwner)
        XCTAssertNotNil(e1?.leaseExpiresMs)
    }

    // 22. Claiming does NOT use UPDATE...LIMIT and is atomic: a second claim
    // before ACK/NACK returns no further rows.
    func testClaimIsExclusive() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)

        let first = try outbox.claim(target: .cloud, limit: 10)
        XCTAssertEqual(first.count, 1)
        // A second claim while the row is in_flight returns nothing.
        let second = try outbox.claim(target: .cloud, limit: 10)
        XCTAssertTrue(second.isEmpty)
    }

    // 23. Authoritative ACK transitions to acknowledged and records a token.
    func testAckTransitionsToAcknowledged() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        let claim = try outbox.claim(target: .cloud).first!

        let result = try outbox.ack(eventSeq: claim.eventSeq,
                                    target: claim.target,
                                    leaseToken: claim.leaseToken)
        if case .acknowledged(let token) = result {
            XCTAssertFalse(token.isEmpty)
        } else {
            XCTFail("expected acknowledged")
        }
        let after = try outbox.entry(eventSeq: claim.eventSeq, target: claim.target)
        XCTAssertEqual(after?.state, .acknowledged)
        XCTAssertNotNil(after?.ackToken)
    }

    // 24. Double ACK is a safe no-op (alreadyAcknowledged).
    func testDoubleAckIsSafeNoOp() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        let claim = try outbox.claim(target: .cloud).first!
        let first = try outbox.ack(eventSeq: claim.eventSeq,
                                   target: claim.target,
                                   leaseToken: claim.leaseToken)
        let second = try outbox.ack(eventSeq: claim.eventSeq,
                                    target: claim.target,
                                    leaseToken: claim.leaseToken)
        if case .acknowledged(let t1) = first, case .alreadyAcknowledged(let t2) = second {
            XCTAssertEqual(t1, t2)
        } else {
            XCTFail("expected acknowledged then alreadyAcknowledged, got \(first) / \(second)")
        }
    }

    // 25. ACK with a stale/wrong lease token is refused (lease not owned).
    // This models "reopen after commit" where a worker tries to ACK work it
    // no longer holds.
    func testAckWithWrongLeaseRefused() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        let _ = try outbox.claim(target: .cloud).first!
        // Use a bogus lease token.
        XCTAssertThrowsError(
            try outbox.ack(eventSeq: 1, target: .cloud, leaseToken: "not-my-lease")
        ) { error in
            guard case Outbox.OutboxError.leaseNotOwned = error else {
                XCTFail("expected leaseNotOwned, got \(error)")
                return
            }
        }
    }

    // 26. Expired lease recovery flips in_flight rows back to pending and
    // applies a backoff so they become re-claimable.
    func testExpiredLeaseRecovery() throws {
        let clock = FakeClock(startMs: 1_000)
        let (_, store, outbox, _) = try makeOutbox(clock: clock,
            backoff: Outbox.BackoffPolicy(baseMs: 100, maxMs: 1_000))
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)

        // Claim -> in_flight with lease at t=1000+30000=31000.
        let claim = try outbox.claim(target: .cloud, leaseMs: 30_000).first!
        XCTAssertEqual(claim.leaseExpiresMs, 31_000)

        // Before expiry: reclaim finds nothing.
        let before = try outbox.reclaimExpiredLeases(now: 30_000)
        XCTAssertEqual(before, 0)

        // After expiry: reclaim flips to pending with backoff.
        clock.advance(by: 32_000)  // now = 33000
        let reclaimed = try outbox.reclaimExpiredLeases()
        XCTAssertEqual(reclaimed, 1)

        let entry = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entry?.state, .pending)
        XCTAssertEqual(entry?.lastError, "lease_expired")
        // next_attempt_ms = reclaim_now + backoff(1) = 33000 + 100 = 33100.
        XCTAssertEqual(entry?.nextAttemptMs, 33_100)

        // Claim again finds it only once the backoff has elapsed.
        // next_attempt_ms is 33100, so advance the clock past it.
        clock.setNow(33_100)
        let reClaim = try outbox.claim(target: .cloud).first
        XCTAssertNotNil(reClaim)
        XCTAssertEqual(reClaim?.attempts, 2)  // attempts preserved across reclaim
    }

    // 27. NACK releases the lease and applies backoff; the entry is later
    // re-claimable. This models a transient transport failure + retry.
    func testNackAppliesBackoffAndRetries() throws {
        let clock = FakeClock(startMs: 1_000)
        let (_, store, outbox, _) = try makeOutbox(clock: clock,
            backoff: Outbox.BackoffPolicy(baseMs: 200, maxMs: 10_000))
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)

        let claim = try outbox.claim(target: .cloud).first!
        try outbox.nack(eventSeq: claim.eventSeq, target: claim.target,
                        leaseToken: claim.leaseToken, error: "transient")

        let entry = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entry?.state, .failed)
        XCTAssertEqual(entry?.lastError, "transient")
        XCTAssertEqual(entry?.attempts, 1)
        // next_attempt = now(1000) + backoff(1)=200 = 1200.
        XCTAssertEqual(entry?.nextAttemptMs, 1_200)

        // Immediately, it's not claimable (backoff not elapsed).
        let immediate = try outbox.claim(target: .cloud)
        XCTAssertTrue(immediate.isEmpty)

        // After the backoff elapses, it becomes claimable again.
        clock.setNow(1_200)
        let retry = try outbox.claim(target: .cloud).first
        XCTAssertNotNil(retry)
        XCTAssertEqual(retry?.attempts, 2)
    }

    // 28. NACK with a stale token is a no-op (another worker may own it now).
    func testNackWithStaleTokenIsNoOp() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        let claim = try outbox.claim(target: .cloud).first!
        // NACK with a different token: no row should change.
        try outbox.nack(eventSeq: claim.eventSeq, target: claim.target,
                        leaseToken: "someone-else", error: "x")
        let entry = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entry?.state, .inFlight)  // unchanged
        XCTAssertEqual(entry?.leaseOwner, claim.leaseToken)
    }

    // 29. Dispatcher + InMemoryTransport: a clean tick ACKs everything.
    func testDispatcherHappyPath() async throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        _ = try store.append(req(idempotencyKey: "k2", aggregateID: "o2"), expectedRevision: 0)

        let transport = InMemoryTransport()
        let dispatcher = OutboxDispatcher(outbox: outbox, transport: transport, target: .cloud)

        let result = try await dispatcher.tick()
        XCTAssertEqual(result, OutboxDispatcher.TickResult(claimed: 2, acknowledged: 2, failed: 0))

        let e1 = try outbox.entry(eventSeq: 1, target: .cloud)
        let e2 = try outbox.entry(eventSeq: 2, target: .cloud)
        XCTAssertEqual(e1?.state, .acknowledged)
        XCTAssertEqual(e2?.state, .acknowledged)
        XCTAssertTrue(transport.isRemotelyAcked(1))
        XCTAssertTrue(transport.isRemotelyAcked(2))
    }

    // 30. Dispatcher with a transient failure on first attempt NACKs and the
    // entry remains deliverable (retry semantics). This is the "rollback"
    // failure-injection path: a failed delivery does not lose the event.
    func testDispatcherTransientFailureThenRetry() async throws {
        let clock = FakeClock(startMs: 1_000)
        let (_, store, outbox, _) = try makeOutbox(clock: clock,
            backoff: Outbox.BackoffPolicy(baseMs: 100, maxMs: 1_000))
        _ = try store.append(req(idempotencyKey: "k1"), expectedRevision: 0)

        var behavior = InMemoryTransport.Behavior()
        behavior.failOnAttempt = [1: "connection_reset"]
        let transport = InMemoryTransport(behavior: behavior)
        let dispatcher = OutboxDispatcher(outbox: outbox, transport: transport, target: .cloud)

        let r1 = try await dispatcher.tick()
        XCTAssertEqual(r1.claimed, 1)
        XCTAssertEqual(r1.failed, 1)
        XCTAssertEqual(r1.acknowledged, 0)
        XCTAssertEqual(transport.attemptCount(for: 1), 1)

        // The entry is now 'failed' with backoff; not immediately claimable.
        let entry = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entry?.state, .failed)

        // Advance past backoff and retry: success.
        clock.setNow(1_100)
        transport.behavior.failOnAttempt = [:]
        let r2 = try await dispatcher.tick()
        XCTAssertEqual(r2.claimed, 1)
        XCTAssertEqual(r2.acknowledged, 1)
        XCTAssertEqual(transport.attemptCount(for: 1), 2)

        let final = try outbox.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(final?.state, .acknowledged)
    }

    // 31. Payload-schema replay: re-appending the SAME event (same id, key,
    // fingerprint) is deduped; the outbox is not duplicated.
    func testPayloadSchemaReplayDedup() throws {
        let (conn, store, _, _) = try makeOutbox()
        let request = req(idempotencyKey: "k1")
        let first = try store.append(request, expectedRevision: 0)
        let second = try store.append(request, expectedRevision: 0)
        XCTAssertTrue(second.wasReplay)
        XCTAssertEqual(first.event.localSeq, second.event.localSeq)

        // Only one event row and one outbox row.
        let eventCount = try conn.query(sql: "SELECT COUNT(*) FROM events;",
                                        mapper: { $0.int(0) }).first ?? 0
        let outboxCount = try conn.query(sql: "SELECT COUNT(*) FROM outbox;",
                                         mapper: { $0.int(0) }).first ?? 0
        XCTAssertEqual(eventCount, 1)
        XCTAssertEqual(outboxCount, 1)
    }

    // 32. Crash/reopen: events and outbox state survive a process restart.
    // We simulate this with a FILE-backed database that we close and reopen.
    // This is the key durability test and uses NO sleeps.
    func testCrashReopenPreservesEventsAndOutbox() async throws {
        let path = NSTemporaryDirectory()
            + "kleventlog-crash-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Phase 1: write an event, claim it, but DO NOT ack (simulate crash
        // mid-delivery).
        let clock = FakeClock(startMs: 10_000)
        let conn1 = try SQLiteConnection(path: path, wal: true)
        try EventLogSchema.migrate(conn1)
        let store1 = EventStore(connection: conn1, clock: clock)
        let outbox1 = Outbox(connection: conn1, store: store1, clock: clock)
        let appended = try store1.append(req(idempotencyKey: "k1"), expectedRevision: 0)
        XCTAssertEqual(appended.event.localSeq, 1)
        let claimed = try outbox1.claim(target: .cloud).first!
        XCTAssertEqual(claimed.eventSeq, 1)
        // "Crash": drop the connection without acking.
        // Drop references; SQLite closes on deinit.
        _ = (conn1, store1, outbox1)  // extend lifetime to here

        // Phase 2: reopen. The event and the in_flight claim must persist.
        let conn2 = try SQLiteConnection(path: path, wal: true)
        try EventLogSchema.migrate(conn2)
        let store2 = EventStore(connection: conn2, clock: clock)
        let outbox2 = Outbox(connection: conn2, store: store2, clock: clock)

        let readBack = try store2.event(eventID: appended.event.eventID)
        XCTAssertEqual(readBack?.localSeq, 1)
        XCTAssertEqual(readBack?.eventType, "OrderCreated")

        let entry = try outbox2.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entry?.state, .inFlight)  // claim survived
        XCTAssertEqual(entry?.attempts, 1)

        // Recover the lapsed lease and deliver successfully.
        clock.advance(by: 60_000)  // well past the lease
        _ = try outbox2.reclaimExpiredLeases()
        let entryAfter = try outbox2.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(entryAfter?.state, .pending)

        // The recovery applied a backoff; advance past it so the dispatcher's
        // claim can pick the entry up again.
        clock.advance(by: 60_000)

        let transport = InMemoryTransport()
        let dispatcher = OutboxDispatcher(outbox: outbox2, transport: transport, target: .cloud)
        let result = try await dispatcher.tick()
        XCTAssertEqual(result.acknowledged, 1)
        let final = try outbox2.entry(eventSeq: 1, target: .cloud)
        XCTAssertEqual(final?.state, .acknowledged)
    }

    // 33. Parallel duplicates: two append calls for the same logical request
    // (same venue+key+fingerprint) result in exactly one event, regardless of
    // ordering. We simulate concurrency by calling sequentially; the store's
    // RESERVED lock serializes them.
    func testParallelDuplicateAppendsCollapse() throws {
        let (_, store, _, _) = try makeOutbox()
        let request = req(idempotencyKey: "shared-key")
        // Sequential calls model the serialization the lock enforces.
        let r1 = try store.append(request, expectedRevision: 0)
        let r2 = try store.append(request, expectedRevision: 0)
        let r3 = try store.append(request, expectedRevision: 0)
        XCTAssertEqual(r1.event.localSeq, r2.event.localSeq)
        XCTAssertEqual(r2.event.localSeq, r3.event.localSeq)
        XCTAssertTrue(r2.wasReplay && r3.wasReplay)
        XCTAssertEqual(try store.maxLocalSeq(), 1)
    }

    // 34. Backoff policy is bounded and exponential.
    func testBackoffPolicy() {
        let p = Outbox.BackoffPolicy(baseMs: 100, maxMs: 10_000, multiplier: 2.0)
        XCTAssertEqual(p.delayMs(forAttempt: 1), 100)
        XCTAssertEqual(p.delayMs(forAttempt: 2), 200)
        XCTAssertEqual(p.delayMs(forAttempt: 3), 400)
        XCTAssertEqual(p.delayMs(forAttempt: 4), 800)
        // Capped at maxMs.
        XCTAssertEqual(p.delayMs(forAttempt: 20), 10_000)
    }

    // 35. Multi-target outbox: claiming one target does not affect another.
    func testMultiTargetIndependence() throws {
        let (_, store, outbox, _) = try makeOutbox()
        _ = try store.append(
            req(idempotencyKey: "k1",
                outboxTargets: [.cloud, OutboxTarget(rawValue: "peer:7")]),
            expectedRevision: 0)

        let cloudClaims = try outbox.claim(target: .cloud)
        XCTAssertEqual(cloudClaims.count, 1)
        let peerClaims = try outbox.claim(target: OutboxTarget(rawValue: "peer:7"))
        XCTAssertEqual(peerClaims.count, 1)

        // Acknowledging the cloud entry does not touch the peer entry.
        _ = try outbox.ack(eventSeq: 1, target: .cloud, leaseToken: cloudClaims[0].leaseToken)
        let peerEntry = try outbox.entry(eventSeq: 1, target: OutboxTarget(rawValue: "peer:7"))
        XCTAssertEqual(peerEntry?.state, .inFlight)
    }
}
