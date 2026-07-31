import Foundation

/// KL-ROLE-002: Sandbox-Demo des Manager-PINs ohne Cloud.
///
/// Er verhält sich wie die Datenbank — dieselben PIN-Regeln, ein Token gilt
/// genau einmal, fünf Fehlversuche sperren, und wer das Recht ohnehin hat,
/// bekommt `pin_not_needed` —, damit die Demo nichts anderes zeigt als der
/// echte Weg.
///
/// **Es wird nichts freigegeben und nichts bewegt.**
///
/// Geteilt (`shared`), weil Kasse, Rechnung und Team-Bildschirm im Demo-Modus
/// dieselbe hinterlegte PIN sehen müssen; drei eigene Kopien wären drei
/// verschiedene Wahrheiten.
actor KitchenLinkDemoManagerPinTransport: KitchenLinkManagerPinTransport {
    static let shared = KitchenLinkDemoManagerPinTransport()

    /// Die PIN der Demo-Schichtleitung. Sie steht auch auf dem Blatt selbst,
    /// sonst ließe sich der Ablauf ohne Cloud nicht durchspielen.
    static let demoAuthorizerPin = "4711"
    static let demoAuthorizerEmail = "sarah@restaurant.de"

    private let maximumFailures = 5

    private var myPin: String?
    private var myPinUpdatedAt: Date?
    private var failures = 0
    private var lockedUntil: Date?
    private var issued: [String: KitchenLinkManagerOverride] = [:]
    private var log: [KitchenLinkManagerOverrideRecord] = []

    /// Im Demo-Modus ist der angemeldete Zugang Inhaber und darf alles — die
    /// Freigabe ist deshalb nur dann nötig, wenn der Aufrufer sie ausdrücklich
    /// erzwingt (Tests). Ohne dieses Flag verhält sich die Demo wie ein
    /// Inhabergerät: sie fragt gar nicht erst.
    private var pretendsMissingPermission = true

    func setPretendsMissingPermission(_ value: Bool) { pretendsMissingPermission = value }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus {
        KitchenLinkManagerPinStatus(
            hasPin: myPin != nil,
            updatedAt: myPinUpdatedAt,
            // Die Demo-Schichtleitung zählt immer mit, die eigene nur, wenn es
            // sie gibt.
            authorizers: 1 + (myPin == nil ? 0 : 1)
        )
    }

    func setPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        pin: String
    ) async throws {
        guard KitchenLinkManagerPinRules.isValid(pin) else {
            throw fail(pin.allSatisfy(\.isNumber) && pin.count >= 4 && pin.count <= 8
                       ? "pin_too_simple" : "pin_invalid_format")
        }
        myPin = pin
        myPinUpdatedAt = Date()
    }

    func clearPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String?
    ) async throws {
        guard userID == nil else { throw fail("permission_denied") }
        myPin = nil
        myPinUpdatedAt = nil
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
        guard KitchenLinkVenuePermission.pinOverridable.contains(permission) else {
            throw fail("pin_permission_not_overridable")
        }
        guard pretendsMissingPermission else { return .refused(.notNeeded) }

        if let until = lockedUntil, until > Date() {
            return .refused(.locked(until: until))
        }
        if lockedUntil != nil { lockedUntil = nil; failures = 0 }

        guard !pin.isEmpty else { return .refused(.missingPin) }

        guard pin == Self.demoAuthorizerPin else {
            failures += 1
            if failures >= maximumFailures {
                let until = Date().addingTimeInterval(5 * 60)
                lockedUntil = until
                return .refused(.locked(until: until))
            }
            return .refused(.invalidPin(attemptsLeft: maximumFailures - failures))
        }

        failures = 0
        let override = KitchenLinkManagerOverride(
            token: "demo-" + UUID().uuidString.lowercased(),
            permission: permission.rawValue,
            expiresAt: Date().addingTimeInterval(5 * 60),
            grantedByEmail: Self.demoAuthorizerEmail
        )
        issued[override.token] = override
        log.insert(
            KitchenLinkManagerOverrideRecord(
                id: override.token,
                permission: permission.rawValue,
                grantedByEmail: Self.demoAuthorizerEmail,
                requestedByEmail: "du@restaurant.de",
                grantedAt: Date(),
                usedAt: nil,
                note: note
            ),
            at: 0
        )
        return .granted(override)
    }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] {
        Array(log.prefix(limit))
    }

    /// Verbraucht einen Token — genau einmal, wie die Datenbank. Die
    /// Demo-Transporte von Kasse und Rechnung rufen das auf, damit ein
    /// zweiter Versuch mit demselben Token auch ohne Cloud scheitert.
    func consume(token: String?, permission: KitchenLinkVenuePermission) throws {
        guard let token, !token.isEmpty, let override = issued[token],
              override.permission == permission.rawValue else {
            throw fail("permission_override_invalid")
        }
        issued.removeValue(forKey: token)
        if let index = log.firstIndex(where: { $0.id == token }) {
            let entry = log[index]
            log[index] = KitchenLinkManagerOverrideRecord(
                id: entry.id,
                permission: entry.permission,
                grantedByEmail: entry.grantedByEmail,
                requestedByEmail: entry.requestedByEmail,
                grantedAt: entry.grantedAt,
                usedAt: Date(),
                note: entry.note
            )
        }
    }
}
