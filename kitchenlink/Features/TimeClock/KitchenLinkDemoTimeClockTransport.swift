import Foundation

/// KL-TIME-001: Sandbox-Demo der Stempeluhr ohne Cloud.
///
/// Er verhält sich wie die Datenbank — zweimal einstempeln wird abgewiesen,
/// Pausen gehen von der Nettozeit ab, das Ausstempeln beendet eine laufende
/// Pause mit, eine Korrektur behält den Originalwert —, damit die Demo nichts
/// anderes zeigt als der echte Weg.
///
/// **Es wird keine Arbeitszeit erfasst.**
actor KitchenLinkDemoTimeClockTransport: KitchenLinkTimeClockTransport {
    private struct Entry {
        var id: String
        var userID: String
        var email: String
        var roleName: String
        var startedAt: Date
        var endedAt: Date?
        var breaks: [(started: Date, ended: Date?)] = []
        var corrected = false
        var correctionReason: String?

        var isOpen: Bool { endedAt == nil }

        func totals(now: Date) -> KitchenLinkTimeTotals {
            let end = endedAt ?? now
            let gross = max(0, Int(end.timeIntervalSince(startedAt)))
            let paused = breaks.reduce(0) { sum, b in
                sum + max(0, Int(min(b.ended ?? now, end).timeIntervalSince(b.started)))
            }
            return KitchenLinkTimeTotals(
                grossSeconds: gross,
                breakSeconds: paused,
                netSeconds: max(0, gross - paused)
            )
        }
    }

    private let meID = "demo-me"
    private var entries: [Entry]

    init(seeded: Bool = true) {
        guard seeded else {
            entries = []
            return
        }
        let now = Date()
        entries = [
            // Eine bereits beendete eigene Schicht von heute Vormittag.
            Entry(
                id: "demo-entry-1", userID: "demo-me", email: "du@restaurant.de",
                roleName: "Inhaber",
                startedAt: now.addingTimeInterval(-6 * 3600),
                endedAt: now.addingTimeInterval(-3 * 3600),
                breaks: [(now.addingTimeInterval(-5 * 3600),
                          now.addingTimeInterval(-4.5 * 3600))]
            ),
            // Zwei Kolleginnen stehen gerade auf der Uhr.
            Entry(
                id: "demo-entry-2", userID: "demo-2", email: "sarah@restaurant.de",
                roleName: "Schichtleitung",
                startedAt: now.addingTimeInterval(-2 * 3600), endedAt: nil
            ),
            Entry(
                id: "demo-entry-3", userID: "demo-4", email: "mira@restaurant.de",
                roleName: "Küche",
                startedAt: now.addingTimeInterval(-4 * 3600), endedAt: nil,
                breaks: [(now.addingTimeInterval(-1800), nil)]
            ),
            // Ein vergessener Ausstempel von gestern — der Fall, für den es die
            // Korrektur gibt.
            Entry(
                id: "demo-entry-4", userID: "demo-3", email: "jonas@restaurant.de",
                roleName: "Service",
                startedAt: now.addingTimeInterval(-20 * 3600), endedAt: nil
            )
        ]
    }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    private var myOpenIndex: Int? {
        entries.firstIndex { $0.userID == meID && $0.isOpen }
    }

    func loadStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkTimeStatus {
        let now = Date()
        let mine = entries.filter { $0.userID == meID }
        let open = myOpenIndex.map { entries[$0] }
        let runningBreak = open?.breaks.first { $0.ended == nil }

        return KitchenLinkTimeStatus(
            clockedIn: open != nil,
            entryID: open?.id,
            startedAt: open?.startedAt,
            onBreak: runningBreak != nil,
            breakStartedAt: runningBreak?.started,
            current: open?.totals(now: now),
            todayNetSeconds: mine.reduce(0) { $0 + $1.totals(now: now).netSeconds },
            today: mine
                .sorted { $0.startedAt > $1.startedAt }
                .map { entry in
                    KitchenLinkTimeEntry(
                        id: entry.id, startedAt: entry.startedAt, endedAt: entry.endedAt,
                        status: entry.isOpen ? "open" : "closed",
                        corrected: entry.corrected, totals: entry.totals(now: now)
                    )
                }
        )
    }

    func clockIn(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        guard myOpenIndex == nil else { throw fail("time_already_clocked_in") }
        entries.append(
            Entry(
                id: "demo-entry-\(entries.count + 1)", userID: meID,
                email: "du@restaurant.de", roleName: "Inhaber",
                startedAt: Date(), endedAt: nil
            )
        )
    }

    func clockOut(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        guard let index = myOpenIndex else { throw fail("time_not_clocked_in") }
        let now = Date()
        for i in entries[index].breaks.indices where entries[index].breaks[i].ended == nil {
            entries[index].breaks[i].ended = now
        }
        entries[index].endedAt = now
    }

    func startBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkBreakKind
    ) async throws {
        guard let index = myOpenIndex else { throw fail("time_not_clocked_in") }
        guard !entries[index].breaks.contains(where: { $0.ended == nil }) else {
            throw fail("time_break_already_running")
        }
        entries[index].breaks.append((Date(), nil))
    }

    func endBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        guard let index = myOpenIndex else { throw fail("time_not_clocked_in") }
        guard let breakIndex = entries[index].breaks.firstIndex(where: { $0.ended == nil }) else {
            throw fail("time_no_open_break")
        }
        entries[index].breaks[breakIndex].ended = Date()
    }

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysBack: Int
    ) async throws -> [KitchenLinkTeamTimeEntry] {
        let now = Date()
        return entries
            .sorted { $0.startedAt > $1.startedAt }
            .map { entry in
                KitchenLinkTeamTimeEntry(
                    id: entry.id, userID: entry.userID, email: entry.email,
                    roleName: entry.roleName,
                    startedAt: entry.startedAt, endedAt: entry.endedAt,
                    status: entry.isOpen ? "open" : "closed",
                    onBreak: entry.breaks.contains { $0.ended == nil },
                    corrected: entry.corrected,
                    correctionReason: entry.correctionReason,
                    totals: entry.totals(now: now)
                )
            }
    }

    func correct(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        entryID: String,
        reason: String,
        endedAt: Date
    ) async throws {
        guard reason.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            throw fail("time_correction_needs_reason")
        }
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            throw fail("time_unknown_entry")
        }
        guard endedAt > entries[index].startedAt else {
            throw fail("time_correction_invalid_range")
        }
        for i in entries[index].breaks.indices where entries[index].breaks[i].ended == nil {
            entries[index].breaks[i].ended = endedAt
        }
        entries[index].endedAt = endedAt
        entries[index].corrected = true
        entries[index].correctionReason = reason
    }
}
