import Foundation

// MARK: - Planned shift lifecycle

extension WorkforcePlannedShift {

    /// Veröffentlicht einen Entwurf. Nach Veröffentlichung kann die Schicht von
    /// Mitarbeitern angenommen oder abgelehnt werden.
    mutating func publish(at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .draft else {
            return .failure(.shiftAlreadyPublished)
        }
        status = .published
        publishedAt = date
        return .success(())
    }

    /// Nimmt eine veröffentlichte Schicht an.
    mutating func accept(at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .published else {
            return .failure(.shiftNotPublished)
        }
        status = .accepted
        acceptedAt = date
        return .success(())
    }

    /// Lehnt eine veröffentlichte Schicht ab. Der Entwurf bleibt erhalten, aber
    /// die Zuordnung ist aufgehoben.
    mutating func decline(at date: Date, reason: String?) -> Result<Void, WorkforceValidationError> {
        guard status == .published else {
            return .failure(.shiftNotPublished)
        }
        status = .declined
        declinedAt = date
        declineReason = reason
        return .success(())
    }

    /// Markiert eine veröffentlichte Schicht als Gegenstand einer offenen
    /// Tauschanfrage. Weitere Annahme ist blockiert, bis die Tauschanfrage
    /// entschieden wurde.
    mutating func requestSwap(_ swapID: WorkforceID) -> Result<Void, WorkforceValidationError> {
        guard status == .published || status == .accepted else {
            return .failure(.invalidStatusTransition)
        }
        status = .swapRequested
        swapRequestID = swapID
        return .success(())
    }

    /// Setzt den Zustand nach erfolgreichem Tausch zurück auf veröffentlicht,
    /// damit der neue Inhaber die Schicht annehmen kann.
    mutating func finalizeSwap(accepted: Bool) -> Result<Void, WorkforceValidationError> {
        guard status == .swapRequested else {
            return .failure(.invalidStatusTransition)
        }
        if accepted {
            status = .published
            swapRequestID = nil
            acceptedAt = nil
        } else {
            status = .published
            swapRequestID = nil
        }
        return .success(())
    }

    /// Erlaubt es einem Manager, eine veröffentlichte oder abgelehnte Schicht
    /// wieder in den Entwurf zurückzusetzen, z. B. um Planungsfehler zu korrigieren.
    mutating func revertToDraft() -> Result<Void, WorkforceValidationError> {
        guard status != .draft else {
            return .failure(.invalidStatusTransition)
        }
        status = .draft
        publishedAt = nil
        acceptedAt = nil
        declinedAt = nil
        declineReason = nil
        swapRequestID = nil
        return .success(())
    }
}

// MARK: - Swap request lifecycle

extension WorkforceSwapRequest {

    /// Akzeptiert eine Tauschanfrage. Beide Seiten müssen vorher zugestimmt haben;
    /// dieses Objekt repräsentiert die finale Genehmigung.
    mutating func accept(at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .pending else {
            return .failure(.swapRequestNotPending)
        }
        status = .accepted
        respondedAt = date
        return .success(())
    }

    mutating func reject(at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .pending else {
            return .failure(.swapRequestNotPending)
        }
        status = .rejected
        respondedAt = date
        return .success(())
    }

    mutating func withdraw(at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .pending else {
            return .failure(.swapRequestNotPending)
        }
        status = .withdrawn
        respondedAt = date
        return .success(())
    }
}

// MARK: - Correction request lifecycle

extension WorkforceCorrectionRequest {

    mutating func submit() -> Result<Void, WorkforceValidationError> {
        guard status == .draft else {
            return .failure(.invalidStatusTransition)
        }
        status = .submitted
        return .success(())
    }

    mutating func approve(by reviewerID: WorkforceID, at date: Date) -> Result<WorkforceAuditEntry, WorkforceValidationError> {
        guard status == .submitted else {
            return .failure(.invalidStatusTransition)
        }
        status = .approved
        reviewedBy = reviewerID
        reviewedAt = date

        let audit = WorkforceAuditEntry(
            id: .init(rawValue: "audit-\(id.rawValue)"),
            employeeID: employeeID,
            venueID: venueID,
            plannedShiftID: plannedShiftID,
            kind: requestedKind,
            timestamp: requestedTimestamp,
            source: .correctionApproved,
            deviceID: nil
        )
        return .success(audit)
    }

    mutating func reject(by reviewerID: WorkforceID, at date: Date) -> Result<Void, WorkforceValidationError> {
        guard status == .submitted else {
            return .failure(.invalidStatusTransition)
        }
        status = .rejected
        reviewedBy = reviewerID
        reviewedAt = date
        return .success(())
    }
}
