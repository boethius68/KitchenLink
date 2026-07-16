import Foundation

// MARK: - Weekday template time

/// Lokale Uhrzeit ohne Datum, verwendet in Schichtvorlagen. Die Zeitzone wird erst
/// bei der Auflösung in ein konkretes Datum berücksichtigt.
struct WorkforceLocalTime: Codable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    var isValid: Bool {
        hour >= 0 && hour < 24 && minute >= 0 && minute < 60
    }

    var timeIntervalSinceMidnight: TimeInterval {
        TimeInterval(hour * 3600 + minute * 60)
    }
}

// MARK: - Availability

/// Verfügbarkeit eines Mitarbeiters. Liegt im Kalenderzeitraum mit expliziter Zeitzone.
struct WorkforceAvailability: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    var range: WorkforceTimeRange
    var timeZoneIdentifier: String
    var recurrence: WorkforceRecurrence?
    var note: String?

    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }
}

enum WorkforceRecurrence: String, Codable, Hashable, Sendable {
    case daily
    case weekly
    case monthly
}

// MARK: - Leave / Absence

enum WorkforceLeaveType: String, Codable, Hashable, Sendable {
    case vacation
    case sick
    case unpaid
    case training
    case other
}

enum WorkforceLeaveStatus: String, Codable, Hashable, Sendable {
    case requested
    case approved
    case rejected
}

struct WorkforceLeave: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    var range: WorkforceTimeRange
    var timeZoneIdentifier: String
    var type: WorkforceLeaveType
    var status: WorkforceLeaveStatus
    var approvedBy: WorkforceID?
    var note: String?

    var isApproved: Bool { status == .approved }
}

// MARK: - Shift Template

/// Wiederkehrende Schichtvorlage. Enthält keine Mitarbeiterzuordnung; diese erfolgt
/// erst bei der Erzeugung konkreter geplanter Schichten.
struct WorkforceShiftTemplate: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    var name: String
    var weekday: Int // 1 = Sunday (Gregorian), 2 = Monday ... 8 = Saturday, wie DateComponents
    var startTime: WorkforceLocalTime
    var endTime: WorkforceLocalTime
    var timeZoneIdentifier: String
    var stationIDs: [WorkforceID]
    var requiredRoles: [WorkforceRole]
    var requiredQualifications: [WorkforceQualification]
    var targetHeadcount: Int

    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    /// Löst die Vorlage für ein konkretes Datum in einen absoluten Zeitraum auf.
    /// `onDate` wird in der Vorlagen-Zeitzone als Tag interpretiert.
    func resolvedRange(on date: Date, calendar: Calendar) -> Result<WorkforceTimeRange, WorkforceValidationError> {
        guard startTime.isValid && endTime.isValid else {
            return .failure(.invalidTimeRange)
        }
        guard let tz = timeZone else {
            return .failure(.invalidTimeRange)
        }

        var localCal = calendar
        localCal.timeZone = tz

        var components = localCal.dateComponents([.year, .month, .day], from: date)
        components.hour = startTime.hour
        components.minute = startTime.minute
        components.second = 0
        components.nanosecond = 0

        guard let start = localCal.date(from: components) else {
            return .failure(.invalidTimeRange)
        }

        components.hour = endTime.hour
        components.minute = endTime.minute

        guard let end = localCal.date(from: components) else {
            return .failure(.invalidTimeRange)
        }

        let resolvedEnd = end <= start ? end.addingTimeInterval(24 * 3600) : end
        return .success(WorkforceTimeRange(startsAt: start, endsAt: resolvedEnd))
    }
}

// MARK: - Planned Shift

enum WorkforceShiftStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case draft
    case published
    case accepted
    case declined
    case swapRequested
    case swapAccepted
}

