import Foundation

/// KL-RES-002: Warteliste und Walk-in-Steuerung (Blueprint §10).
///
/// Unterstützt den Service bei spontan eintreffenden Gästen ohne Reservierung:
/// Erfassung von Name, Gruppengröße, Mobilnummer, Bereichspräferenz und
/// geschätzter Wartezeit sowie Benachrichtigung und Tischplatzierung.

public enum KitchenLinkWaitlistStatus: String, CaseIterable, Identifiable, Sendable {
    case waiting = "waiting"
    case notified = "notified"
    case seated = "seated"
    case cancelled = "cancelled"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .waiting: return "Wartend"
        case .notified: return "Benachrichtigt"
        case .seated: return "Platziert"
        case .cancelled: return "Storniert"
        }
    }

    public var isActive: Bool {
        self == .waiting || self == .notified
    }
}

public struct KitchenLinkWaitlistEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public var guestName: String
    public var guestPhone: String?
    public var partySize: Int
    public var area: String
    public var estimatedWaitMinutes: Int
    public var notes: String?
    public var status: KitchenLinkWaitlistStatus
    public var tableID: String?
    public var tableLabel: String?
    public var createdAt: Date
    public var seatedAt: Date?

    public init(
        id: String = UUID().uuidString,
        guestName: String,
        guestPhone: String? = nil,
        partySize: Int,
        area: String = "Gastraum",
        estimatedWaitMinutes: Int = 15,
        notes: String? = nil,
        status: KitchenLinkWaitlistStatus = .waiting,
        tableID: String? = nil,
        tableLabel: String? = nil,
        createdAt: Date = Date(),
        seatedAt: Date? = nil
    ) {
        self.id = id
        self.guestName = guestName
        self.guestPhone = guestPhone
        self.partySize = partySize
        self.area = area
        self.estimatedWaitMinutes = estimatedWaitMinutes
        self.notes = notes
        self.status = status
        self.tableID = tableID
        self.tableLabel = tableLabel
        self.createdAt = createdAt
        self.seatedAt = seatedAt
    }

    /// Tatsächlich vergangene Wartezeit in Minuten seit Eintragung.
    public func elapsedMinutes(at referenceDate: Date = Date()) -> Int {
        let seconds = referenceDate.timeIntervalSince(createdAt)
        return max(0, Int(seconds / 60))
    }

    /// Ob die geschätzte Wartezeit bereits überschritten wurde.
    public func isOverdue(at referenceDate: Date = Date()) -> Bool {
        elapsedMinutes(at: referenceDate) > estimatedWaitMinutes
    }
}

public protocol KitchenLinkWaitlistProviding: Sendable {
    func loadWaitlist() async throws -> [KitchenLinkWaitlistEntry]
    func addWalkIn(
        guestName: String,
        partySize: Int,
        phone: String?,
        area: String,
        estimatedWaitMinutes: Int,
        notes: String?
    ) async throws -> KitchenLinkWaitlistEntry
    func updateStatus(
        entryID: String,
        status: KitchenLinkWaitlistStatus,
        tableID: String?
    ) async throws
}

/// Actor-basierter Demo-Provider für Sandbox-Betrieb und Tests.
public actor KitchenLinkWaitlistDemoProvider: KitchenLinkWaitlistProviding {
    private var entries: [KitchenLinkWaitlistEntry]

    public init(initialEntries: [KitchenLinkWaitlistEntry]? = nil) {
        if let initial = initialEntries {
            self.entries = initial
        } else {
            let now = Date()
            self.entries = [
                KitchenLinkWaitlistEntry(
                    id: "wait-1",
                    guestName: "Markus Bauer",
                    guestPhone: "+49 172 3344556",
                    partySize: 2,
                    area: "Gastraum",
                    estimatedWaitMinutes: 15,
                    notes: "Warten an der Bar",
                    status: .waiting,
                    createdAt: now.addingTimeInterval(-600) // Vor 10 Min.
                ),
                KitchenLinkWaitlistEntry(
                    id: "wait-2",
                    guestName: "Sarah Neumann",
                    guestPhone: "+49 176 9988776",
                    partySize: 4,
                    area: "Terrasse",
                    estimatedWaitMinutes: 20,
                    notes: "Hochstuhl bereitstellen",
                    status: .notified,
                    createdAt: now.addingTimeInterval(-1200) // Vor 20 Min.
                )
            ]
        }
    }

    public func loadWaitlist() async throws -> [KitchenLinkWaitlistEntry] {
        entries.filter { $0.status.isActive }
    }

    public func addWalkIn(
        guestName: String,
        partySize: Int,
        phone: String?,
        area: String,
        estimatedWaitMinutes: Int,
        notes: String?
    ) async throws -> KitchenLinkWaitlistEntry {
        let cleanName = guestName.trimmingCharacters(in: .whitespaces)
        guard cleanName.count >= 2 else {
            throw KitchenLinkWaitlistError.invalidInput("Name muss mindestens 2 Zeichen lang sein")
        }
        guard partySize >= 1 && partySize <= 50 else {
            throw KitchenLinkWaitlistError.invalidInput("Personenanzahl muss zwischen 1 und 50 liegen")
        }

        let entry = KitchenLinkWaitlistEntry(
            id: UUID().uuidString,
            guestName: cleanName,
            guestPhone: phone?.trimmingCharacters(in: .whitespaces),
            partySize: partySize,
            area: area.isEmpty ? "Gastraum" : area,
            estimatedWaitMinutes: max(5, estimatedWaitMinutes),
            notes: notes?.trimmingCharacters(in: .whitespaces),
            status: .waiting,
            createdAt: Date()
        )

        entries.append(entry)
        return entry
    }

    public func updateStatus(
        entryID: String,
        status: KitchenLinkWaitlistStatus,
        tableID: String?
    ) async throws {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else {
            throw KitchenLinkWaitlistError.notFound
        }

        entries[idx].status = status
        if let newTable = tableID {
            entries[idx].tableID = newTable
            entries[idx].tableLabel = "Tisch \(newTable)"
        }
        if status == .seated {
            entries[idx].seatedAt = Date()
        }
    }
}

public enum KitchenLinkWaitlistError: LocalizedError {
    case notFound
    case invalidInput(String)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound: return "Wartelisten-Eintrag nicht gefunden"
        case .invalidInput(let msg): return msg
        case .serverError(let msg): return "Serverfehler: \(msg)"
        }
    }
}

/// Hilfsklasse zur Berechnung von Aufenthaltsdauern und Folgebelegungen (Blueprint §10).
public enum KitchenLinkSeatingTurnoverHelper {
    public static let standardSeatingDurationMinutes: Int = 90

    public static func expectedDepartureDate(seatedAt: Date, durationMinutes: Int = standardSeatingDurationMinutes) -> Date {
        seatedAt.addingTimeInterval(Double(durationMinutes * 60))
    }

    public static func remainingMinutes(seatedAt: Date, durationMinutes: Int = standardSeatingDurationMinutes, now: Date = Date()) -> Int {
        let departure = expectedDepartureDate(seatedAt: seatedAt, durationMinutes: durationMinutes)
        let diff = departure.timeIntervalSince(now)
        return max(0, Int(diff / 60))
    }
}
