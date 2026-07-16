import Foundation

// MARK: - Outbox
//
// The outbox is a PROJECTION of events that need delivery to one or more
// targets. It never edits or deletes events; it only tracks delivery state.
//
// Concurrency model (see EVENT_LOG_V2.md §Outbox state machine & §Claiming):
//   * Every mutating operation runs inside `connection.transaction { tx in ... }`,
//     which performs BEGIN IMMEDIATE ... COMMIT under ONE lock acquisition. This
//     avoids reentrant locking on the connection's serial queue and keeps the
//     whole operation atomic. Ref: https://www.sqlite.org/lang_transaction.html
//   * Claiming does NOT use `UPDATE ... LIMIT`. SQLite does not support it in
//     the standard build, and even where compiled in it is unsafe for
//     work-queue semantics. Ref:
//       https://www.sqlite.org/lang_update.html#update_limit
//     Instead we SELECT candidate rows ORDER BY next_attempt_ms LIMIT n under
//     the RESERVED lock, then UPDATE each by PRIMARY KEY (event_seq, target).
//   * Lease recovery: a row whose `lease_expires_ms < now` while `state =
//     'in_flight'` is flipped back to 'pending' (attempts preserved, backoff
//     applied) inside a tx.
//   * Backoff: `attempts` drives an exponential backoff used to compute
//     `next_attempt_ms`. Bounded to avoid pathological delays.
//
public final class Outbox: @unchecked Sendable {

    public enum OutboxError: Error, Equatable {
        case notPending(eventSeq: Int64, target: OutboxTarget, state: OutboxState)
        case leaseNotOwned(eventSeq: Int64, target: OutboxTarget)
        case storage(String)
    }

    public struct BackoffPolicy: Equatable, Sendable {
        public let baseMs: Int64
        public let maxMs: Int64
        /// Multiplier applied per attempt. 2.0 = classic exponential.
        public let multiplier: Double

        public init(baseMs: Int64 = 500, maxMs: Int64 = 60_000, multiplier: Double = 2.0) {
            self.baseMs = baseMs
            self.maxMs = maxMs
            self.multiplier = multiplier
        }

        /// Delay for the Nth retry. `attempt` is the count AFTER the failed
        /// attempt (so 1 means "delay before the 2nd attempt overall").
        public func delayMs(forAttempt attempt: Int) -> Int64 {
            let raw = Double(baseMs) * pow(multiplier, Double(max(0, attempt - 1)))
            return min(maxMs, Int64(raw.rounded()))
        }
    }

    /// A claimed batch entry, handed to the transport.
    public struct Claim: Equatable, Sendable {
        public let eventSeq: Int64
        public let target: OutboxTarget
        public let leaseToken: String
        public let leaseExpiresMs: Int64
        public let attempts: Int
        public let event: EventRecord

        public init(eventSeq: Int64, target: OutboxTarget, leaseToken: String,
                    leaseExpiresMs: Int64, attempts: Int, event: EventRecord) {
            self.eventSeq = eventSeq
            self.target = target
            self.leaseToken = leaseToken
            self.leaseExpiresMs = leaseExpiresMs
            self.attempts = attempts
            self.event = event
        }
    }

    /// Result of an authoritative ACK.
    public enum AckResult: Equatable, Sendable {
        /// The entry transitioned to `acknowledged` and is durably persisted.
        case acknowledged(ackToken: String)
        /// The entry was already acknowledged; this ACK is a safe no-op.
        case alreadyAcknowledged(ackToken: String)
    }

    public let connection: SQLiteConnection
    public let store: EventStore
    private let clock: Clock
    public let backoff: BackoffPolicy

    public init(connection: SQLiteConnection, store: EventStore,
                clock: Clock, backoff: BackoffPolicy = BackoffPolicy()) {
        self.connection = connection
        self.store = store
        self.clock = clock
        self.backoff = backoff
    }

    // MARK: - Claiming

