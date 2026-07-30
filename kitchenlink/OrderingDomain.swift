import Foundation

/// Sichtbare Tischbezeichnung (KL-TABLE-001). Betreiber vergeben Nummern,
/// Kürzel *und* Namen: „Tisch 7" und „Tisch A1" sind richtig, „Tisch Theke"
/// nicht. Regel: ein zusammenhängendes Kürzel mit mindestens einer Ziffer ist
/// eine Tischnummer und bekommt das Präfix; alles mit Leerzeichen oder ganz
/// ohne Ziffer ist ein Name und bleibt, wie er ist. Dieselbe Regel gilt im
/// Gast-Web (`tableHeadline` in `table-context.ts`), damit Gast und Personal
/// denselben Platz gleich benennen.
enum KitchenLinkTableLabel {
    static func headline(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        let isTableCode = trimmed.contains(where: \.isNumber)
            && trimmed.allSatisfy { $0.isLetter || $0.isNumber }
        return isTableCode ? "Tisch \(trimmed)" : trimmed
    }
}

enum ServiceMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case dineIn = "dine_in"
    case bar
    case pickup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dineIn:
            return "Vor Ort"
        case .bar:
            return "Bar"
        case .pickup:
            return "Abholung"
        }
    }

    var subtitle: String {
        switch self {
        case .dineIn:
            return "Bestellung wird an den Tisch gebracht."
        case .bar:
            return "Abholung an der Bar."
        case .pickup:
            return "Zum Mitnehmen."
        }
    }

    var icon: String {
        switch self {
        case .dineIn:
            return "fork.knife.circle.fill"
        case .bar:
            return "wineglass.fill"
        case .pickup:
            return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

enum QRContextMode: String, Codable, Hashable {
    case table
    case venueShared

    var backendValue: String {
        switch self {
        case .table:
            return "table"
        case .venueShared:
            return "venue_shared"
        }
    }

    init?(backendValue: String) {
        switch backendValue {
        case "table":
            self = .table
        case "venue_shared":
            self = .venueShared
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .table:
            return "Tisch-QR"
        case .venueShared:
            return "Venue-QR"
        }
    }
}

struct VenueTable: Identifiable, Codable, Hashable {
    var id: String
    let label: String
    var isActive: Bool
}

struct VenueProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var slug: String
    var supportedServiceModes: [ServiceMode]
    var tables: [VenueTable]
}

struct ResolvedVenueContext: Identifiable, Codable, Hashable {
    let token: String
    let venue: VenueProfile
    let mode: QRContextMode
    let resolvedTable: VenueTable?

    var id: String { token }

    var displayContextLine: String {
        switch (mode, resolvedTable?.label) {
        case (.table, let tableLabel?):
            return "\(mode.title) · Tisch \(tableLabel)"
        case (.table, nil):
            return mode.title
        case (.venueShared, _):
            return "\(mode.title) · Tisch wird im Checkout bestaetigt"
        }
    }
}

struct ConfirmedCheckoutContext: Equatable {
    let serviceMode: ServiceMode
    let table: VenueTable?
    let customerNote: String
}

enum CheckoutValidationError: LocalizedError, Equatable {
    case unsupportedServiceMode
    case missingTable
    case invalidTableCode

    var errorDescription: String? {
        switch self {
        case .unsupportedServiceMode:
            return "Dieser Service-Modus ist fuer die Venue nicht freigegeben."
        case .missingTable:
            return "Bitte gib einen gueltigen Tischcode an, bevor du vor Ort bestellst."
        case .invalidTableCode:
            return "Der Tischcode wurde nicht gefunden oder ist deaktiviert."
        }
    }
}

enum VenueProfileValidationError: LocalizedError, Equatable {
    case missingName
    case missingSlug
    case missingServiceMode

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Bitte gib einen Venue-Namen an."
        case .missingSlug:
            return "Bitte gib einen gueltigen QR-Slug an."
        case .missingServiceMode:
            return "Mindestens ein Service-Modus muss aktiv sein."
        }
    }
}

enum VenueTableMutationError: LocalizedError, Equatable {
    case missingLabel
    case duplicateLabel

    var errorDescription: String? {
        switch self {
        case .missingLabel:
            return "Bitte gib ein gueltiges Tisch-Label an."
        case .duplicateLabel:
            return "Dieses Tisch-Label existiert bereits."
        }
    }
}

