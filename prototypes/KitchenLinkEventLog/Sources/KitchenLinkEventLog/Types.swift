import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Domain types
//
// These types model the authoritative local event log and its outbox. They are
// Codable + Equatable + Sendable where it is semantically sound, so that the
// store can be composed into a larger system without losing type safety.
//
// The payload is deliberately opaque (`Data`) at the storage layer: the log
// preserves the canonical bytes the client provided and never reserializes
// them. A `payload_version` lets readers evolve the payload schema without
// rewriting history. See EVENT_LOG_V2.md §Payload contract.

/// A globally unique event identifier (UUID string). The client generates it;
/// the store refuses duplicates via the `idx_events_event_id` unique index.
public struct EventID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    /// Generates a new v4 UUID identifier. In production, prefer UUIDv7
    /// (time-ordered) for better index locality; this prototype uses v4 which
    /// is universally available in Foundation.
    public init() { self.rawValue = UUID().uuidString }
}

/// A logical aggregate identifier (e.g. an order id, a payment id).
public struct AggregateID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A client-supplied idempotency key. Must be stable for retries of the SAME
/// logical request.
public struct IdempotencyKey: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A venue identifier. All events are partitioned by venue.
public struct VenueID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A physical/logical device identifier (the authoring device).
public struct DeviceID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A delivery target (e.g. "cloud", "peer:device-7").
public struct OutboxTarget: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

// MARK: EventRecord

/// A single authoritative event as persisted in the log. Immutable after
/// insertion. `aggregateRev` is 1-based: the first event for an aggregate has
/// revision 1.
public struct EventRecord: Equatable, Codable, Sendable {
    public let eventID: EventID
    public let localSeq: Int64
    public let venueID: VenueID
    public let aggregateID: AggregateID
    public let aggregateType: String
    public let aggregateRev: Int64
    public let eventType: String
    public let payloadVersion: Int
    public let payload: Data
    public let requestFingerprint: String
    public let idempotencyKey: IdempotencyKey
    public let deviceID: DeviceID
    public let occurredAtMs: Int64
    public let loggedAtMs: Int64

    public init(eventID: EventID,
                localSeq: Int64,
                venueID: VenueID,
                aggregateID: AggregateID,
                aggregateType: String,
                aggregateRev: Int64,
                eventType: String,
                payloadVersion: Int,
                payload: Data,
                requestFingerprint: String,
                idempotencyKey: IdempotencyKey,
                deviceID: DeviceID,
                occurredAtMs: Int64,
                loggedAtMs: Int64) {
        self.eventID = eventID
        self.localSeq = localSeq
        self.venueID = venueID
        self.aggregateID = aggregateID
        self.aggregateType = aggregateType
        self.aggregateRev = aggregateRev
        self.eventType = eventType
        self.payloadVersion = payloadVersion
        self.payload = payload
        self.requestFingerprint = requestFingerprint
        self.idempotencyKey = idempotencyKey
        self.deviceID = deviceID
        self.occurredAtMs = occurredAtMs
        self.loggedAtMs = loggedAtMs
    }
}

// MARK: - Outbox state machine

/// The state of an outbox entry. Transitions are enforced in code and are
/// documented in EVENT_LOG_V2.md §Outbox state machine.
///
/// The raw values match the database column values (snake_case) so that the
/// enum round-trips with the `outbox.state` column without translation.
public enum OutboxState: String, Codable, Sendable, Equatable {
    case pending       = "pending"      // waiting to be claimed
    case inFlight      = "in_flight"    // claimed under a lease, delivery attempted
    case acknowledged  = "acknowledged" // authoritatively ACKed
    case failed        = "failed"       // exhausted retries (terminal for now; see doc)
}

/// A snapshot of an outbox row.
public struct OutboxEntry: Equatable, Codable, Sendable {
    public let eventSeq: Int64
    public let target: OutboxTarget
    public let state: OutboxState
    public let attempts: Int
    public let leaseOwner: String?
    public let leaseExpiresMs: Int64?
    public let nextAttemptMs: Int64?
    public let lastError: String?
    public let ackToken: String?
    public let updatedAtMs: Int64