    /// Claims up to `limit` pending rows for `target`. Each claim:
    ///   - sets state to 'in_flight'
    ///   - assigns a fresh `lease_token` and a `lease_expires_ms`
    ///   - increments `attempts`
    ///   - records `updated_at_ms`
    ///
    /// The whole batch is committed in ONE transaction. Returns the claimed
    /// entries with their full event records (so the transport has everything
    /// it needs to deliver).
    public func claim(target: OutboxTarget, limit: Int = 10,
                      leaseMs: Int64 = 30_000) throws -> [Claim] {
        let now = clock.nowMs()
        let leaseToken = UUID().uuidString

        return try connection.transaction { tx in
            // 1) Select candidates by PK under the RESERVED lock.
            let candidates: [(seq: Int64, attempts: Int)] = try tx.query(
                sql: """
                SELECT event_seq, attempts FROM outbox
                 WHERE target = ?
                   AND state IN ('pending','failed')
                   AND (next_attempt_ms IS NULL OR next_attempt_ms <= ?)
                 ORDER BY COALESCE(next_attempt_ms, event_seq), event_seq
                 LIMIT ?;
                """,
                params: [.text(target.rawValue), .integer(now), .integer(Int64(limit))],
                mapper: { row in (seq: row.int(0), attempts: Int(row.int(1))) }
            )

            var claims: [Claim] = []
            for candidate in candidates {
                let newAttempts = candidate.attempts + 1
                let expires = now + leaseMs
                // 2) UPDATE by PK — no row-ordering dependence.
                _ = try tx.execute(sql: """
                    UPDATE outbox
                       SET state = 'in_flight',
                           attempts = ?,
                           lease_owner = ?,
                           lease_expires_ms = ?,
                           updated_at_ms = ?
                     WHERE event_seq = ? AND target = ?;
                    """, params: [
                        .integer(Int64(newAttempts)),
                        .text(leaseToken),
                        .integer(expires),
                        .integer(now),
                        .integer(candidate.seq),
                        .text(target.rawValue)
                    ])

                // Fetch the event for the transport (inline read inside the tx).
                let event: EventRecord? = try tx.queryOne(
                    sql: "SELECT * FROM events WHERE local_seq = ?;",
                    params: [.integer(candidate.seq)],
                    mapper: Self.rowToEvent
                )
                if let event {
                    claims.append(Claim(
                        eventSeq: candidate.seq,
                        target: target,
                        leaseToken: leaseToken,
                        leaseExpiresMs: expires,
                        attempts: newAttempts,
                        event: event
                    ))
                }
            }
            return claims
        }
    }

    // MARK: - NACK / failure (release back to pending with backoff)

    /// Releases an in_flight claim back to 'failed' (re-claimable) and applies
    /// the backoff so the next attempt is delayed. Idempotent: if the lease no
    /// longer matches, this is a no-op (another worker may have reclaimed it).
    public func nack(eventSeq: Int64, target: OutboxTarget,
                     leaseToken: String, error: String) throws {
        let now = clock.nowMs()

        try connection.transaction { tx in
            // Read attempts inside the tx (inline, no reentrant lock).
            let attempts: Int = try tx.queryOne(
                sql: "SELECT attempts FROM outbox WHERE event_seq = ? AND target = ?;",
                params: [.integer(eventSeq), .text(target.rawValue)],
                mapper: { Int($0.int(0)) }
            ) ?? 1
            let nextAttempt = now + backoff.delayMs(forAttempt: attempts)

            // Only update if the lease still matches; otherwise no-op.
            _ = try tx.execute(sql: """
                UPDATE outbox
                   SET state = 'failed',
                       lease_owner = NULL,
                       lease_expires_ms = NULL,
                       next_attempt_ms = ?,
                       last_error = ?,
                       updated_at_ms = ?
                 WHERE event_seq = ? AND target = ?
                   AND state = 'in_flight'
                   AND lease_owner = ?;
                """, params: [
                    .integer(nextAttempt),
                    .text(error),
                    .integer(now),
                    .integer(eventSeq),
                    .text(target.rawValue),
                    .text(leaseToken)
                ])
        }
    }

    // MARK: - Authoritative ACK
    //
    // The ACK contract: the transport may call `ack` ONLY AFTER it has
    // successfully durably committed the event on the target side (e.g. the
    // cloud returned HTTP 200 AND we verified the row landed). HTTP 200 alone
    // is NOT proof of persistence. See EVENT_LOG_V2.md §ACK contract.
    //
    // `ack` transitions the entry to 'acknowledged' and records an
    // `ack_token`. It is idempotent: a second ACK for an already-acknowledged
    // entry returns `.alreadyAcknowledged` with the original token.

    public func ack(eventSeq: Int64, target: OutboxTarget,
                    leaseToken: String) throws -> AckResult {
        let now = clock.nowMs()
        let ackToken = "ack-\(eventSeq)-\(target.rawValue)-\(now)"

        return try connection.transaction { tx in
            // Check the current state BEFORE the UPDATE, so we can distinguish
            // "already acknowledged" (safe no-op) from "lease not owned".
            let before: (state: String, token: String?)? = try tx.queryOne(
                sql: "SELECT state, ack_token FROM outbox WHERE event_seq = ? AND target = ?;",
                params: [.integer(eventSeq), .text(target.rawValue)],
                mapper: { row in (state: row.string(0) ?? "", token: row.string(1)) }
            )
            if before?.state == "acknowledged" {
                return AckResult.alreadyAcknowledged(ackToken: before?.token ?? ackToken)
            }

            // Transition to acknowledged only if the lease matches. If the
            // lease has lapsed and been reclaimed, the ACK is refused — the
            // transport must not acknowledge work it no longer owns.
            _ = try tx.execute(sql: """
                UPDATE outbox
                   SET state = 'acknowledged',
                       lease_owner = NULL,
                       lease_expires_ms = NULL,
                       ack_token = ?,
                       last_error = NULL,
                       updated_at_ms = ?
                 WHERE event_seq = ? AND target = ?
                   AND state = 'in_flight'
                   AND lease_owner = ?;
                """, params: [
                    .text(ackToken),
                    .integer(now),
                    .integer(eventSeq),
                    .text(target.rawValue),
                    .text(leaseToken)
                ])

            // Inspect the resulting row to decide the outcome.
            let after: (state: String, token: String?)? = try tx.queryOne(
                sql: "SELECT state, ack_token FROM outbox WHERE event_seq = ? AND target = ?;",
                params: [.integer(eventSeq), .text(target.rawValue)],
                mapper: { row in (state: row.string(0) ?? "", token: row.string(1)) }
            )
            if after?.state == "acknowledged" {
                return AckResult.acknowledged(ackToken: after?.token ?? ackToken)
            }
            // State was not acknowledged and the UPDATE did not transition it:
            // the lease did not match.
            throw OutboxError.leaseNotOwned(eventSeq: eventSeq, target: target)
        }
    }