struct CheckoutState: Equatable {
    var serviceMode: ServiceMode
    var selectedTable: VenueTable?
    var manualTableCode: String
    var customerNote: String

    init(context: ResolvedVenueContext) {
        let defaultServiceMode = context.resolvedTable != nil ? ServiceMode.dineIn : (context.venue.supportedServiceModes.first ?? .dineIn)
        self.serviceMode = defaultServiceMode
        self.selectedTable = context.resolvedTable
        self.manualTableCode = context.resolvedTable?.label ?? ""
        self.customerNote = ""
    }

    func validated(in context: ResolvedVenueContext) -> Result<ConfirmedCheckoutContext, CheckoutValidationError> {
        guard context.venue.supportedServiceModes.contains(serviceMode) else {
            return .failure(.unsupportedServiceMode)
        }

        let trimmedNote = customerNote.trimmingCharacters(in: .whitespacesAndNewlines)

        switch serviceMode {
        case .dineIn:
            if let selectedTable, selectedTable.isActive {
                return .success(
                    ConfirmedCheckoutContext(
                        serviceMode: serviceMode,
                        table: selectedTable,
                        customerNote: trimmedNote
                    )
                )
            }

            let normalizedCode = manualTableCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard !normalizedCode.isEmpty else {
                return .failure(.missingTable)
            }

            guard let matchedTable = context.venue.tables.first(where: {
                $0.isActive && $0.label.caseInsensitiveCompare(normalizedCode) == .orderedSame
            }) else {
                return .failure(.invalidTableCode)
            }

            return .success(
                ConfirmedCheckoutContext(
                    serviceMode: serviceMode,
                    table: matchedTable,
                    customerNote: trimmedNote
                )
            )

        case .bar, .pickup:
            return .success(
                ConfirmedCheckoutContext(
                    serviceMode: serviceMode,
                    table: nil,
                    customerNote: trimmedNote
                )
            )
        }
    }
}

enum OrderLifecycleStatus: String, CaseIterable, Codable, Identifiable, Hashable {
    case pending
    case accepted
    case preparing
    case ready
    case served
    case canceled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "Eingegangen"
        case .accepted:
            return "Akzeptiert"
        case .preparing:
            return "In Zubereitung"
        case .ready:
            return "Bereit"
        case .served:
            return "Serviert"
        case .canceled:
            return "Storniert"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .preparing:
            return "flame.fill"
        case .ready:
            return "bell.fill"
        case .served:
            return "checkmark.seal.fill"
        case .canceled:
            return "xmark.octagon.fill"
        }
    }

    var sortIndex: Int {
        switch self {
        case .pending:
            return 0
        case .accepted:
            return 1
        case .preparing:
            return 2
        case .ready:
            return 3
        case .served:
            return 4
        case .canceled:
            return 5
        }
    }

    var primaryNextStatus: OrderLifecycleStatus? {
        switch self {
        case .pending:
            return .accepted
        case .accepted:
            return .preparing
        case .preparing:
            return .ready
        case .ready:
            return .served
        case .served, .canceled:
            return nil
        }
    }

    var primaryActionTitle: String? {
        switch self {
        case .pending:
            return "Annehmen"
        case .accepted:
            return "Zubereitung starten"
        case .preparing:
            return "Als bereit markieren"
        case .ready:
            return "Als serviert markieren"
        case .served, .canceled:
            return nil
        }
    }

    var canCancel: Bool {
        switch self {
        case .pending, .accepted, .preparing, .ready:
            return true
        case .served, .canceled:
            return false
        }
    }

    static let customerTimeline: [OrderLifecycleStatus] = [.pending, .accepted, .preparing, .ready, .served]
    static let boardSections: [OrderLifecycleStatus] = [.pending, .accepted, .preparing, .ready, .served, .canceled]

    func canTransition(to newStatus: OrderLifecycleStatus) -> Bool {
        if newStatus == .canceled {
            return canCancel
        }
        return primaryNextStatus == newStatus
    }
}

struct CustomerTrackedOrder: Identifiable, Equatable {
    let id: String
    let venueName: String
    let serviceMode: ServiceMode
    let tableLabel: String?
    let totalCents: Int
    let itemCount: Int
    let createdAt: Date
    let customerNote: String
    var status: OrderLifecycleStatus
}
