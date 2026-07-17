import Foundation
import Testing
@testable import kitchenlink

@Suite("Workforce Domain")
struct KitchenLinkWorkforceDomainTests {

    // MARK: - Identity and equality

    @Test
    func employeeIsEmployedWhenActiveAndNotLeft() {
        let employee = WorkforceEmployee(
            id: "emp-active",
            givenName: "Max",
            familyName: "Mustermann",
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000),
            roles: [.service],
            qualifications: [],
            isActive: true
        )
        #expect(employee.isEmployed)
    }

    @Test
    func inactiveEmployeeIsNotEmployed() {
        let employee = WorkforceEmployee(
            id: "emp-inactive",
            givenName: "Max",
            familyName: "Mustermann",
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000),
            roles: [.service],
            qualifications: [],
            isActive: false
        )
        #expect(!employee.isEmployed)
    }

    @Test
    func rolesAreCodableAndIdentifiable() {
        let role = WorkforceRole.manager
        #expect(role.id == "manager")
        #expect(WorkforceRole.allCases.contains(.kitchen))
    }

    // MARK: - Time range helpers

    @Test
    func timeRangeDetectsOverlap() {
        let a = WorkforceTimeRange(startsAt: date(hour: 8, minute: 0), endsAt: date(hour: 12, minute: 0))
        let b = WorkforceTimeRange(startsAt: date(hour: 10, minute: 0), endsAt: date(hour: 14, minute: 0))
        #expect(a.overlaps(with: b))
    }

    @Test
    func timeRangeIsInvalidWhenEndBeforeStart() {
        let range = WorkforceTimeRange(startsAt: date(hour: 12, minute: 0), endsAt: date(hour: 8, minute: 0))
        #expect(!range.isValid)
    }

    // MARK: - Shift template resolution

    @Test
    func templateResolvesToLocalTimeInBerlin() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let monday = try mondayReference(calendar: calendar)

        let template = WorkforceShiftTemplate(
            id: "template",
            name: "Mittag",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 11, minute: 30),
            endTime: WorkforceLocalTime(hour: 15, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [],
            requiredRoles: [],
            requiredQualifications: [],
            targetHeadcount: 1
        )

        let range = try template.resolvedRange(on: monday, calendar: calendar).get()
        let startComponents = calendar.dateComponents([.hour, .minute], from: range.startsAt)
        #expect(startComponents.hour == 11)
        #expect(startComponents.minute == 30)
    }

    @Test
    func templateResolvesOvernightShift() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let monday = try mondayReference(calendar: calendar)

        let template = WorkforceShiftTemplate(
            id: "template-overnight",
            name: "Nacht",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 22, minute: 0),
            endTime: WorkforceLocalTime(hour: 3, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [],
            requiredRoles: [],
            requiredQualifications: [],
            targetHeadcount: 1
        )

        let range = try template.resolvedRange(on: monday, calendar: calendar).get()
        let duration = range.duration
        #expect(duration == 5 * 3600)
        let endDay = calendar.component(.day, from: range.endsAt)
        let startDay = calendar.component(.day, from: range.startsAt)
        #expect(endDay == startDay + 1)
    }

    @Test
    func templateRejectsInvalidLocalTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let monday = try mondayReference(calendar: calendar)

        let template = WorkforceShiftTemplate(
            id: "template-bad",
            name: "Bad",
            weekday: 2,
            startTime: WorkforceLocalTime(hour: 25, minute: 0),
            endTime: WorkforceLocalTime(hour: 26, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [],
            requiredRoles: [],
            requiredQualifications: [],
            targetHeadcount: 1
        )

        let result = template.resolvedRange(on: monday, calendar: calendar)
        #expect(result == .failure(.invalidTimeRange))
    }

    // MARK: - Daylight saving time transitions

    @Test
    func springDSTForwardAdjustsLocalTime() throws {
        // 30 March 2025: clocks jump from 02:00 to 03:00 in Europe/Berlin.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let reference = dateComponents(year: 2025, month: 3, day: 30, calendar: calendar)
        let sunday = calendar.date(from: reference)!

        let template = WorkforceShiftTemplate(
            id: "template-dst",
            name: "Nacht",
            weekday: 1, // Sunday
            startTime: WorkforceLocalTime(hour: 1, minute: 0),
            endTime: WorkforceLocalTime(hour: 4, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [],
            requiredRoles: [],
            requiredQualifications: [],
            targetHeadcount: 1
        )

        let range = try template.resolvedRange(on: sunday, calendar: calendar).get()
        // Wall-clock duration is 3 hours, but UTC duration is 2 hours because of DST.
        let startUTC = range.startsAt.timeIntervalSince1970
        let endUTC = range.endsAt.timeIntervalSince1970
        #expect(endUTC - startUTC == 2 * 3600)
    }

    @Test
    func autumnDSTFallbackAddsExtraHour() throws {
        // 26 October 2025: clocks fall back from 03:00 to 02:00 in Europe/Berlin.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let reference = dateComponents(year: 2025, month: 10, day: 26, calendar: calendar)
        let sunday = calendar.date(from: reference)!

        let template = WorkforceShiftTemplate(
            id: "template-dst-fall",
            name: "Nacht",
            weekday: 1, // Sunday
            startTime: WorkforceLocalTime(hour: 1, minute: 0),
            endTime: WorkforceLocalTime(hour: 4, minute: 0),
            timeZoneIdentifier: "Europe/Berlin",
            stationIDs: [],
            requiredRoles: [],
            requiredQualifications: [],
            targetHeadcount: 1
        )

        let range = try template.resolvedRange(on: sunday, calendar: calendar).get()
        let startUTC = range.startsAt.timeIntervalSince1970
        let endUTC = range.endsAt.timeIntervalSince1970
        #expect(endUTC - startUTC == 4 * 3600)
    }

    // MARK: - Shift lifecycle state machine

    @Test
    func draftCanBePublished() throws {
        let shift = try fixtureShift()
        var mutable = shift
        let result = mutable.publish(at: Date())
        expectSuccess(result)
        #expect(mutable.status == .published)
        #expect(mutable.publishedAt != nil)
    }

    @Test
    func publishedShiftCanBeAccepted() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        let result = shift.accept(at: Date())
        expectSuccess(result)
        #expect(shift.status == .accepted)
    }

    @Test
    func draftCannotBeAcceptedDirectly() throws {
        var shift = try fixtureShift()
        let result = shift.accept(at: Date())
        expectFailure(result, .shiftNotPublished)
    }

    @Test
    func acceptedShiftCannotBeAcceptedAgain() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        _ = shift.accept(at: Date())
        let result = shift.accept(at: Date())
        expectFailure(result, .shiftNotPublished)
    }

    @Test
    func publishedShiftCanBeDeclined() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        let result = shift.decline(at: Date(), reason: "Krank")
        expectSuccess(result)
        #expect(shift.status == .declined)
        #expect(shift.declineReason == "Krank")
    }

    @Test
    func managerCanRevertPublishedShiftToDraft() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        let result = shift.revertToDraft()
        expectSuccess(result)
        #expect(shift.status == .draft)
        #expect(shift.publishedAt == nil)
    }

    @Test
    func publishedShiftCanEnterSwapRequest() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        let result = shift.requestSwap("swap-1")
        expectSuccess(result)
        #expect(shift.status == .swapRequested)
        #expect(shift.swapRequestID?.rawValue == "swap-1")
    }

    @Test
    func acceptedSwapFinalizesBackToPublished() throws {
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        _ = shift.requestSwap("swap-1")
        let result = shift.finalizeSwap(accepted: true)
        expectSuccess(result)
        #expect(shift.status == .published)
        #expect(shift.swapRequestID == nil)
    }

    @Test
    func rejectedSwapFromAcceptedShiftClearsStaleAcceptedAt() throws {
        // A shift that was already accepted, then put up for swap, then the
        // swap is rejected: the shift returns to `published` and must not
        // keep the old `acceptedAt` from before the swap was requested --
        // otherwise status and acceptedAt contradict each other.
        var shift = try fixtureShift()
        _ = shift.publish(at: Date())
        _ = shift.accept(at: Date())
        #expect(shift.acceptedAt != nil)
        _ = shift.requestSwap("swap-2")
        let result = shift.finalizeSwap(accepted: false)
        expectSuccess(result)
        #expect(shift.status == .published)
        #expect(shift.swapRequestID == nil)
        #expect(shift.acceptedAt == nil)
    }

    // MARK: - Swap request lifecycle

    @Test
    func swapRequestCanBeAcceptedAndRejected() throws {
        var swap = WorkforceSwapRequest(
            id: "swap-1",
            requestingShiftID: "shift-a",
            requestedShiftID: "shift-b",
            status: .pending,
            requestedAt: Date()
        )
        let acceptResult = swap.accept(at: Date())
        expectSuccess(acceptResult)
        #expect(swap.status == .accepted)

        var another = WorkforceSwapRequest(
            id: "swap-2",
            requestingShiftID: "shift-a",
            requestedShiftID: "shift-b",
            status: .pending,
            requestedAt: Date()
        )
        let rejectResult = another.reject(at: Date())
        expectSuccess(rejectResult)
        #expect(another.status == .rejected)
    }

    @Test
    func acceptedSwapRequestCannotBeRejectedAgain() {
        var swap = WorkforceSwapRequest(
            id: "swap-1",
            requestingShiftID: "shift-a",
            requestedShiftID: "shift-b",
            status: .accepted,
            requestedAt: Date()
        )
        let result = swap.reject(at: Date())
        expectFailure(result, .swapRequestNotPending)
    }

    // MARK: - Correction request lifecycle

    @Test
    func correctionFlowProducesAuditEntry() throws {
        var request = WorkforceCorrectionRequest(
            id: "corr-1",
            employeeID: "emp-1",
            venueID: "venue-1",
            plannedShiftID: nil,
            requestedKind: .clockIn,
            requestedTimestamp: Date(timeIntervalSince1970: 1_756_000_000),
            reason: "Vergessen",
            status: .draft
        )
        _ = request.submit()
        let audit = try request.approve(by: "manager-1", at: Date()).get()
        #expect(request.status == .approved)
        #expect(audit.employeeID.rawValue == "emp-1")
        #expect(audit.kind == .clockIn)
        #expect(audit.source == .correctionApproved)
    }

    @Test
    func unapprovedCorrectionCannotProduceAuditEntry() {
        var request = WorkforceCorrectionRequest(
            id: "corr-1",
            employeeID: "emp-1",
            venueID: "venue-1",
            plannedShiftID: nil,
            requestedKind: .clockIn,
            requestedTimestamp: Date(),
            reason: "Vergessen",
            status: .draft
        )
        let result = request.approve(by: "manager-1", at: Date())
        expectFailure(result, .invalidStatusTransition)
    }

    // MARK: - Validators

    @Test
    func plannedShiftValidatorRejectsInactiveEmployee() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        var context = fixture.validationContext()
        var inactive = fixture.anna
        inactive.isActive = false
        context.employees[inactive.id] = inactive

        let shift = fixture.plannedShifts[0]
        let result = WorkforcePlannedShiftValidator.validate(shift, in: context)
        expectFailure(result, .employeeNotActive)
    }

    @Test
    func plannedShiftValidatorRejectsMissingQualification() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        var shift = fixture.plannedShifts[0]
        shift.requiredQualifications = [.barLicense]

        let result = WorkforcePlannedShiftValidator.validate(shift, in: context)
        expectFailure(result, .missingQualification(.barLicense))
    }

    @Test
    func plannedShiftValidatorRejectsApprovedLeaveOverlap() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let shift = fixture.plannedShifts[0]
        let leave = WorkforceLeave(
            id: "leave-1",
            employeeID: shift.employeeID,
            range: shift.range,
            timeZoneIdentifier: "Europe/Berlin",
            type: .vacation,
            status: .approved,
            approvedBy: fixture.anna.id,
            note: nil
        )
        let context = fixture.validationContext(leaves: [leave])
        let result = WorkforcePlannedShiftValidator.validate(shift, in: context)
        expectFailure(result, .unavailable)
    }

    @Test
    func plannedShiftValidatorRejectsMissingAvailability() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let shift = fixture.plannedShifts[0]
        let result = WorkforcePlannedShiftValidator.validate(shift, in: context)
        expectFailure(result, .unavailable)
    }

    @Test
    func plannedShiftValidatorAcceptsWithAvailability() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let shift = fixture.plannedShifts[0]
        let availability = WorkforceAvailability(
            id: "avail-1",
            employeeID: shift.employeeID,
            range: WorkforceTimeRange(
                startsAt: shift.range.startsAt.addingTimeInterval(-3600),
                endsAt: shift.range.endsAt.addingTimeInterval(3600)
            ),
            timeZoneIdentifier: "Europe/Berlin"
        )
        let context = fixture.validationContext(availabilities: [availability])
        let result = WorkforcePlannedShiftValidator.validate(shift, in: context)
        #expect(try result.get() == ())
    }

    @Test
    func availabilityValidatorRejectsOverlap() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let base = fixture.plannedShifts[0].range
        let availability = WorkforceAvailability(
            id: "avail-1",
            employeeID: fixture.anna.id,
            range: WorkforceTimeRange(startsAt: base.startsAt, endsAt: base.endsAt),
            timeZoneIdentifier: "Europe/Berlin"
        )
        let overlapping = WorkforceAvailability(
            id: "avail-2",
            employeeID: fixture.anna.id,
            range: WorkforceTimeRange(
                startsAt: base.startsAt.addingTimeInterval(1800),
                endsAt: base.endsAt.addingTimeInterval(1800)
            ),
            timeZoneIdentifier: "Europe/Berlin"
        )
        let context = fixture.validationContext(availabilities: [availability])
        let result = WorkforceAvailabilityValidator.validate(overlapping, in: context)
        expectFailure(result, .overlappingAvailability)
    }

    @Test
    func stationStaffingValidatorDetectsUnderstaffing() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let shift = fixture.plannedShifts[0]
        let result = WorkforceStationStaffingValidator.validate(
            for: shift.stationIDs[0],
            during: shift.range,
            targetHeadcount: 5,
            in: context
        )
        #expect(result == .failure(.understaffedStation(shift.stationIDs[0], required: 5, actual: 1)))
    }

    @Test
    func stationStaffingValidatorAcceptsAdequateStaffing() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let shift = fixture.plannedShifts[0]
        let result = WorkforceStationStaffingValidator.validate(
            for: shift.stationIDs[0],
            during: shift.range,
            targetHeadcount: 1,
            in: context
        )
        #expect(try result.get() == 1)
    }

    @Test
    func timeEntryValidatorRejectsClockInBeforeHireDate() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let event = WorkforceClockEvent(
            id: "clock-1",
            employeeID: fixture.anna.id,
            venueID: fixture.venueID,
            plannedShiftID: nil,
            kind: .clockIn,
            timestamp: fixture.anna.joinedAt.addingTimeInterval(-24 * 3600)
        )
        let result = WorkforceTimeEntryValidator.validate(event, in: context)
        expectFailure(result, .timeEntryBeforeHireDate)
    }

    @Test
    func timeEntryValidatorRejectsInactiveEmployee() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        var context = fixture.validationContext()
        var inactive = fixture.ben
        inactive.isActive = false
        context.employees[inactive.id] = inactive

        let event = WorkforceClockEvent(
            id: "clock-1",
            employeeID: fixture.ben.id,
            venueID: fixture.venueID,
            plannedShiftID: nil,
            kind: .clockIn,
            timestamp: fixture.mondayStart
        )
        let result = WorkforceTimeEntryValidator.validate(event, in: context)
        expectFailure(result, .employeeNotActive)
    }

    @Test
    func breakValidatorRejectsBreakOutsideShift() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let shift = fixture.plannedShifts[0]
        let breakEntry = WorkforceBreakEntry(
            id: "break-1",
            employeeID: shift.employeeID,
            venueID: fixture.venueID,
            plannedShiftID: shift.id,
            range: WorkforceTimeRange(
                startsAt: shift.range.startsAt.addingTimeInterval(-3600),
                endsAt: shift.range.startsAt.addingTimeInterval(-1800)
            ),
            kind: .restBreak
        )
        let result = WorkforceBreakValidator.validate(breakEntry, in: context)
        expectFailure(result, .inconsistentBreak)
    }

    @Test
    func breakValidatorAcceptsBreakInsideShift() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let context = fixture.validationContext()
        let shift = fixture.plannedShifts[0]
        let breakEntry = WorkforceBreakEntry(
            id: "break-1",
            employeeID: shift.employeeID,
            venueID: fixture.venueID,
            plannedShiftID: shift.id,
            range: WorkforceTimeRange(
                startsAt: shift.range.startsAt.addingTimeInterval(3600),
                endsAt: shift.range.startsAt.addingTimeInterval(3900)
            ),
            kind: .restBreak
        )
        let result = WorkforceBreakValidator.validate(breakEntry, in: context)
        expectSuccess(result)
    }

    // MARK: - Fixture consistency

    @Test
    func sandboxFixtureContainsExpectedEmployees() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        #expect(fixture.employees.count == 5)
        #expect(fixture.stations.count == 3)
        #expect(fixture.plannedShifts.count == 4)
    }

    @Test
    func sandboxFixtureShiftIsPublished() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        #expect(fixture.plannedShifts.allSatisfy { $0.isPublished })
    }

    @Test
    func venueShiftIsOvernight() throws {
        let fixture = try WorkforceSandboxWeekFixture()
        let endDay = fixture.calendar.component(.day, from: fixture.venueShift.range.endsAt)
        let startDay = fixture.calendar.component(.day, from: fixture.venueShift.range.startsAt)
        #expect(endDay == startDay + 1)
    }

    // MARK: - Helpers

    private func expectFailure<Success, E: Equatable & Sendable>(
        _ result: Result<Success, E>,
        _ expected: E,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        if case .failure(let error) = result {
            #expect(error == expected, sourceLocation: sourceLocation)
        } else {
            Issue.record("Expected failure \(expected), got success", sourceLocation: sourceLocation)
        }
    }

    private func expectSuccess<E: Equatable & Sendable>(
        _ result: Result<Void, E>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        if case .failure(let error) = result {
            Issue.record("Expected success, got failure \(error)", sourceLocation: sourceLocation)
        }
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 16
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "Europe/Berlin")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private func mondayReference(calendar: Calendar) throws -> Date {
        let reference = dateComponents(year: 2026, month: 7, day: 14, calendar: calendar)
        return calendar.date(from: reference)!
    }

    private func dateComponents(year: Int, month: Int, day: Int, calendar: Calendar) -> DateComponents {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = calendar.timeZone
        return components
    }

    private func fixtureShift() throws -> WorkforcePlannedShift {
        let fixture = try WorkforceSandboxWeekFixture()
        var shift = fixture.plannedShifts[0]
        // Reset to draft so lifecycle tests start from the initial state.
        _ = shift.revertToDraft()
        return shift
    }
}
