import Foundation

// MARK: - Identifiers

struct WorkforceID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    var description: String { rawValue }
}

extension WorkforceID: Identifiable {
    var id: String { rawValue }
}

// MARK: - Roles

/// Standard rollen für Mitarbeiter. Eigene Rollen werden später über ein konfigurierbares
/// Rechtemodell abgebildet; diese Enum deckt die für die Sandbox-Beta notwendigen
/// Standardrollen ab.
enum WorkforceRole: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case owner = "owner"
    case manager = "manager"
    case shiftLead = "shift_lead"
    case service = "service"
    case kitchen = "kitchen"
    case bar = "bar"
    case driver = "driver"
    case inventory = "inventory"
    case accounting = "accounting"

    var id: String { rawValue }
}

// MARK: - Qualifications

/// Qualifikationen, die einer geplanten Schicht oder einem Mitarbeiter zugeordnet werden.
/// Die Liste ist erweiterbar; für die Sandbox-Beta werden die häufigsten Küchen-/Service-
/// Qualifikationen abgedeckt.
enum WorkforceQualification: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case foodSafety = "food_safety"
    case barLicense = "bar_license"
    case driverLicense = "driver_license"
    case sommelier = "sommelier"
    case cashRegister = "cash_register"
    case shiftLead = "shift_lead"
    case barista = "barista"

    var id: String { rawValue }
}

// MARK: - Stations

/// Produktions- oder Service-Station innerhalb eines Standorts. Eine Station kann
/// einer geplanten Schicht zugeordnet werden und trägt eine Sollbesetzung.
struct WorkforceStation: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    var name: String
    var colorHex: String?
    var requiredQualifications: [WorkforceQualification]
}

// MARK: - Employee Profile

/// Mitarbeiterprofil. Enthält keine anmeldespezifischen Authentifizierungsdaten;
/// diese gehören zum Identity-Modul.
struct WorkforceEmployee: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    var givenName: String
    var familyName: String
    var email: String?
    var phone: String?
    var employeeNumber: String?
    var joinedAt: Date
    var leftAt: Date?
    var roles: [WorkforceRole]
    var qualifications: [WorkforceQualification]
    var isActive: Bool

    var displayName: String { "\(givenName) \(familyName)" }

    var isEmployed: Bool {
        isActive && (leftAt == nil || (leftAt ?? .distantPast) > Date())
    }
}

// MARK: - Venue Assignment

/// Zuordnung eines Mitarbeiters zu einem Standort. Ein Mitarbeiter kann mehreren
/// Standorten zugeordnet sein, pro Standort aber nur einmal vorkommen.
struct WorkforceVenueAssignment: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    let venueID: WorkforceID
    var defaultHourlyRateCents: Int?
    var startedAt: Date
    var endedAt: Date?
    var roles: [WorkforceRole]
    var homeStations: [WorkforceID]
}

// MARK: - Time range helpers

struct WorkforceTimeRange: Codable, Hashable, Sendable {
    var startsAt: Date
    var endsAt: Date

    var isValid: Bool { startsAt <= endsAt }
    var duration: TimeInterval { max(0, endsAt.timeIntervalSince(startsAt)) }

    func overlaps(with other: WorkforceTimeRange) -> Bool {
        startsAt < other.endsAt && other.startsAt < endsAt
    }

    func contains(_ date: Date) -> Bool {
        date >= startsAt && date < endsAt
    }

    func intersects(with other: WorkforceTimeRange) -> WorkforceTimeRange? {
        let start = max(startsAt, other.startsAt)
        let end = min(endsAt, other.endsAt)
        guard start < end else { return nil }
        return WorkforceTimeRange(startsAt: start, endsAt: end)
    }
}

// MARK: - Errors

enum WorkforceValidationError: LocalizedError, Equatable, Hashable, Sendable {
    case invalidTimeRange
    case overlappingAvailability
    case leaveOverlapsWithShift
    case missingQualification(WorkforceQualification)
    case unavailable
    case understaffedStation(WorkforceID, required: Int, actual: Int)
    case inconsistentBreak
    case shiftNotPublished
    case shiftAlreadyPublished
    case invalidStatusTransition
    case employeeNotActive
    case venueAssignmentMissing
    case duplicateTimeEntry
    case timeEntryBeforeHireDate
    case correctionNotApproved
    case swapRequestNotPending

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "Der Zeitraum ist ungültig."
        case .overlappingAvailability:
            return "Verfügbarkeiten überschneiden sich."
        case .leaveOverlapsWithShift:
            return "Abwesenheit überschneidet sich mit einer geplanten Schicht."
        case .missingQualification(let q):
            return "Fehlende Qualifikation: \(q.rawValue)."
        case .unavailable:
            return "Der Mitarbeiter ist in diesem Zeitraum nicht verfügbar."
        case .understaffedStation(let stationID, let required, let actual):
            return "Station \(stationID) unterbesetzt: \(actual)/\(required)."
        case .inconsistentBreak:
            return "Pause passt nicht zur Schicht."
        case .shiftNotPublished:
            return "Schicht ist noch nicht veröffentlicht."
        case .shiftAlreadyPublished:
            return "Schicht wurde bereits veröffentlicht."
        case .invalidStatusTransition:
            return "Zustandsübergang ist nicht erlaubt."
        case .employeeNotActive:
            return "Mitarbeiter ist nicht aktiv."
        case .venueAssignmentMissing:
            return "Keine Standortzuordnung vorhanden."
        case .duplicateTimeEntry:
            return "Zeiteintrag überschneidet sich mit einem bestehenden."
        case .timeEntryBeforeHireDate:
            return "Zeiteintrag liegt vor dem Einstellungsdatum."
        case .correctionNotApproved:
            return "Korrektur wurde noch nicht freigegeben."
        case .swapRequestNotPending:
            return "Tauschanfrage ist nicht offen."
        }
    }
}
