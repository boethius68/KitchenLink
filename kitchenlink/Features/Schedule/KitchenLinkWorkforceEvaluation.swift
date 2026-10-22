import Foundation

/// KL-WORKFORCE-EVAL-001: Soll-/Ist-Vergleich und Überstunden-Berechnung (Blueprint §9.3).
///
/// Verbindet den Dienstplan (Soll-Stunden aus `KitchenLinkPlannedShift`) mit der
/// Zeiterfassung (Ist-Stunden aus `KitchenLinkTimeTotals` / `KitchenLinkTeamTimeEntry`).

/// Gesetzliche Pausenkonformität nach § 4 deutsches Arbeitszeitgesetz (ArbZG).
struct KitchenLinkBreakCompliance: Equatable, Sendable {
    /// Ob die gesetzlichen Mindestpausen eingehalten wurden.
    let isCompliant: Bool
    /// Gesetzlich geforderte Mindestpause in Sekunden.
    let requiredBreakSeconds: Int
    /// Tatsächlich genommene Pause in Sekunden.
    let actualBreakSeconds: Int
    /// Fehlende Pause in Sekunden (Defizit).
    let deficitSeconds: Int
    /// Hinweistext bei Nichteinhaltung (z. B. "Mindestpause von 30 Min. unterschritten").
    let notice: String?

    static func evaluate(grossWorkSeconds: Int, actualBreakSeconds: Int) -> KitchenLinkBreakCompliance {
        let requiredSeconds: Int
        if grossWorkSeconds > 9 * 3600 {
            requiredSeconds = 45 * 60 // 45 Minuten ab 9 Stunden
        } else if grossWorkSeconds > 6 * 3600 {
            requiredSeconds = 30 * 60 // 30 Minuten ab 6 Stunden
        } else {
            requiredSeconds = 0
        }

        let deficit = max(0, requiredSeconds - actualBreakSeconds)
        let isCompliant = deficit == 0
        let notice: String?
        if !isCompliant {
            let reqMinutes = requiredSeconds / 60
            let actMinutes = actualBreakSeconds / 60
            notice = "Gesetzliche Mindestpause von \(reqMinutes) Min. unterschritten (\(actMinutes) Min. erfasst, § 4 ArbZG)."
        } else {
            notice = nil
        }

        return KitchenLinkBreakCompliance(
            isCompliant: isCompliant,
            requiredBreakSeconds: requiredSeconds,
            actualBreakSeconds: actualBreakSeconds,
            deficitSeconds: deficit,
            notice: notice
        )
    }
}

/// Einzelauswertung für einen Mitarbeiter im gewählten Zeitraum.
struct KitchenLinkEmployeeWorkforceEvaluation: Identifiable, Equatable, Sendable {
    let id: String
    let userID: String
    let displayName: String
    let roleName: String?
    /// Geplante Arbeitszeit in Sekunden (Soll).
    let targetSeconds: Int
    /// Tatsächliche Netto-Arbeitszeit in Sekunden (Ist).
    let actualNetSeconds: Int
    /// Tatsächliche Brutto-Arbeitszeit vor Pausenabzug.
    let actualGrossSeconds: Int
    /// Erfasste Pausenzeit in Sekunden.
    let actualBreakSeconds: Int
    /// Über-/Minusstunden in Sekunden (positiv = Überstunden, negativ = Minusstunden).
    let deltaSeconds: Int
    /// Gesetzliche Pausenprüfung nach ArbZG.
    let breakCompliance: KitchenLinkBreakCompliance

    var targetHours: Double { Double(targetSeconds) / 3600.0 }
    var actualHours: Double { Double(actualNetSeconds) / 3600.0 }
    var deltaHours: Double { Double(deltaSeconds) / 3600.0 }
    var isOvertime: Bool { deltaSeconds > 0 }
    var isUndertime: Bool { deltaSeconds < 0 }

    /// Formatierter Differenzstring, z. B. "+1 Std. 30 Min." oder "-45 Min."
    var formattedDelta: String {
        KitchenLinkWorkforceEvaluationFormatter.formatDelta(seconds: deltaSeconds)
    }

    var formattedTarget: String {
        KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: targetSeconds)
    }

    var formattedActual: String {
        KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: actualNetSeconds)
    }
}

