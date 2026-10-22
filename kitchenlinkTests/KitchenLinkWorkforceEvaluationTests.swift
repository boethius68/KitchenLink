import Testing
import Foundation
@testable import kitchenlink

struct KitchenLinkWorkforceEvaluationTests {

    @Test func testBreakComplianceUnder6Hours() {
        // Unter 6 Stunden keine gesetzliche Mindestpause
        let compliance = KitchenLinkBreakCompliance.evaluate(
            grossWorkSeconds: 5 * 3600,
            actualBreakSeconds: 0
        )
        #expect(compliance.isCompliant == true)
        #expect(compliance.requiredBreakSeconds == 0)
        #expect(compliance.deficitSeconds == 0)
        #expect(compliance.notice == nil)
    }

    @Test func testBreakComplianceBetween6And9HoursCompliant() {
        // 8 Stunden Arbeit mit 30 Min. Pause -> konform
        let compliance = KitchenLinkBreakCompliance.evaluate(
            grossWorkSeconds: 8 * 3600,
            actualBreakSeconds: 30 * 60
        )
        #expect(compliance.isCompliant == true)
        #expect(compliance.requiredBreakSeconds == 1800)
        #expect(compliance.deficitSeconds == 0)
    }

    @Test func testBreakComplianceBetween6And9HoursDeficit() {
        // 8 Stunden Arbeit mit nur 15 Min. Pause -> Verstoß (15 Min. Defizit)
        let compliance = KitchenLinkBreakCompliance.evaluate(
            grossWorkSeconds: 8 * 3600,
            actualBreakSeconds: 15 * 60
        )
        #expect(compliance.isCompliant == false)
        #expect(compliance.requiredBreakSeconds == 1800)
        #expect(compliance.deficitSeconds == 900)
        #expect(compliance.notice?.contains("30 Min.") == true)
    }

    @Test func testBreakComplianceOver9HoursDeficit() {
        // 10 Stunden Arbeit mit nur 30 Min. Pause -> Verstoß (ab 9h sind 45 Min. nötig)
        let compliance = KitchenLinkBreakCompliance.evaluate(
            grossWorkSeconds: 10 * 3600,
            actualBreakSeconds: 30 * 60
        )
        #expect(compliance.isCompliant == false)
        #expect(compliance.requiredBreakSeconds == 2700)
        #expect(compliance.deficitSeconds == 900)
        #expect(compliance.notice?.contains("45 Min.") == true)
    }

    @Test func testFormatting() {
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: 0) == "0 Min.")
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: 1800) == "30 Min.")
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: 3600) == "1 Std.")
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: 5400) == "1 Std. 30 Min.")

        #expect(KitchenLinkWorkforceEvaluationFormatter.formatDelta(seconds: 0) == "±0 Min.")
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatDelta(seconds: 3600) == "+1 Std.")
        #expect(KitchenLinkWorkforceEvaluationFormatter.formatDelta(seconds: -1800) == "-30 Min.")
    }

    @Test func testTeamWorkforceEvaluationCalculation() {
        let now = Date()
        let shiftAnna = KitchenLinkPlannedShift(
            id: "ps-1",
            userID: "u-anna",
            email: "anna@kitchenlink.test",
            roleName: "Service",
            startsAt: now,
            endsAt: now.addingTimeInterval(8 * 3600), // 8 Stunden Soll
            area: "Gastraum",
            station: nil,
            status: .accepted,
            note: nil,
            declineReason: nil
        )

        let shiftBen = KitchenLinkPlannedShift(
            id: "ps-2",
            userID: "u-ben",
            email: "ben@kitchenlink.test",
            roleName: "Küche",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600), // 6 Stunden Soll
            area: "Küche",
            station: "kitchen",
            status: .published,
            note: nil,
            declineReason: nil
        )

        // Anna hat 8,5 Stunden gearbeitet (inkl. 30m Pause) -> Netto 8h -> genau Soll (0 Delta)
        let timeAnna = KitchenLinkTeamTimeEntry(
            id: "te-1",
            userID: "u-anna",
            email: "anna@kitchenlink.test",
            roleName: "Service",
            startedAt: now,
            endedAt: now.addingTimeInterval(8.5 * 3600),
            status: "closed",
            onBreak: false,
            corrected: false,
            correctionReason: nil,
            totals: KitchenLinkTimeTotals(
                grossSeconds: Int(8.5 * 3600),
                breakSeconds: 1800,
                netSeconds: 8 * 3600
            )
        )

        // Ben hat 7 Stunden gearbeitet (inkl. 30m Pause) -> Netto 6,5h -> +30 Min. Überstunden
        let timeBen = KitchenLinkTeamTimeEntry(
            id: "te-2",
            userID: "u-ben",
            email: "ben@kitchenlink.test",
            roleName: "Küche",
            startedAt: now,
            endedAt: now.addingTimeInterval(7 * 3600),
            status: "closed",
            onBreak: false,
            corrected: false,
            correctionReason: nil,
            totals: KitchenLinkTimeTotals(
                grossSeconds: 7 * 3600,
                breakSeconds: 1800,
                netSeconds: Int(6.5 * 3600)
            )
        )

        let teamEval = KitchenLinkTeamWorkforceEvaluation.calculate(
            plannedShifts: [shiftAnna, shiftBen],
            timeEntries: [timeAnna, timeBen]
        )

        #expect(teamEval.employeeCount == 2)
        #expect(teamEval.totalTargetSeconds == 14 * 3600) // 8 + 6 = 14h Soll
        #expect(teamEval.totalActualNetSeconds == Int(14.5 * 3600)) // 8 + 6.5 = 14.5h Ist
        #expect(teamEval.totalDeltaSeconds == 1800) // +30 Min. Überstunden im Team
        #expect(teamEval.breakViolationsCount == 0) // Beide haben 30 Min. Pause gemacht

        let evalBen = teamEval.evaluations.first { $0.userID == "u-ben" }
        #expect(evalBen != nil)
        #expect(evalBen?.isOvertime == true)
        #expect(evalBen?.formattedDelta == "+30 Min.")
    }
}
