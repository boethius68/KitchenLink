import Foundation

// MARK: - Validation context

/// Einfacher schreibgeschützter Kontext für domänenseitige Validierungen.
/// Persistenz und UI greifen später auf denselben Validator zurück.
struct WorkforceValidationContext: Sendable {
    var employees: [WorkforceID: WorkforceEmployee]
    var assignments: [WorkforceID: WorkforceVenueAssignment]
    var stations: [WorkforceID: WorkforceStation]
    var plannedShifts: [WorkforcePlannedShift]
    var availabilities: [WorkforceAvailability]
    var leaves: [WorkforceLeave]
    var timeEntries: [WorkforceClockEvent]
    var breakEntries: [WorkforceBreakEntry]
    var venueShifts: [WorkforceVenueShift]
}

// MARK: - Availability validator

struct WorkforceAvailabilityValidator {

    /// Prüft, ob eine neue Verfügbarkeit konsistent ist und sich nicht mit
    /// bestehenden Verfügbarkeiten desselben Mitarbeiters überschneidet.
    static func validate(
        _ availability: WorkforceAvailability,
        in context: WorkforceValidationContext
    ) -> Result<Void, WorkforceValidationError> {
        guard availability.range.isValid else {
            return .failure(.invalidTimeRange)
        }

        let sameEmployee = context.availabilities.filter { $0.employeeID == availability.employeeID && $0.id != availability.id }
        for existing in sameEmployee where availability.range.overlaps(with: existing.range) {
            return .failure(.overlappingAvailability)
        }

        return .success(())
    }
}

// MARK: - Leave validator

struct WorkforceLeaveValidator {

    /// Prüft, ob eine Abwesenheit genehmigt ist und sich nicht mit bereits
    /// veröffentlichten Schichten desselben Mitarbeiters überschneidet.
    static func validate(
        _ leave: WorkforceLeave,
        in context: WorkforceValidationContext
    ) -> Result<Void, WorkforceValidationError> {
        guard leave.range.isValid else {
            return .failure(.invalidTimeRange)
        }

        if leave.status == .approved {
            let conflicting = context.plannedShifts.filter {
                $0.employeeID == leave.employeeID &&
                $0.isPublished &&
                $0.range.overlaps(with: leave.range)
            }
            guard conflicting.isEmpty else {
                return .failure(.leaveOverlapsWithShift)
            }
        }

        return .success(())
    }
}

// MARK: - Planned shift validator

struct WorkforcePlannedShiftValidator {

    /// Prüft eine geplante Schicht auf Konsistenz: Zeitraum, Verfügbarkeit,
    /// Abwesenheit, Qualifikation und aktive Standortzuordnung.
    static func validate(
        _ shift: WorkforcePlannedShift,
        in context: WorkforceValidationContext
    ) -> Result<Void, WorkforceValidationError> {
        guard shift.range.isValid else {
            return .failure(.invalidTimeRange)
        }

        guard let employee = context.employees[shift.employeeID], employee.isActive else {
            return .failure(.employeeNotActive)
        }

        let venueAssignments = context.assignments.values.filter {
            $0.employeeID == shift.employeeID && $0.venueID == shift.venueID
        }
        guard !venueAssignments.isEmpty else {
            return .failure(.venueAssignmentMissing)
        }

        // Approved leave blocks the shift.
        let blockingLeave = context.leaves.first {
            $0.employeeID == shift.employeeID &&
            $0.isApproved &&
            $0.range.overlaps(with: shift.range)
        }
        guard blockingLeave == nil else {
            return .failure(.unavailable)
        }

        // Qualifications required by the station.
        for stationID in shift.stationIDs {
            guard let station = context.stations[stationID] else { continue }
            for qualification in station.requiredQualifications {
                guard employee.qualifications.contains(qualification) else {
                    return .failure(.missingQualification(qualification))
                }
            }
        }

        // Required qualifications explicitly listed on the shift.
        for qualification in shift.requiredQualifications {
            guard employee.qualifications.contains(qualification) else {
                return .failure(.missingQualification(qualification))
            }
        }

        // Availability check: at least one availability covers the whole shift.
        let covering = context.availabilities.contains {
            $0.employeeID == shift.employeeID &&
            $0.range.startsAt <= shift.range.startsAt &&
            $0.range.endsAt >= shift.range.endsAt
        }
        if !covering {
            // If no explicit availability is recorded, we still reject the shift
            // unless a leave is approved. Availability is opt-in and explicit.
            // To allow a shift without availability, caller must add availability.
        }
        guard covering else {
            return .failure(.unavailable)
        }

        return .success(())
    }
}

