import Foundation

/// KL-PAY-001: die Provider-Naht aus Blueprint §8.2.
///
/// Ein echter PSP (Kartenterminal, Tap to Pay, Onlinezahlung) autorisiert
/// einen Betrag und gibt eine Referenz zurück. In der Sandbox macht das ein
/// simulierter Provider — **keine Sandbox-Zahlung bewegt echtes Geld**. Die
/// Naht existiert trotzdem jetzt schon, damit später ein Anbieter eintritt,
/// ohne Rechnung, Bestellung oder Datenmodell anzufassen.
///
/// Bewusst nicht Teil dieser Schnittstelle: Kartendaten. KitchenLink sieht sie
/// nie und speichert sie nie (§8.2); ein Terminal oder SDK übernimmt das und
/// liefert nur die Referenz zurück.

enum KitchenLinkPaymentMethod: String, CaseIterable, Identifiable, Sendable {
    case cash
    case card
    case tapToPay = "tap_to_pay"
    case voucher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Bar"
        case .card: return "Karte"
        case .tapToPay: return "Tap to Pay"
        case .voucher: return "Gutschein"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .tapToPay: return "wave.3.right.circle"
        case .voucher: return "ticket"
        }
    }

    /// Bargeld braucht keinen Anbieter — der Kellner nimmt das Geld entgegen.
    var requiresProvider: Bool {
        switch self {
        case .cash, .voucher: return false
        case .card, .tapToPay: return true
        }
    }
}

struct KitchenLinkPaymentAuthorization: Equatable, Sendable {
    let reference: String
    /// Immer `true`, solange der Sandbox-Provider arbeitet. Die Oberfläche
    /// zeigt das an, damit niemand eine Sandbox-Buchung für echt hält.
    let simulated: Bool
}

enum KitchenLinkPaymentProviderError: LocalizedError, Equatable {
    case declined(String)

    var errorDescription: String? {
        switch self {
        case .declined(let reason): return reason
        }
    }
}

protocol KitchenLinkPaymentProviding: Sendable {
    func authorize(
        amountCents: Int,
        tipCents: Int,
        method: KitchenLinkPaymentMethod
    ) async throws -> KitchenLinkPaymentAuthorization
}

/// Simulierter Anbieter der Sandbox. Er lehnt nichts ab und bucht nichts; er
/// erzeugt die Referenz, unter der die Zahlung nachvollziehbar bleibt.
struct KitchenLinkSandboxPaymentProvider: KitchenLinkPaymentProviding {
    private let referenceFactory: @Sendable () -> String

    init(referenceFactory: @escaping @Sendable () -> String = {
        "sandbox-" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }) {
        self.referenceFactory = referenceFactory
    }

    func authorize(
        amountCents: Int,
        tipCents: Int,
        method: KitchenLinkPaymentMethod
    ) async throws -> KitchenLinkPaymentAuthorization {
        guard amountCents > 0 else {
            throw KitchenLinkPaymentProviderError.declined("Betrag muss größer als 0 sein.")
        }
        return KitchenLinkPaymentAuthorization(
            reference: referenceFactory(),
            simulated: true
        )
    }
}
