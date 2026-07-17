import Foundation

// MARK: - Transport protocol + reference implementation
//
// `OutboxTransport` is the seam between the outbox and the actual delivery
// mechanism (cloud sync HTTP, Multipeer, etc.). The reference implementation
// `InMemoryTransport` is fully deterministic and injectable so that tests can
// exercise the ACK contract, retries, and failure paths WITHOUT network or
// sleeps.
//
// The ACK contract (see EVENT_LOG_V2.md §ACK contract):
//   - The transport returns `.acknowledged` ONLY after the target has durably
//     persisted the event. HTTP 200 alone is not sufficient.
//   - On `.failed`, the dispatcher nacks the entry and the backoff applies.
//   - The dispatcher never acknowledges an entry whose lease it does not own.

public protocol OutboxTransport: Sendable {
    /// Attempt delivery of `claim`. The result determines the dispatcher's
    /// subsequent ACK/NACK. `claim.leaseToken` identifies the in-flight lease.
    func deliver(_ claim: Outbox.Claim) async throws -> TransportResult
}

public enum TransportResult: Equatable, Sendable {
    /// The target durably accepted the event. `remoteToken` is the target's
    /// proof of persistence (e.g. a server-generated id/etag). The dispatcher
    /// will issue an authoritative ACK.
    case acknowledged(remoteToken: String)
    /// Delivery failed transiently; the entry will be nacked and retried with
    /// backoff.
    case failed(reason: String)
}

// MARK: - Dispatcher
//
// Pulls claims from the outbox, hands them to the transport, and performs the
// authoritative ACK or NACK. It is the glue that ties the store, outbox and
// transport together. Tests drive it directly to keep everything deterministic.

public final class OutboxDispatcher: @unchecked Sendable {
    public let outbox: Outbox
    public let transport: OutboxTransport
    public let target: OutboxTarget

    public init(outbox: Outbox, transport: OutboxTransport, target: OutboxTarget) {
        self.outbox = outbox
        self.transport = transport
        self.target = target
    }

    /// One dispatch tick: claim, deliver each, ACK/NACK. Returns the number of
    /// claims processed and how many were acknowledged.
    public struct TickResult: Equatable, Sendable {
        public let claimed: Int
        public let acknowledged: Int
        public let failed: Int
    }

    @discardableResult
    public func tick(limit: Int = 10) async throws -> TickResult {
        let claims = try outbox.claim(target: target, limit: limit)
        var acked = 0
        var failed = 0
        for claim in claims {
            do {
                let result = try await transport.deliver(claim)
                switch result {
                case .acknowledged:
                    _ = try outbox.ack(eventSeq: claim.eventSeq,
                                       target: claim.target,
                                       leaseToken: claim.leaseToken)
                    acked += 1
                case .failed(let reason):
                    try outbox.nack(eventSeq: claim.eventSeq,
                                    target: claim.target,
                                    leaseToken: claim.leaseToken,
                                    error: reason)
                    failed += 1
                }
            } catch {
                // Transport threw: treat as transient failure.
                try? outbox.nack(eventSeq: claim.eventSeq,
                                 target: claim.target,
                                 leaseToken: claim.leaseToken,
                                 error: String(describing: error))
                failed += 1
            }
        }
        return TickResult(claimed: claims.count, acknowledged: acked, failed: failed)
    }
}

// MARK: - InMemoryTransport (deterministic reference transport)

/// A fully in-process, deterministic transport used for tests and as the
/// reference. Its failure injection hooks make it possible to exercise:
///   - rollback after commit (claim acked twice → double ACK)
///   - crash/reopen (entries survive via the durable log)
///   - expired lease (a stale token is refused by `ack`)
///   - duplicate ACK (already-acknowledged is a safe no-op)
///   - payload-schema replay (same event id/key/fingerprint is deduped)
public final class InMemoryTransport: OutboxTransport, @unchecked Sendable {

    public struct Behavior: Sendable {
        /// If non-nil, the Nth call (1-based) fails with this reason instead
        /// of acknowledging. Used to simulate transient failures + retries.
        public var failOnAttempt: [Int: String] = [:]
        /// If true, every delivery acknowledges WITHOUT recording a remote
        /// token — simulating "HTTP 200 only", i.e. NO durable proof. The
        /// dispatcher still ACKs, but tests can assert that the contract
        /// expects the transport to only return `.acknowledged` when durable.
        public var ackWithoutProof: Bool = false
        public init() {}
    }

    // We use a serial DispatchQueue for synchronization because `deliver` is
    // `async` and NSLock is unsafe to use across suspension points. The queue
    // is sync-invoked, so the critical section never suspends. Ref:
    // Swift Concurrency: "async-safe scoped locking" — DispatchQueue.sync is a
    // valid synchronous alternative when no `await` happens inside.
    private let lock = DispatchQueue(label: "kitchenlink.transport.memory")
    private var _delivered: [Int64: Int] = [:]      // eventSeq -> attempt count
    private var _remoteAcks: Set<Int64> = []        // eventSeq acknowledged remotely
    public var behavior: Behavior

    public init(behavior: Behavior = Behavior()) {
        self.behavior = behavior
    }

    public func deliver(_ claim: Outbox.Claim) async throws -> TransportResult {
        // No `await` happens inside the lock, so sync access is safe.
        lock.sync {
            let n = (_delivered[claim.eventSeq] ?? 0) + 1
            _delivered[claim.eventSeq] = n

            if let reason = behavior.failOnAttempt[n] {
                return .failed(reason: reason)
            }
            _remoteAcks.insert(claim.eventSeq)
            let token = behavior.ackWithoutProof
                ? "no-proof"
                : "remote-\(claim.eventSeq)-\(n)"
            return .acknowledged(remoteToken: token)
        }
    }

    /// Test introspection.
    public func attemptCount(for eventSeq: Int64) -> Int {
        lock.sync { _delivered[eventSeq] ?? 0 }
    }
    public func isRemotelyAcked(_ eventSeq: Int64) -> Bool {
        lock.sync { _remoteAcks.contains(eventSeq) }
    }
}