/// Aggregierte Gesamtauswertung über alle Mitarbeiter.
struct KitchenLinkTeamWorkforceEvaluation: Equatable, Sendable {
    let evaluations: [KitchenLinkEmployeeWorkforceEvaluation]
    let totalTargetSeconds: Int
    let totalActualNetSeconds: Int
    let totalDeltaSeconds: Int
    let employeeCount: Int
    let breakViolationsCount: Int

    static let empty = KitchenLinkTeamWorkforceEvaluation(
        evaluations: [],
        totalTargetSeconds: 0,
        totalActualNetSeconds: 0,
        totalDeltaSeconds: 0,
        employeeCount: 0,
        breakViolationsCount: 0
    )

    static func calculate(
        plannedShifts: [KitchenLinkPlannedShift],
        timeEntries: [KitchenLinkTeamTimeEntry]
    ) -> KitchenLinkTeamWorkforceEvaluation {
        // Sammle alle eindeutigen Benutzer
        var userIDs = Set<String>()
        var namesByUserID: [String: String] = [:]
        var rolesByUserID: [String: String] = [:]

        for shift in plannedShifts {
            if let uid = shift.userID {
                userIDs.insert(uid)
                namesByUserID[uid] = shift.displayName
                if let role = shift.roleName { rolesByUserID[uid] = role }
            }
        }
        for entry in timeEntries {
            userIDs.insert(entry.userID)
            namesByUserID[entry.userID] = entry.displayName
            if let role = entry.roleName { rolesByUserID[entry.userID] = role }
        }

        var results: [KitchenLinkEmployeeWorkforceEvaluation] = []
        var totalTarget = 0
        var totalActual = 0
        var totalDelta = 0
        var violations = 0

        for uid in userIDs.sorted() {
            // Berechne Soll aus geplanten Schichten (nur akzeptierte oder veröffentlichte Schichten zählen)
            let userShifts = plannedShifts.filter { $0.userID == uid && $0.status != .declined }
            let targetSeconds = userShifts.reduce(0) { $0 + $1.durationSeconds }

            // Berechne Ist aus Zeiterfassungseinträgen
            let userEntries = timeEntries.filter { $0.userID == uid }
            let actualNet = userEntries.reduce(0) { $0 + $1.totals.netSeconds }
            let actualGross = userEntries.reduce(0) { $0 + $1.totals.grossSeconds }
            let actualBreak = userEntries.reduce(0) { $0 + $1.totals.breakSeconds }

            let delta = actualNet - targetSeconds
            let compliance = KitchenLinkBreakCompliance.evaluate(
                grossWorkSeconds: actualGross,
                actualBreakSeconds: actualBreak
            )

            if !compliance.isCompliant {
                violations += 1
            }

            let eval = KitchenLinkEmployeeWorkforceEvaluation(
                id: uid,
                userID: uid,
                displayName: namesByUserID[uid] ?? String(uid.prefix(8)),
                roleName: rolesByUserID[uid],
                targetSeconds: targetSeconds,
                actualNetSeconds: actualNet,
                actualGrossSeconds: actualGross,
                actualBreakSeconds: actualBreak,
                deltaSeconds: delta,
                breakCompliance: compliance
            )

            results.append(eval)
            totalTarget += targetSeconds
            totalActual += actualNet
            totalDelta += delta
        }

        return KitchenLinkTeamWorkforceEvaluation(
            evaluations: results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            totalTargetSeconds: totalTarget,
            totalActualNetSeconds: totalActual,
            totalDeltaSeconds: totalDelta,
            employeeCount: results.count,
            breakViolationsCount: violations
        )
    }
}

/// Formatierungshelfer für Arbeitszeiten und Abweichungen.
enum KitchenLinkWorkforceEvaluationFormatter {
    static func formatHoursMinutes(seconds: Int) -> String {
        let absSec = abs(seconds)
        let hours = absSec / 3600
        let minutes = (absSec % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours) Std. \(minutes) Min."
        } else if hours > 0 {
            return "\(hours) Std."
        } else {
            return "\(minutes) Min."
        }
    }

    static func formatDelta(seconds: Int) -> String {
        if seconds == 0 {
            return "±0 Min."
        }
        let sign = seconds > 0 ? "+" : "-"
        let text = formatHoursMinutes(seconds: abs(seconds))
        return "\(sign)\(text)"
    }
}