    // MARK: - Lease recovery

    /// Reclaims entries whose leases have lapsed: flips `state` back to
    /// `pending` and applies a small backoff so a wedged worker does not get
    /// immediately re-spammed. Returns the number of entries reclaimed.
    @discardableResult
    public func reclaimExpiredLeases(now: Int64? = nil) throws -> Int {
        let now = now ?? clock.nowMs()

        return try connection.transaction { tx in
            // Identify lapsed leases under the lock.
            let lapsed: [(Int64, OutboxTarget, Int)] = try tx.query(
                sql: """
                SELECT event_seq, target, attempts FROM outbox
                 WHERE state = 'in_flight'
                   AND lease_expires_ms IS NOT NULL
                   AND lease_expires_ms < ?;
                """,
                params: [.integer(now)],
                mapper: { row in
                    (row.int(0),
                     OutboxTarget(rawValue: row.string(1) ?? ""),
                     Int(row.int(2)))
                }
            )
            for (seq, target, attempts) in lapsed {
                let next = now + backoff.delayMs(forAttempt: attempts)
                _ = try tx.execute(sql: """
                    UPDATE outbox
                       SET state = 'pending',
                           lease_owner = NULL,
                           lease_expires_ms = NULL,
                           next_attempt_ms = ?,
                           last_error = 'lease_expired',
                           updated_at_ms = ?
                     WHERE event_seq = ? AND target = ?
                       AND state = 'in_flight';
                    """, params: [
                        .integer(next),
                        .integer(now),
                        .integer(seq),
                        .text(target.rawValue)
                    ])
            }
            return lapsed.count
        }
    }

    // MARK: - Reads

    public func entry(eventSeq: Int64, target: OutboxTarget) throws -> OutboxEntry? {
        try connection.query(
            sql: """
            SELECT event_seq, target, state, attempts, lease_owner,
                   lease_expires_ms, next_attempt_ms, last_error, ack_token,
                   updated_at_ms
              FROM outbox
             WHERE event_seq = ? AND target = ?;
            """,
            params: [.integer(eventSeq), .text(target.rawValue)],
            mapper: Self.rowToEntry
        ).first
    }

    /// All entries currently in a non-acknowledged state for a target.
    public func openEntries(target: OutboxTarget) throws -> [OutboxEntry] {
        try connection.query(
            sql: """
            SELECT event_seq, target, state, attempts, lease_owner,
                   lease_expires_ms, next_attempt_ms, last_error, ack_token,
                   updated_at_ms
              FROM outbox
             WHERE target = ? AND state != 'acknowledged'
             ORDER BY event_seq;
            """,
            params: [.text(target.rawValue)],
            mapper: Self.rowToEntry
        )
    }

    // MARK: - Row mappers (shared, stateless)

    fileprivate static func rowToEntry(_ row: StatementRow) -> OutboxEntry {
        OutboxEntry(
            eventSeq: row.int(0),
            target: OutboxTarget(rawValue: row.string(1) ?? ""),
            state: OutboxState(rawValue: row.string(2) ?? "pending") ?? .pending,
            attempts: Int(row.int(3)),
            leaseOwner: row.string(4),
            leaseExpiresMs: row.int(5) == 0 ? nil : row.int(5),
            nextAttemptMs: row.int(6) == 0 ? nil : row.int(6),
            lastError: row.string(7),
            ackToken: row.string(8),
            updatedAtMs: row.int(9)
        )
    }

    fileprivate static func rowToEvent(_ row: StatementRow) -> EventRecord {
        EventRecord(
            eventID: EventID(rawValue: row.string(0) ?? ""),
            localSeq: row.int(1),
            venueID: VenueID(rawValue: row.string(2) ?? ""),
            aggregateID: AggregateID(rawValue: row.string(3) ?? ""),
            aggregateType: row.string(4) ?? "",
            aggregateRev: row.int(5),
            eventType: row.string(6) ?? "",
            payloadVersion: Int(row.int(7)),
            payload: row.data(8) ?? Data(),
            requestFingerprint: row.string(9) ?? "",
            idempotencyKey: IdempotencyKey(rawValue: row.string(10) ?? ""),
            deviceID: DeviceID(rawValue: row.string(11) ?? ""),
            occurredAtMs: row.int(12),
            loggedAtMs: row.int(13)
        )
    }
}
