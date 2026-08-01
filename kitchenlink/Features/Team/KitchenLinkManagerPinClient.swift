import Foundation

/// KL-ROLE-002: Manager-PIN gegen die Sandbox-Instanz.
///
/// KL-ROLE-001 hat aus Blueprint §9.1 nur das Recht umgesetzt. Der Satz lautet
/// aber „sensible Aktionen per besonderem Recht **oder** Manager-PIN" — und
/// genau die zweite Hälfte ist der Fall am Tisch: eine Servicekraft soll eine
/// Zahlung stornieren, die Führungskraft gibt **diese eine** Aktion vor Ort
/// frei, ohne dass sich jemand ab- und wieder anmeldet.
///
/// Der Ablauf hat zwei Schritte: `operator_authorize_with_pin` gibt einen
/// einmaligen, kurzlebigen Token zurück, und die eigentliche RPC verbraucht
/// ihn. Die App hält den Token nur so lange, wie die Aktion dauert — er wandert
/// nie in den Schlüsselbund und überlebt keinen Neustart.

/// Was die App über PINs wissen muss, bevor sie eine Freigabe anbietet.
struct KitchenLinkManagerPinStatus: Equatable, Sendable {
    let hasPin: Bool
    let updatedAt: Date?
    /// Wie viele Personen dieser Venue **heute** etwas freigeben könnten:
    /// hinterlegte PIN und ein passendes Recht. Ohne diese Zahl böte der
    /// Bildschirm am Tisch eine Freigabe an, die niemand erteilen kann.
    let authorizers: Int

    static let unknown = KitchenLinkManagerPinStatus(
        hasPin: false, updatedAt: nil, authorizers: 0
    )

    var someoneCanAuthorize: Bool { authorizers > 0 }

