import Foundation

/// KL-RES-001: Tischreservierungen (Blueprint §10, Meilenstein 3).
///
/// Ermöglicht die Verwaltung von Gast- und Telefonreservierungen für den Service:
/// Statusübergänge (bestätigt -> platziert -> abgeschlossen / storniert / no-show),
/// Zuweisung von Tischen sowie Erfassung neuer Reservierungen.

public enum KitchenLinkReservationStatus: String, CaseIterable, Identifiable, Sendable {
    case confirmed = "confirmed"
    case seated = "seated"
    case completed = "completed"
    case cancelled = "cancelled"
    case noShow = "no_show"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .confirmed: return "Bestätigt"
        case .seated: return "Platziert"
        case .completed: return "Abgeschlossen"
        case .cancelled: return "Storniert"
        case .noShow: return "No-Show"
        }
    }

    public var isTerminal: Bool {
        self == .completed || self == .cancelled || self == .noShow
    }
}

public struct KitchenLinkReservation: Identifiable, Equatable, Sendable {
    public let id: String
    public var referenceCode: String
    public var guestName: String
    public var guestEmail: String
    public var guestPhone: String?
    public var partySize: Int
    public var reservationDate: String // YYYY-MM-DD
    public var reservationTime: String // HH:MM
    public var area: String
    public var specialRequests: String?
    public var status: KitchenLinkReservationStatus
    public var tableID: String?
    public var tableLabel: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        referenceCode: String,
        guestName: String,
        guestEmail: String,
        guestPhone: String? = nil,
        partySize: Int,
        reservationDate: String,
        reservationTime: String,
        area: String = "Gastraum",
        specialRequests: String? = nil,
        status: KitchenLinkReservationStatus = .confirmed,
        tableID: String? = nil,
        tableLabel: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.referenceCode = referenceCode
        self.guestName = guestName
        self.guestEmail = guestEmail
        self.guestPhone = guestPhone
        self.partySize = partySize
        self.reservationDate = reservationDate
        self.reservationTime = reservationTime
        self.area = area
        self.specialRequests = specialRequests
        self.status = status
        self.tableID = tableID
        self.tableLabel = tableLabel
        self.createdAt = createdAt
    }
}

public protocol KitchenLinkReservationsProviding: Sendable {
    func loadReservations(date: String?) async throws -> [KitchenLinkReservation]
    func updateStatus(reservationID: String, status: KitchenLinkReservationStatus, tableID: String?) async throws
    func createPhoneReservation(
        guestName: String,
        guestEmail: String,
        guestPhone: String?,
        partySize: Int,
        date: String,
        time: String,
        area: String,
        specialRequests: String?
    ) async throws -> KitchenLinkReservation
}

/// Lokaler In-Memory Provider mit vorkonfigurierten Demo-Reservierungen für Tests & Sandbox.
public actor KitchenLinkReservationsDemoProvider: KitchenLinkReservationsProviding {
    private var reservations: [KitchenLinkReservation]

    public init(initialReservations: [KitchenLinkReservation]? = nil) {
        if let initial = initialReservations {
            self.reservations = initial
        } else {
            let today = KitchenLinkReservationDateHelper.todayDateString()
            self.reservations = [
                KitchenLinkReservation(
                    id: "demo-res-1",
                    referenceCode: "KL-384910",
                    guestName: "Familie Sommer",
                    guestEmail: "sommer@example.de",
                    guestPhone: "+49 170 1234567",
                    partySize: 4,
                    reservationDate: today,
                    reservationTime: "18:00",
                    area: "Gastraum",
                    specialRequests: "Kinderstuhl erbeten",
                    status: .confirmed,
                    tableID: "t-1",
                    tableLabel: "Tisch 1"
                ),
                KitchenLinkReservation(
                    id: "demo-res-2",
                    referenceCode: "KL-592814",
                    guestName: "Dr. Alexander Weber",
                    guestEmail: "weber@kanzlei.de",
                    guestPhone: "+49 171 9876543",
                    partySize: 2,
                    reservationDate: today,
                    reservationTime: "19:00",
                    area: "Terrasse",
                    status: .seated,
                    tableID: "t-4",
                    tableLabel: "Tisch 4"
                ),
                KitchenLinkReservation(
                    id: "demo-res-3",
                    referenceCode: "KL-827419",
                    guestName: "Bürgerstiftung e.V.",
                    guestEmail: "kontakt@buergerstiftung.org",
                    guestPhone: "+49 89 203040",
                    partySize: 8,
                    reservationDate: today,
                    reservationTime: "20:00",
                    area: "Gastraum",
                    specialRequests: "Ruhiger Ecktisch",
                    status: .confirmed
                )
            ]
        }
    }

    public func loadReservations(date: String?) async throws -> [KitchenLinkReservation] {
        if let targetDate = date, !targetDate.isEmpty {
            return reservations.filter { $0.reservationDate == targetDate }
        }
        return reservations
    }

    public func updateStatus(
        reservationID: String,
        status: KitchenLinkReservationStatus,
        tableID: String?
    ) async throws {
        guard let idx = reservations.firstIndex(where: { $0.id == reservationID }) else {
            throw KitchenLinkReservationError.notFound
        }
        reservations[idx].status = status
        if let newTable = tableID {
            reservations[idx].tableID = newTable
            reservations[idx].tableLabel = "Tisch \(newTable)"
        }
    }

    public func createPhoneReservation(
        guestName: String,
        guestEmail: String,
        guestPhone: String?,
        partySize: Int,
        date: String,
        time: String,
        area: String,
        specialRequests: String?
    ) async throws -> KitchenLinkReservation {
        guard guestName.trimmingCharacters(in: .whitespaces).count >= 2 else {
            throw KitchenLinkReservationError.invalidInput("Name muss mindestens 2 Zeichen lang sein")
        }
        guard partySize >= 1 && partySize <= 50 else {
            throw KitchenLinkReservationError.invalidInput("Personenanzahl muss zwischen 1 und 50 liegen")
        }

        let refCode = "KL-\(Int.random(in: 100000...999999))"
        let res = KitchenLinkReservation(
            id: UUID().uuidString,
            referenceCode: refCode,
            guestName: guestName.trimmingCharacters(in: .whitespaces),
            guestEmail: guestEmail.trimmingCharacters(in: .whitespaces).lowercased(),
            guestPhone: guestPhone?.trimmingCharacters(in: .whitespaces),
            partySize: partySize,
            reservationDate: date,
            reservationTime: time,
            area: area.isEmpty ? "Gastraum" : area,
            specialRequests: specialRequests?.trimmingCharacters(in: .whitespaces),
            status: .confirmed
        )

        reservations.append(res)
        return res
    }
}

public enum KitchenLinkReservationError: LocalizedError {
    case notFound
    case invalidInput(String)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Reservierung nicht gefunden"
        case .invalidInput(let msg):
            return msg
        case .serverError(let msg):
            return "Serverfehler: \(msg)"
        }
    }
}

public enum KitchenLinkReservationDateHelper {
    public static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return formatter.string(from: Date())
    }

    public static func tomorrowDateString() -> String {
        let cal = Calendar.current
        let nextDay = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return formatter.string(from: nextDay)
    }

    public static func formattedGermanDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "de_DE")
        outputFormatter.dateStyle = .medium
        return outputFormatter.string(from: date)
    }
}
