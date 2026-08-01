import Foundation

/// KL-ROLE-002: die Freigabe am Tisch.
///
/// Der Zustand ist absichtlich klein und kurzlebig. Ein Token wird geholt,
/// sofort für **eine** Aktion verwendet und danach vergessen — er wird nicht
/// gespeichert, nicht wiederverwendet und überlebt keinen Neustart. Alles
/// andere wäre keine einmalige Freigabe mehr.

/// Die PIN-Regeln der Datenbank, gespiegelt, damit der Betrieb sie am Gerät
/// erfährt statt an einem Serverfehler. Die Durchsetzung bleibt in der
/// Datenbank (`kitchenlink_validate_pin`) — das hier ist Höflichkeit.
enum KitchenLinkManagerPinRules {
    static let minimumLength = 4
    static let maximumLength = 8

    /// Gibt den Grund zurück, warum diese PIN nicht taugt — oder `nil`.
    static func rejection(for pin: String) -> String? {
        guard pin.count >= minimumLength, pin.count <= maximumLength,
              pin.allSatisfy(\.isNumber) else {
            return "Vier bis acht Ziffern."
        }
        if Set(pin).count == 1 {
            return "Eine durchgehend gleiche Ziffer ist keine PIN."
        }
        let ascending = "01234567890123456789"
        let descending = "98765432109876543210"
        if ascending.contains(pin) || descending.contains(pin) {
            return "Eine fortlaufende Zahlenreihe ist keine PIN."
        }
        return nil
    }

    static func isValid(_ pin: String) -> Bool { rejection(for: pin) == nil }
}

/// Was mit einem rechtepflichtigen Handgriff möglich ist. Drei Fälle statt
/// eines Boolean, weil sie im Betrieb drei verschiedene Reaktionen verlangen:
/// tun, jemanden holen — oder sich damit abfinden.
enum KitchenLinkPermissionGate: Equatable {
    case allowed
    /// Das Recht fehlt, aber eine Führungskraft kann es hier und jetzt
    /// freigeben. Der Text erklärt beides.
    case needsAuthorization(String)
    /// Das Recht fehlt und es gibt keinen Weg daran vorbei — weil die Aktion
    /// nicht überbrückbar ist oder niemand eine PIN hinterlegt hat.
    case blocked(String)

    var note: String? {
        switch self {
        case .allowed: nil
        case .needsAuthorization(let text), .blocked(let text): text
        }
    }

    var allowsAuthorization: Bool {
        if case .needsAuthorization = self { return true }
        return false
    }

    static func evaluate(
        permission: KitchenLinkVenuePermission,
        role: KitchenLinkMyRole,
        pinStatus: KitchenLinkManagerPinStatus
    ) -> KitchenLinkPermissionGate {
        if role.can(permission) { return .allowed }
        guard role.isStaff else {
            return .blocked("Dieser Zugang gehört nicht zum Personal dieses Restaurants.")
        }

        let who = role.roleName ?? "Personal"
        let what = permission.deniedClause
        if permission.isPinOverridable && pinStatus.someoneCanAuthorize {
            return .needsAuthorization(
                "Als \(who) darfst du \(what). Eine Führungskraft kann es "
                    + "hier mit ihrer PIN freigeben — einmal, für diese Aktion."
            )
        }
        // Der Wortlaut aus KL-ROLE-001 bleibt, wo es keinen Weg vorbei gibt.
        return .blocked(
            "Als \(who) darfst du \(what). Frag Inhaber, Manager oder Schichtleitung."
        )
    }
}

/// Der Zustand des Freigabe-Blattes. Es gehört keinem Bildschirm: Kasse und
/// Rechnung brauchen dieselbe Geste.
@MainActor
final class KitchenLinkManagerPinAuthorizationModel: ObservableObject {
    @Published var pin: String = ""
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?
    /// Nach der Sperre hilft auch die richtige PIN nicht mehr; das Feld wird
    /// dann abgeschaltet, statt weiter Versuche anzubieten.
    @Published private(set) var isLocked = false

    let permission: KitchenLinkVenuePermission
    private let note: String?
    private let context: [String: String]

    private let config: KitchenLinkCloudConfig
    private let transport: KitchenLinkManagerPinTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool

    init(
        permission: KitchenLinkVenuePermission,
        note: String? = nil,
        context: [String: String] = [:],
        config: KitchenLinkCloudConfig = .sandboxDefault,
        transport: KitchenLinkManagerPinTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.permission = permission
        self.note = note
        self.context = context
        self.config = config
        self.transport = transport
        self.store = store
        self.requiresSession = requiresSession
    }

    /// Baut das Modell passend zum Sandbox-Demo-Launch-Argument.
    static func make(
        permission: KitchenLinkVenuePermission,
        note: String? = nil,
        context: [String: String] = [:]
    ) -> KitchenLinkManagerPinAuthorizationModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkManagerPinAuthorizationModel(
                permission: permission, note: note, context: context
            )
        }
        return KitchenLinkManagerPinAuthorizationModel(
            permission: permission,
            note: note,
            context: context,
            transport: KitchenLinkDemoManagerPinTransport.shared,
            requiresSession: false
        )
    }

    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard !requiresSession else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    var canSubmit: Bool {
        !isWorking && !isLocked && KitchenLinkManagerPinRules.isValid(pin)
    }

    /// Holt die Freigabe. Erfolg heißt: ein Token, der **jetzt** verwendet
    /// werden muss — der Aufrufer führt die Aktion unmittelbar danach aus.
    func authorize() async -> KitchenLinkManagerOverride? {
        guard let session = currentSession else {
            message = "Bitte zuerst anmelden."
            return nil
        }
        if let rejection = KitchenLinkManagerPinRules.rejection(for: pin) {
            message = rejection
            return nil
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await transport.authorize(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                permission: permission,
                pin: pin,
                note: note,
                context: context
            )
            switch result {
            case .granted(let override):
                // Die PIN verlässt den Speicher, sobald sie ihren Zweck erfüllt
                // hat. Sie gehört der Führungskraft, nicht diesem Gerät.
                pin = ""
                message = nil
                return override
            case .refused(let refusal):
                pin = ""
                message = refusal.message
                if case .locked = refusal { isLocked = true }
                return nil
            }
        } catch {
            message = Self.message(for: error)
            return nil
        }
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