    static func decode(_ data: Data) throws -> KitchenLinkManagerPinStatus {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return KitchenLinkManagerPinStatus(
            hasPin: root["has_pin"] as? Bool ?? false,
            updatedAt: (root["updated_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            authorizers: root["authorizers"] as? Int ?? 0
        )
    }
}

/// Die erteilte Freigabe. Sie gilt für genau eine Aktion, einen Zugang und
/// wenige Minuten — deshalb ist sie ein Wegwerfwert und kein Zustand.
struct KitchenLinkManagerOverride: Equatable, Sendable {
    let token: String
    let permission: String
    let expiresAt: Date?
    let grantedByEmail: String?
}

/// Warum es keine Freigabe gab. Bewusst als Fälle statt als Fehlertext: nur
/// zwei davon sind ein Bedienfehler, die anderen brauchen im Betrieb eine
/// andere Reaktion.
enum KitchenLinkManagerPinRefusal: Equatable, Sendable {
    /// Falsche PIN. `attemptsLeft` ist der Grund, warum das keine Exception
    /// ist: die Datenbank zählt mit, und die App sagt, wie viel bleibt.
    case invalidPin(attemptsLeft: Int)
    case locked(until: Date?)
    /// Zwei Personen führen dieselbe PIN. Eine Freigabe, die sich niemandem
    /// zuordnen lässt, wird nicht erteilt (Blueprint §8.2).
    case ambiguous
    case missingPin
    /// Dieser Zugang darf es ohnehin — die App hätte gar nicht fragen müssen.
    case notNeeded
    case unknown(String)

    var message: String {
        switch self {
        case .invalidPin(let left) where left == 1:
            "PIN falsch. Noch ein Versuch."
        case .invalidPin(let left):
            "PIN falsch. Noch \(left) Versuche."
        case .locked:
            "Zu viele Fehlversuche. Dieses Gerät kann fünf Minuten lang keine "
                + "Freigabe holen."
        case .ambiguous:
            "Diese PIN führen zwei Personen. Eine Freigabe muss eindeutig einer "
                + "Person zuzuordnen sein — bitte eine der beiden ändern."
        case .missingPin:
            "Bitte die PIN eingeben."
        case .notNeeded:
            "Dieser Zugang darf das bereits."
        case .unknown(let reason):
            reason
        }
    }

    static func decode(_ reason: String, root: [String: Any]) -> KitchenLinkManagerPinRefusal {
        switch reason {
        case "pin_invalid":
            .invalidPin(attemptsLeft: root["attempts_left"] as? Int ?? 0)
        case "pin_locked":
            .locked(
                until: (root["locked_until"] as? String).flatMap(KitchenLinkCloudTimestamp.parse)
            )
        case "pin_ambiguous": .ambiguous
        case "pin_missing": .missingPin
        case "pin_not_needed": .notNeeded
        default: .unknown(reason)
        }
    }
}

enum KitchenLinkManagerPinAuthorization: Equatable, Sendable {
    case granted(KitchenLinkManagerOverride)
    case refused(KitchenLinkManagerPinRefusal)

    static func decode(_ data: Data) throws -> KitchenLinkManagerPinAuthorization {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        guard root["granted"] as? Bool == true else {
            let reason = root["reason"] as? String ?? "unbekannt"
            return .refused(KitchenLinkManagerPinRefusal.decode(reason, root: root))
        }
        guard let token = root["token"] as? String else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return .granted(
            KitchenLinkManagerOverride(
                token: token,
                permission: root["permission"] as? String ?? "",
                expiresAt: (root["expires_at"] as? String)
                    .flatMap(KitchenLinkCloudTimestamp.parse),
                grantedByEmail: root["granted_by_email"] as? String
            )
        )
    }
}

/// Eine Zeile aus dem Freigabeprotokoll. Ohne sie wäre die Nachvollziehbarkeit
/// nur eine Zusage in einem Migrationskommentar.
struct KitchenLinkManagerOverrideRecord: Identifiable, Equatable, Sendable {
    let id: String
    let permission: String
    let grantedByEmail: String?
    let requestedByEmail: String?
    let grantedAt: Date?
    let usedAt: Date?
    let note: String?

    /// Eine erteilte, aber nie verbrauchte Freigabe ist kein Fehler — die
    /// Aktion wurde abgebrochen. Sie bleibt sichtbar, weil sie zeigt, dass
    /// jemand gefragt hat.
    var wasUsed: Bool { usedAt != nil }

    var permissionLabel: String {
        KitchenLinkVenuePermission(rawValue: permission)?.label ?? permission
    }

    static func decode(_ row: [String: Any]) -> KitchenLinkManagerOverrideRecord? {
        guard let id = row["id"] as? String,
              let permission = row["permission"] as? String else {
            return nil
        }
        return KitchenLinkManagerOverrideRecord(
            id: id,
            permission: permission,
            grantedByEmail: row["granted_by_email"] as? String,
            requestedByEmail: row["requested_by_email"] as? String,
            grantedAt: (row["granted_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            usedAt: (row["used_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            note: row["note"] as? String
        )
    }
}

protocol KitchenLinkManagerPinTransport: Sendable {
    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus

    func setPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        pin: String
    ) async throws

    /// `userID == nil` heißt „die eigene". Eine fremde darf nur löschen, wer
    /// Personal verwaltet.
    func clearPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String?
    ) async throws

    func authorize(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        permission: KitchenLinkVenuePermission,
        pin: String,
        note: String?,
        context: [String: String]
    ) async throws -> KitchenLinkManagerPinAuthorization

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord]
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkManagerPinTransport {
    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus {
        struct Body: Encodable { let p_venue_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_manager_pin_status",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug))
        )
        return try KitchenLinkManagerPinStatus.decode(data)
    }

    func setPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        pin: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_pin: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_set_manager_pin",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug, p_pin: pin))
        )
    }

    func clearPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String?
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_user_id: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_clear_manager_pin",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_user_id: userID)
            )
        )
    }

    func authorize(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        permission: KitchenLinkVenuePermission,
        pin: String,
        note: String?,
        context: [String: String]
    ) async throws -> KitchenLinkManagerPinAuthorization {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_permission: String
            let p_pin: String
            let p_note: String?
            let p_context: [String: String]
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_authorize_with_pin",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_permission: permission.rawValue,
                    p_pin: pin,
                    p_note: note?.isEmpty == false ? note : nil,
                    p_context: context
                )
            )
        )
        return try KitchenLinkManagerPinAuthorization.decode(data)
    }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_limit: Int
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_recent_overrides",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_limit: limit)
            )
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkManagerOverrideRecord.decode)
    }
}
