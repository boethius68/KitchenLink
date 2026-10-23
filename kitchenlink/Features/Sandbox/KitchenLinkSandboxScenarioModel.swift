import Foundation
import SwiftUI

/// KL-SANDBOX-001: Geführte Demo-Szenarien & Sandbox-Steuerung (Blueprint §20 & §21 Meilenstein 7).
///
/// Ermöglicht das Umschalten von Restaurant-Betriebsphasen (Mittag, Abend,
/// Tagesabschluss, Offline-Ausfall), gezielte Fehlersimulation und 1-Klick-Reset
/// für Vorführungen, Investoren-Demos und automatisierte Abnahmetests.

public enum KitchenLinkSandboxScenarioType: String, CaseIterable, Identifiable, Sendable {
    case lunchRush = "lunch_rush"
    case eveningBar = "evening_bar"
    case shiftClosing = "shift_closing"
    case offlineDisaster = "offline_disaster"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lunchRush: return "Mittagsansturm"
        case .eveningBar: return "Abendservice & Bar"
        case .shiftClosing: return "Tagesabschluss & Kassenprüfung"
        case .offlineDisaster: return "Netzwerkausfall & Venue-Hub"
        }
    }

    public var subtitle: String {
        switch self {
        case .lunchRush:
            return "Hohe Frequenz · 6 Tische aktiv · Küche und Theke ausgelastet · 2 Abholungen"
        case .eveningBar:
            return "Voll besetzt · Reservierungen zugeteilt · Cocktails & Speisen · Loyalty-Stammgäste"
        case .shiftClosing:
            return "Kassenzählung fällig · Belege gebucht · TSE-Signaturzähler · DATEV & DSFinV-K Export"
        case .offlineDisaster:
            return "Cloud nicht erreichbar · Lokaler Venue-Hub übernimmt · Offline-Kasse & Bon-Relay"
        }
    }

    public var icon: String {
        switch self {
        case .lunchRush: return "flame.fill"
        case .eveningBar: return "wineglass.fill"
        case .shiftClosing: return "lock.shield.fill"
        case .offlineDisaster: return "wifi.slash"
        }
    }
}

public struct KitchenLinkSandboxFaultState: Equatable, Sendable {
    public var simulatePaymentTimeout: Bool = false
    public var simulateCashVariance: Bool = false
    public var simulateIngredientDepletion: Bool = false
    public var simulateCloudOffline: Bool = false

    public init(
        simulatePaymentTimeout: Bool = false,
        simulateCashVariance: Bool = false,
        simulateIngredientDepletion: Bool = false,
        simulateCloudOffline: Bool = false
    ) {
        self.simulatePaymentTimeout = simulatePaymentTimeout
        self.simulateCashVariance = simulateCashVariance
        self.simulateIngredientDepletion = simulateIngredientDepletion
        self.simulateCloudOffline = simulateCloudOffline
    }
}

/// Dienstprogramm für den vollständigen JSON-Export und Restore eines Restaurant-Snapshots.
public enum KitchenLinkBackupExporter {

    public struct SnapshotPayload: Codable, Sendable {
        public let schemaVersion: String
        public let exportedAt: String
        public let venueName: String
        public let venueSlug: String
        public let tableCount: Int
        public let activeOrdersCount: Int
        public let cashBalanceCents: Int
        public let tseTransactionsCount: Int
        public let status: String
    }

    public static func createSnapshotJSON(
        venueName: String = "Gasthaus Alte Mühle",
        venueSlug: String = "alte-muehle",
        tableCount: Int = 12,
        activeOrdersCount: Int = 6,
        cashBalanceCents: Int = 29460,
        tseCount: Int = 2
    ) -> String {
        let payload = SnapshotPayload(
            schemaVersion: "2.0-sandbox-beta",
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            venueName: venueName,
            venueSlug: venueSlug,
            tableCount: tableCount,
            activeOrdersCount: activeOrdersCount,
            cashBalanceCents: cashBalanceCents,
            tseTransactionsCount: tseCount,
            status: "consistent"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    public static func validateSnapshot(jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(SnapshotPayload.self, from: data) else {
            return false
        }
        return payload.schemaVersion == "2.0-sandbox-beta" && !payload.venueName.isEmpty
    }
}