// MARK: - Station staffing validator

struct WorkforceStationStaffingValidator {

    /// Prüft pro Station und Zeitraum, ob die Sollbesetzung erreicht ist.
    /// Unterbesetzung wird als Warnung zurückgegeben, nicht als harter Fehler,
    /// damit Planer absichtlich unterbesetzte Schichten anlegen können.
    static func validate(
        for stationID: WorkforceID,
        during range: WorkforceTimeRange,
        targetHeadcount: Int,
        in context: WorkforceValidationContext
    ) -> Result<Int, WorkforceValidationError> {
        guard context.stations[stationID] != nil else {
            return .success(0)
        }

        let assigned = context.plannedShifts.filter {
            $0.stationIDs.contains(stationID) &&
            $0.range.overlaps(with: range) &&
            ($0.status == .published || $0.status == .accepted || $0.status == .swapRequested)
        }

        let count = assigned.count
        if count < targetHeadcount {
            return .failure(.understaffedStation(stationID, required: targetHeadcount, actual: count))
        }
        return .success(count)
    }
}

// MARK: - Time entry validator

struct WorkforceTimeEntryValidator {

    /// Prüft, ob ein Stempel-Ereignis zulässig ist: Mitarbeiter aktiv,
    /// Zeitraum innerhalb einer geplanten Schicht, keine Überschneidung mit
    /// bestehenden Stempel-Ereignissen desselben Typs.
    static func validate(
        _ event: WorkforceClockEvent,
        in context: WorkforceValidationContext
    ) -> Result<Void, WorkforceValidationError> {
        guard let employee = context.employees[event.employeeID], employee.isActive else {
            return .failure(.employeeNotActive)
        }

        guard event.timestamp >= employee.joinedAt else {
            return .failure(.timeEntryBeforeHireDate)
        }

        if let shiftID = event.plannedShiftID {
            guard let shift = context.plannedShifts.first(where: { $0.id == shiftID }) else {
                return .failure(.invalidTimeRange)
            }
            guard shift.range.contains(event.timestamp) || shift.range.endsAt == event.timestamp else {
                return .failure(.invalidTimeRange)
            }
        }

        let sameType = context.timeEntries.filter {
            $0.employeeID == event.employeeID &&
            $0.kind == event.kind &&
            $0.id != event.id
        }
        for existing in sameType {
            if abs(existing.timestamp.timeIntervalSince(event.timestamp)) < 1 {
                return .failure(.duplicateTimeEntry)
            }
        }

        return .success(())
    }
}

// MARK: - Break validator

struct WorkforceBreakValidator {

    /// Prüft, ob eine Pause innerhalb einer zugeordneten Schicht liegt und
    /// sich nicht mit anderen Pausen überschneidet.
    static func validate(
        _ breakEntry: WorkforceBreakEntry,
        in context: WorkforceValidationContext
    ) -> Result<Void, WorkforceValidationError> {
        guard breakEntry.range.isValid else {
            return .failure(.invalidTimeRange)
        }

        guard let shift = context.plannedShifts.first(where: { $0.id == breakEntry.plannedShiftID }) else {
            return .failure(.inconsistentBreak)
        }

        guard shift.range.startsAt <= breakEntry.range.startsAt &&
              shift.range.endsAt >= breakEntry.range.endsAt else {
            return .failure(.inconsistentBreak)
        }

        let overlapping = context.breakEntries.contains {
            $0.employeeID == breakEntry.employeeID &&
            $0.id != breakEntry.id &&
            $0.range.overlaps(with: breakEntry.range)
        }
        guard !overlapping else {
            return .failure(.inconsistentBreak)
        }

        return .success(())
    }
}

// MARK: - Helpers

extension WorkforceValidationContext {

    func isEmployeeAvailable(_ employeeID: WorkforceID, at date: Date) -> Bool {
        availabilities.contains {
            $0.employeeID == employeeID && $0.range.contains(date)
        }
    }

    func isEmployeeOnApprovedLeave(_ employeeID: WorkforceID, at date: Date) -> Bool {
        leaves.contains {
            $0.employeeID == employeeID && $0.isApproved && $0.range.contains(date)
        }
    }
}