/// Geplante Arbeitsschicht. Sie ist bewusst von `VenueShift` (Betriebsschicht) und
/// `WorkforceTimeEntry` (tatsächliche Zeiterfassung) getrennt.
struct WorkforcePlannedShift: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let venueID: WorkforceID
    let employeeID: WorkforceID
    let templateID: WorkforceID?
    var range: WorkforceTimeRange
    var timeZoneIdentifier: String
    var status: WorkforceShiftStatus
    var stationIDs: [WorkforceID]
    var targetHeadcount: Int
    var requiredQualifications: [WorkforceQualification]
    var publishedAt: Date?
    var acceptedAt: Date?
    var declinedAt: Date?
    var declineReason: String?
    var swapRequestID: WorkforceID?
    var note: String?

    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    var isPublished: Bool { status != .draft }
    var isAssigned: Bool { status == .published || status == .accepted || status == .swapRequested }
    var isFinal: Bool { status == .accepted || status == .declined }
}

// MARK: - Swap request

enum WorkforceSwapStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case pending
    case accepted
    case rejected
    case withdrawn
}

struct WorkforceSwapRequest: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let requestingShiftID: WorkforceID
    let requestedShiftID: WorkforceID
    var status: WorkforceSwapStatus
    var requestedAt: Date
    var respondedAt: Date?
    var note: String?
}

// MARK: - Venue Shift (operating shift)

/// Betriebsschicht. Sie repräsentiert den geöffneten Zeitraum eines Standorts und
/// kann mehrere geplante Arbeitsschichten umfassen.
struct WorkforceVenueShift: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let venueID: WorkforceID
    var range: WorkforceTimeRange
    var timeZoneIdentifier: String
    var openedBy: WorkforceID
    var closedBy: WorkforceID?
    var closedAt: Date?
    var startingCashCents: Int?

    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }
    var isClosed: Bool { closedAt != nil }
}

// MARK: - Time tracking

enum WorkforceTimeEntryKind: String, Codable, Hashable, Sendable {
    case clockIn = "clock_in"
    case clockOut = "clock_out"
}

enum WorkforceBreakKind: String, Codable, Hashable, Sendable {
    case restBreak = "rest_break"
    case mealBreak = "meal_break"
}

/// Unveränderbarer Stempel-Eintrag. Ein Audit-Eintrag entsteht entweder direkt
/// durch Ein-/Ausstempeln oder durch Freigabe einer Korrektur.
struct WorkforceAuditEntry: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    let venueID: WorkforceID
    let plannedShiftID: WorkforceID?
    let kind: WorkforceTimeEntryKind
    let timestamp: Date
    let source: WorkforceAuditSource
    let deviceID: String?
}

enum WorkforceAuditSource: String, Codable, Hashable, Sendable {
    case clock
    case correctionApproved = "correction_approved"
    case manualManagerEntry = "manual_manager_entry"
}

/// Roh-Ein-/Ausstempelung. Kann in Audit-Einträge überführt werden, sobald sie
/// konsistent ist.
struct WorkforceClockEvent: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    let venueID: WorkforceID
    let plannedShiftID: WorkforceID?
    let kind: WorkforceTimeEntryKind
    var timestamp: Date
    var deviceID: String?
}

/// Pause, die zu einem Zeitraum gehört. Pausen müssen innerhalb einer Schicht liegen.
struct WorkforceBreakEntry: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    let venueID: WorkforceID
    let plannedShiftID: WorkforceID?
    var range: WorkforceTimeRange
    var kind: WorkforceBreakKind
    var note: String?
}

enum WorkforceCorrectionStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case draft
    case submitted
    case approved
    case rejected
}

/// Korrekturantrag für einen vergessenen Stempel oder eine falsche Uhrzeit.
/// Nach Freigabe wird ein unveränderlicher `WorkforceAuditEntry` erzeugt.
struct WorkforceCorrectionRequest: Identifiable, Codable, Hashable, Sendable {
    let id: WorkforceID
    let employeeID: WorkforceID
    let venueID: WorkforceID
    let plannedShiftID: WorkforceID?
    let requestedKind: WorkforceTimeEntryKind
    var requestedTimestamp: Date
    var reason: String
    var status: WorkforceCorrectionStatus
    var reviewedBy: WorkforceID?
    var reviewedAt: Date?
}