    public init(eventSeq: Int64,
                target: OutboxTarget,
                state: OutboxState,
                attempts: Int,
                leaseOwner: String?,
                leaseExpiresMs: Int64?,
                nextAttemptMs: Int64?,
                lastError: String?,
                ackToken: String?,
                updatedAtMs: Int64) {
        self.eventSeq = eventSeq
        self.target = target
        self.state = state
        self.attempts = attempts
        self.leaseOwner = leaseOwner
        self.leaseExpiresMs = leaseExpiresMs
        self.nextAttemptMs = nextAttemptMs
        self.lastError = lastError
        self.ackToken = ackToken
        self.updatedAtMs = updatedAtMs
    }
}

// MARK: - Append request

/// A request to append a single event. Constructed by the domain layer.
public struct AppendEventRequest: Equatable, Sendable {
    public let eventID: EventID
    public let venueID: VenueID
    public let aggregateID: AggregateID
    public let aggregateType: String
    public let eventType: String
    public let payloadVersion: Int
    public let payload: Data
    public let requestFingerprint: String
    public let idempotencyKey: IdempotencyKey
    public let deviceID: DeviceID
    /// When the event logically occurred. If nil, the store uses the clock.
    public let occurredAtMs: Int64?

    /// Targets that should receive this event via the outbox. At least one is
    /// typical ("cloud"). The store creates one outbox row per target.
    public let outboxTargets: [OutboxTarget]

    public init(eventID: EventID,
                venueID: VenueID,
                aggregateID: AggregateID,
                aggregateType: String,
                eventType: String,
                payloadVersion: Int,
                payload: Data,
                requestFingerprint: String,
                idempotencyKey: IdempotencyKey,
                deviceID: DeviceID,
                occurredAtMs: Int64? = nil,
                outboxTargets: [OutboxTarget] = [.cloud]) {
        self.eventID = eventID
        self.venueID = venueID
        self.aggregateID = aggregateID
        self.aggregateType = aggregateType
        self.eventType = eventType
        self.payloadVersion = payloadVersion
        self.payload = payload
        self.requestFingerprint = requestFingerprint
        self.idempotencyKey = idempotencyKey
        self.deviceID = deviceID
        self.occurredAtMs = occurredAtMs
        self.outboxTargets = outboxTargets
    }
}

extension OutboxTarget {
    /// The default cloud-sync target.
    public static let cloud = OutboxTarget(rawValue: "cloud")
}

// MARK: - Fingerprint
//
// `request_fingerprint` is a SHA-256 (lowercase hex) of the canonical request.
// It is NOT the payload bytes alone: it includes the fields that semantically
// define the operation, so that two different operations that happen to share
// a payload cannot collide. The canonical input is documented and stable.
// Ref for SHA-256 determinism: Apple CryptoKit `SHA256` is a pure function
// over its input bytes.
public enum Fingerprint {

    /// Computes the canonical SHA-256 fingerprint for an append request.
    ///
    /// Canonical input (UTF-8, newline-separated, in this exact order):
    ///   1. venueID
    ///   2. aggregateType
    ///   3. aggregateID
    ///   4. eventType
    ///   5. payloadVersion (decimal)
    ///   6. payload bytes (raw, NOT hex-encoded)
    ///
    /// `idempotency_key` is intentionally NOT part of the fingerprint: the key
    /// labels the logical request, while the fingerprint describes WHAT the
    /// request does. This lets the store reject "same key, different payload"
    /// as a real conflict rather than silently returning the old result.
    public static func canonical(venueID: VenueID,
                                 aggregateType: String,
                                 aggregateID: AggregateID,
                                 eventType: String,
                                 payloadVersion: Int,
                                 payload: Data) -> String {
        var input = Data()
        func append(_ s: String) {
            input.append(Data(s.utf8))
            input.append(0x0A) // newline
        }
        append(venueID.rawValue)
        append(aggregateType)
        append(aggregateID.rawValue)
        append(eventType)
        append(String(payloadVersion))
        input.append(payload)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Clock
//
// All timestamps are epoch-millis (Int64). The clock is injectable so that
// tests are deterministic and never rely on wall-clock sleeps.
public protocol Clock: Sendable {
    func nowMs() -> Int64
}

/// Wall-clock for production. Uses `Date().timeIntervalSince1970`.
public struct SystemClock: Clock {
    public init() {}
    public func nowMs() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
    }
}

/// Fixed / offset clock for deterministic tests.
public final class FakeClock: Clock, @unchecked Sendable {
    private var value: Int64
    public init(startMs: Int64 = 1_700_000_000_000) { self.value = startMs }
    public func nowMs() -> Int64 { value }
    public func advance(by ms: Int64) { value += ms }
    public func setNow(_ ms: Int64) { value = ms }
}
