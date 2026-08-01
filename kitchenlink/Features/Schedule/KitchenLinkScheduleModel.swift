import Foundation

/// KL-PLAN-001: Zustand des Dienstplans.
///
/// Zwei Blickrichtungen auf denselben Bildschirm, und die Reihenfolge ist
/// Absicht: **zuerst die eigenen Schichten**, denn die betreffen jeden — auch
/// die Planende. Der Wochenplan des Lokals kommt darunter und nur, wer
/// `schedule.manage` trägt, sieht ihn überhaupt.
@MainActor
final class KitchenLinkScheduleModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case working
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var myShifts: [KitchenLinkPlannedShift] = []
    @Published private(set) var venueShifts: [KitchenLinkPlannedShift] = []
    @Published private(set) var team: [KitchenLinkTeamMember] = []
    @Published private(set) var myRole: KitchenLinkMyRole = .none
    /// KL-LEAVE-001: Abwesenheiten gehören auf denselben Bildschirm wie der
    /// Plan — sie sind der Grund, warum eine Woche nicht aufgeht.
    @Published private(set) var myLeaves: [KitchenLinkLeave] = []
    @Published private(set) var venueLeaves: [KitchenLinkLeave] = []
    @Published var notice: String?

    /// Montag der angezeigten Woche, in der Zeitzone des Geräts.
    @Published private(set) var weekStart: Date

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkScheduleTransport
    private let teamTransport: KitchenLinkTeamTransport
    private let leaveTransport: KitchenLinkLeaveTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool
    private let calendar: Calendar

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkScheduleTransport = URLSessionKitchenLinkCloudTransport(),
        teamTransport: KitchenLinkTeamTransport = URLSessionKitchenLinkCloudTransport(),
        leaveTransport: KitchenLinkLeaveTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true,
        now: Date = Date()
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.teamTransport = teamTransport
        self.leaveTransport = leaveTransport
        self.store = store
        self.requiresSession = requiresSession

        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        cal.firstWeekday = 2 // Montag — die Woche eines Betriebs beginnt nicht sonntags.
        self.calendar = cal
        self.weekStart = Self.startOfWeek(for: now, calendar: cal)
    }

    static func make() -> KitchenLinkScheduleModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkScheduleModel()
        }
        return KitchenLinkScheduleModel(
            transport: KitchenLinkDemoScheduleTransport(),
            teamTransport: KitchenLinkDemoTeamTransport(),
            leaveTransport: KitchenLinkDemoLeaveTransport(),
            requiresSession: false
        )
    }

    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard !requiresSession else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    nonisolated static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    // MARK: - Abgeleitete Anzeige

    var canPlan: Bool { myRole.can(.scheduleManage) }

    var weekEnd: Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    /// Die sieben Tage der Woche, jeder mit seinen Schichten.
    var weekDays: [(day: Date, shifts: [KitchenLinkPlannedShift])] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let shifts = venueShifts
                .filter { calendar.isDate($0.startsAt, inSameDayAs: day) }
                .sorted { $0.startsAt < $1.startsAt }
            return (day, shifts)
        }
    }

    /// Was noch niemand gesehen hat. Der Knopf zum Veröffentlichen sagt das
    /// auch — „3 Entwürfe veröffentlichen" statt eines nackten „Veröffentlichen".
    var draftCount: Int { venueShifts.filter { $0.status == .draft }.count }

    /// Eigene Schichten, die auf eine Antwort warten. Sie stehen oben, weil sie
    /// das Einzige auf diesem Bildschirm sind, das etwas von einem will.
    var shiftsAwaitingResponse: [KitchenLinkPlannedShift] {
        myShifts.filter { $0.status.awaitsResponse }
    }

    var confirmedShifts: [KitchenLinkPlannedShift] {
        myShifts.filter { $0.status == .accepted }
    }

    /// Offene Anträge — das Einzige an den Abwesenheiten, das eine Entscheidung
    /// verlangt. Sie stehen deshalb oben, gleich hinter den eigenen Schichten.
    var openLeaveRequests: [KitchenLinkLeave] {
        venueLeaves.filter { $0.status.isOpen }
    }

    var approvedLeaves: [KitchenLinkLeave] {
        venueLeaves.filter { $0.status == .approved }
    }

    /// Eigene Anträge, die noch zurückgezogen werden können.
    var myOpenLeaves: [KitchenLinkLeave] {
        myLeaves.filter { $0.status.isOpen }
    }

    // MARK: - Woche wechseln

    func showWeek(offsetBy weeks: Int) async {
        guard let moved = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) else {
            return
        }
        weekStart = moved
        await load()
    }

    func showCurrentWeek(now: Date = Date()) async {
        weekStart = Self.startOfWeek(for: now, calendar: calendar)
        await load()
    }

    // MARK: - Laden

    func load() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if phase != .working { phase = .loading }
        do {
            myRole = try await teamTransport.loadMyRole(
                config: config, session: session, venueSlug: config.venueSlug
            )
            myShifts = try await transport.loadMyShifts(
                config: config, session: session, venueSlug: config.venueSlug, daysAhead: 21
            )
            myLeaves = try await leaveTransport.loadMyLeaves(
                config: config, session: session, venueSlug: config.venueSlug
            )

            if myRole.can(.scheduleManage) {
                venueShifts = try await transport.loadVenueSchedule(
                    config: config, session: session, venueSlug: config.venueSlug,
                    from: weekStart, to: weekEnd
                )
                // Wer geplant werden kann, steht im Team — die Liste braucht
                // aber `staff.manage`. Ohne das Recht bleibt sie leer und die
                // App bietet das Anlegen nicht an, statt in einen Fehler zu
                // laufen.
                team = myRole.can(.staffManage)
                    ? try await teamTransport.loadTeam(
                        config: config, session: session, venueSlug: config.venueSlug
                    )
                    : []
                venueLeaves = try await leaveTransport.loadVenueLeaves(
                    config: config, session: session, venueSlug: config.venueSlug,
                    onlyOpen: false
                )
            } else {
                venueShifts = []
                team = []
                venueLeaves = []
            }
            phase = .ready
        } catch KitchenLinkCloudServiceError.unauthorized {
            store.clearSession()
            phase = .needsSignIn
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func signIn(email: String, password: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            phase = .failed("E-Mail und Passwort sind erforderlich.")
            return
        }
        phase = .working
        do {
            let session = try await auth.signIn(config: config, email: trimmed, password: password)
            store.save(session: session)
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    // MARK: - Antworten

    func respond(to shift: KitchenLinkPlannedShift, accept: Bool, reason: String? = nil) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            try await transport.respond(
                config: config, session: session, venueSlug: config.venueSlug,
                shiftID: shift.id, accept: accept, reason: reason
            )
            notice = accept
                ? "Schicht angenommen."
                : "Schicht abgelehnt. Die Planung sieht das."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    // MARK: - Planen

    /// Gibt `nil` zurück, wenn geplant wurde, sonst den Grund der Absage —
    /// damit der Bearbeitungsbogen ihn selbst zeigen kann. Ein Hinweis nur auf
    /// dem Bildschirm dahinter wäre unsichtbar, solange der Bogen offen ist.
    func plan(
        userID: String,
        startsAt: Date,
        endsAt: Date,
        area: String?,
        station: String?,
        note: String?,
        shiftID: String? = nil
    ) async -> String? {
        guard let session = currentSession else {
            phase = .needsSignIn
            return "Bitte zuerst anmelden."
        }
        guard endsAt > startsAt else {
            return "Das Ende muss nach dem Beginn liegen."
        }

        phase = .working
        do {
            try await transport.planShift(
                config: config, session: session, venueSlug: config.venueSlug,
                userID: userID, startsAt: startsAt, endsAt: endsAt,
                area: area?.isEmpty == true ? nil : area,
                station: station, note: note?.isEmpty == true ? nil : note,
                shiftID: shiftID
            )
            notice = shiftID == nil ? "Schicht geplant." : "Schicht geändert."
            await load()
            return nil
        } catch {
            phase = .ready
            return Self.explain(Self.message(for: error))
        }
    }

    func delete(_ shift: KitchenLinkPlannedShift) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            try await transport.deleteShift(
                config: config, session: session, venueSlug: config.venueSlug, shiftID: shift.id
            )
            notice = "Schicht gelöscht."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    func publishWeek() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard draftCount > 0 else {
            notice = "In dieser Woche gibt es keine Entwürfe."
            return
        }

        phase = .working
        do {
            let count = try await transport.publish(
                config: config, session: session, venueSlug: config.venueSlug,
                from: weekStart, to: weekEnd
            )
            notice = count == 1
                ? "Eine Schicht veröffentlicht. Sie steht jetzt im Plan des Personals."
                : "\(count) Schichten veröffentlicht. Sie stehen jetzt im Plan des Personals."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    // MARK: - Abwesenheiten

    /// Gibt `nil` zurück, wenn beantragt wurde, sonst den Grund der Absage.
    func requestLeave(
        startsAt: Date,
        endsAt: Date,
        kind: KitchenLinkLeaveKind,
        reason: String?
    ) async -> String? {
        guard let session = currentSession else {
            phase = .needsSignIn
            return "Bitte zuerst anmelden."
        }
        guard endsAt > startsAt else {
            return "Das Ende muss nach dem Beginn liegen."
        }

        phase = .working
        do {
            try await leaveTransport.requestLeave(
                config: config, session: session, venueSlug: config.venueSlug,
                startsAt: startsAt, endsAt: endsAt, kind: kind,
                reason: reason?.isEmpty == true ? nil : reason
            )
            notice = "\(kind.label) beantragt. Die Planung entscheidet."
            await load()
            return nil
        } catch {
            phase = .ready
            return Self.explain(Self.message(for: error))
        }
    }

    func cancelLeave(_ leave: KitchenLinkLeave) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            try await leaveTransport.cancelLeave(
                config: config, session: session, venueSlug: config.venueSlug, leaveID: leave.id
            )
            notice = "Antrag zurückgezogen."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    func review(_ leave: KitchenLinkLeave, approve: Bool, note: String? = nil) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            let decision = try await leaveTransport.reviewLeave(
                config: config, session: session, venueSlug: config.venueSlug,
                leaveID: leave.id, approve: approve,
                note: note?.isEmpty == true ? nil : note
            )
            // Die kollidierenden Schichten werden **nicht** gestrichen — wer
            // sie umbesetzt, entscheidet die Planung. Der Satz sagt das auch.
            if approve, decision.conflictingShiftCount > 0 {
                notice = decision.conflictingShiftCount == 1
                    ? "Genehmigt. Eine geplante Schicht fällt in den Zeitraum und "
                        + "muss neu besetzt werden."
                    : "Genehmigt. \(decision.conflictingShiftCount) geplante Schichten "
                        + "fallen in den Zeitraum und müssen neu besetzt werden."
            } else {
                notice = approve ? "Genehmigt." : "Abgelehnt."
            }
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    /// Die Absagen der Datenbank in einem Satz, der im Betrieb weiterhilft.
    nonisolated static func explain(_ message: String) -> String {
        if message.contains("plan_on_leave") {
            return "Diese Person hat in dem Zeitraum eine genehmigte Abwesenheit."
        }
        if message.contains("leave_already_approved") {
            return "Für diesen Zeitraum ist bereits etwas genehmigt."
        }
        if message.contains("leave_already_decided") {
            return "Darüber ist bereits entschieden."
        }
        if message.contains("leave_not_yours") {
            return "Das ist nicht dein Antrag."
        }
        if message.contains("leave_invalid_range") {
            return "Das Ende muss nach dem Beginn liegen."
        }
        if message.contains("plan_overlaps") {
            return "Diese Person ist in dem Zeitraum schon verplant."
        }
        if message.contains("plan_not_published") {
            return "Darauf lässt sich nicht mehr antworten — die Schicht wurde "
                + "inzwischen geändert."
        }
        if message.contains("plan_not_yours") {
            return "Das ist nicht deine Schicht."
        }
        if message.contains("plan_unknown_staff") {
            return "Diese Person gehört nicht zum Personal."
        }
        if message.contains("plan_invalid_range") {
            return "Das Ende muss nach dem Beginn liegen."
        }
        if message.contains("permission_denied") {
            return "Dafür fehlt diesem Zugang das Recht."
        }
        if message.contains("plan_forbidden") {
            return "Dieser Zugang gehört nicht zum Personal dieses Restaurants."
        }
        return message
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
