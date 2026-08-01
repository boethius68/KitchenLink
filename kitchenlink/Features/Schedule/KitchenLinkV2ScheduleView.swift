import SwiftUI

/// KL-PLAN-001: „Dienstplan" — wer kommt wann.
///
/// Die Reihenfolge ist Absicht: **oben, was von einem will** — eigene
/// Schichten, die auf eine Antwort warten. Darunter die eigenen bestätigten,
/// und erst ganz unten die Woche des Lokals, die nur die Planung sieht.
struct KitchenLinkV2ScheduleView: View {
    @StateObject private var model = KitchenLinkScheduleModel.make()
    @State private var editing: KitchenLinkScheduleDraft?
    @State private var decliningShift: KitchenLinkPlannedShift?
    @State private var declineReason = ""
    @State private var requestingLeave = false
    @State private var editingRequirements = false

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    switch model.phase {
                    case .loading:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Dienstplan wird geladen …")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                        }
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await model.signIn(email: email, password: password)
                        }
                    case .failed(let message):
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                                Text(message)
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Erneut versuchen") { Task { await model.load() } }
                                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                            }
                        }
                    case .ready, .working:
                        if !model.shiftsAwaitingResponse.isEmpty {
                            awaitingSection
                        }
                        myShiftsSection
                        // Die offenen Antraege stehen direkt hinter den eigenen
                        // Schichten: sie sind das Zweite, was eine Entscheidung
                        // verlangt.
                        if model.canPlan, !model.openLeaveRequests.isEmpty {
                            leaveRequestsSection
                        }
                        myLeavesSection
                        if model.canPlan {
                            weekSection
                        }
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("schedule.notice")
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Dienstplan")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await model.load() }
        .sheet(item: $editing) { draft in
            KitchenLinkV2ShiftEditorSheet(
                draft: draft,
                team: model.team
            ) { userID, start, end, area, station, note in
                let failure = await model.plan(
                    userID: userID, startsAt: start, endsAt: end,
                    area: area, station: station, note: note, shiftID: draft.shiftID
                )
                if failure == nil { editing = nil }
                return failure
            } onCancel: {
                editing = nil
            }
        }
        .sheet(isPresented: $requestingLeave) {
            KitchenLinkV2LeaveRequestSheet { start, end, kind, reason in
                let failure = await model.requestLeave(
                    startsAt: start, endsAt: end, kind: kind, reason: reason
                )
                if failure == nil { requestingLeave = false }
                return failure
            } onCancel: {
                requestingLeave = false
            }
        }
        .sheet(isPresented: $editingRequirements) {
            KitchenLinkV2StaffingRequirementsSheet(
                requirements: model.requirements
            ) { weekday, start, end, target, station in
                await model.addRequirement(
                    weekday: weekday, startsAtLocal: start, endsAtLocal: end,
                    targetHeadcount: target, station: station
                )
            } onDelete: { requirement in
                await model.deleteRequirement(requirement)
            } onClose: {
                editingRequirements = false
            }
        }
        .alert(
            "Schicht ablehnen",
            isPresented: Binding(
                get: { decliningShift != nil },
                set: { if !$0 { decliningShift = nil; declineReason = "" } }
            )
        ) {
            TextField("Grund", text: $declineReason)
            Button("Ablehnen", role: .destructive) {
                if let shift = decliningShift {
                    let reason = declineReason
                    Task { await model.respond(to: shift, accept: false, reason: reason) }
                }
                decliningShift = nil
                declineReason = ""
            }
            Button("Abbrechen", role: .cancel) {
                decliningShift = nil
                declineReason = ""
            }
        } message: {
            Text("Die Planung sieht den Grund und kann die Schicht neu besetzen.")
        }
    }

    // MARK: - Wartet auf Antwort

    private var awaitingSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("BITTE BESTÄTIGEN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            ForEach(model.shiftsAwaitingResponse) { shift in
                KitchenLinkV2Card {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                        shiftHeadline(shift)

                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            Button("Annehmen") {
                                Task { await model.respond(to: shift, accept: true) }
                            }
                            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                            .accessibilityIdentifier("schedule.accept.\(shift.id)")

                            Button("Ablehnen") { decliningShift = shift }
                                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                                .accessibilityIdentifier("schedule.decline.\(shift.id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Eigene Schichten

    private var myShiftsSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("MEINE SCHICHTEN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            if model.confirmedShifts.isEmpty {
                KitchenLinkV2Card {
                    Text(model.shiftsAwaitingResponse.isEmpty
                         ? "Für dich ist gerade nichts eingeteilt."
                         : "Noch nichts bestätigt.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
            } else {
                KitchenLinkV2Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.confirmedShifts.enumerated()), id: \.element.id) { index, shift in
                            if index > 0 {
                                Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                shiftHeadline(shift)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, KitchenLinkV2Spacing.large)
                            .padding(.vertical, KitchenLinkV2Spacing.small)
                        }
                    }
                }
            }
        }
    }

    private func shiftHeadline(_ shift: KitchenLinkPlannedShift) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(KitchenLinkV2ScheduleDateText.dayAndRange(shift.startsAt, shift.endsAt))
                .font(KitchenLinkV2Typography.primaryLine)
                .kitchenLinkV2TabularNumbers()
            if let place = shift.placeLine {
                Text(place)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
            if let note = shift.note {
                Text(note)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Abwesenheiten

    private var leaveRequestsSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("OFFENE ABWESENHEITSANTRÄGE")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            ForEach(model.openLeaveRequests) { leave in
                KitchenLinkV2Card {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(leave.displayName) · \(leave.kind.label)")
                                .font(KitchenLinkV2Typography.primaryLine)
                            Text(KitchenLinkV2ScheduleDateText.dayRange(
                                leave.startsAt, leave.endsAt))
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                .kitchenLinkV2TabularNumbers()
                            if let reason = leave.reason {
                                Text(reason)
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            }
                        }

                        // Die Zahl, die den Ausschlag gibt: eine Genehmigung
                        // wird trotzdem erteilt, aber diese Schichten muessen
                        // dann neu besetzt werden.
                        if leave.conflictingShifts > 0 {
                            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .accessibilityHidden(true)
                                Text(leave.conflictingShifts == 1
                                     ? "Eine geplante Schicht fällt in den Zeitraum und "
                                        + "müsste neu besetzt werden."
                                     : "\(leave.conflictingShifts) geplante Schichten fallen "
                                        + "in den Zeitraum und müssten neu besetzt werden.")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                            .accessibilityIdentifier("schedule.leaveConflict.\(leave.id)")
                        }

                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            Button("Genehmigen") {
                                Task { await model.review(leave, approve: true) }
                            }
                            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                            .accessibilityIdentifier("schedule.approveLeave.\(leave.id)")

                            Button("Ablehnen") {
                                Task { await model.review(leave, approve: false) }
                            }
                            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                            .accessibilityIdentifier("schedule.rejectLeave.\(leave.id)")
                        }
                    }
                }
            }
        }
    }

    private var myLeavesSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Text("MEINE ABWESENHEITEN")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Spacer(minLength: 0)
                Button {
                    requestingLeave = true
                } label: {
                    Image(systemName: "plus").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Abwesenheit beantragen")
                .accessibilityIdentifier("schedule.requestLeave")
            }

            if model.myLeaves.isEmpty {
                KitchenLinkV2Card {
                    Text("Nichts beantragt.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
            } else {
                KitchenLinkV2Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.myLeaves.enumerated()), id: \.element.id) { index, leave in
                            if index > 0 {
                                Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                            }
                            myLeaveRow(leave)
                        }
                    }
                }
            }
        }
    }

    private func myLeaveRow(_ leave: KitchenLinkLeave) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(leave.kind.label)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(KitchenLinkV2ScheduleDateText.dayRange(leave.startsAt, leave.endsAt))
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .kitchenLinkV2TabularNumbers()
                if let note = leave.reviewNote {
                    Text(note)
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }
            }
            Spacer(minLength: 0)
            // Nur ein offener Antrag lässt sich zurückziehen — über eine
            // entschiedene Abwesenheit entscheidet die Planung.
            if leave.status.isOpen {
                Button("Zurückziehen") { Task { await model.cancelLeave(leave) } }
                    .font(KitchenLinkV2Typography.meta)
                    .accessibilityIdentifier("schedule.cancelLeave.\(leave.id)")
            } else {
                Text(leave.status.label)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(
                        leave.status == .approved
                            ? KitchenLinkV2Palette.Urgency.freshSymbol
                            : KitchenLinkV2Palette.Content.muted
                    )
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
    }

    // MARK: - Woche des Lokals

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Text("WOCHE DES LOKALS")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Spacer(minLength: 0)
                Button {
                    Task { await model.showWeek(offsetBy: -1) }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Woche zurück")
                .accessibilityIdentifier("schedule.previousWeek")

                Button {
                    Task { await model.showWeek(offsetBy: 1) }
                } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Woche vor")
                .accessibilityIdentifier("schedule.nextWeek")
            }

            HStack(spacing: KitchenLinkV2Spacing.small) {
                Text(KitchenLinkV2ScheduleDateText.weekRange(model.weekStart))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .accessibilityIdentifier("schedule.weekLabel")

                // Die eine Zahl, die sagt, ob der Plan aufgeht.
                if model.missingThisWeek > 0 {
                    Text(model.missingThisWeek == 1
                         ? "· eine Person fehlt"
                         : "· \(model.missingThisWeek) Personen fehlen")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .accessibilityIdentifier("schedule.weekShortfall")
                }

                Spacer(minLength: 0)

                Button {
                    editingRequirements = true
                } label: {
                    Image(systemName: "person.2.badge.gearshape")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Sollbesetzung bearbeiten")
                .accessibilityIdentifier("schedule.openRequirements")
            }

            ForEach(model.weekDays, id: \.day) { entry in
                dayCard(entry.day, shifts: entry.shifts)
            }

            if model.draftCount > 0 {
                Button(model.draftCount == 1
                       ? "Einen Entwurf veröffentlichen"
                       : "\(model.draftCount) Entwürfe veröffentlichen") {
                    Task { await model.publishWeek() }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(model.phase == .working)
                .accessibilityIdentifier("schedule.publish")

                Text("Erst danach steht die Woche im Plan des Personals. "
                     + "Entwürfe sieht nur die Planung.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func dayCard(_ day: Date, shifts: [KitchenLinkPlannedShift]) -> some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack {
                    Text(KitchenLinkV2ScheduleDateText.weekday(day))
                        .font(KitchenLinkV2Typography.primaryLine)
                    Spacer(minLength: 0)
                    if !model.team.isEmpty {
                        Button {
                            editing = KitchenLinkScheduleDraft(day: day)
                        } label: {
                            Image(systemName: "plus").frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("Schicht am \(KitchenLinkV2ScheduleDateText.weekday(day)) anlegen")
                        .accessibilityIdentifier("schedule.add.\(KitchenLinkV2ScheduleDateText.dayKey(day))")
                    }
                }

                // Was fehlt, steht direkt am Tag — das ist die Frage, die eine
                // Planende beim Blick auf die Woche wirklich hat.
                ForEach(model.shortfalls(on: day)) { gap in
                    HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(shortfallText(gap))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .accessibilityIdentifier("schedule.shortfall.\(gap.id)")
                }

                if shifts.isEmpty {
                    Text("Niemand eingeteilt.")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                } else {
                    ForEach(shifts) { shift in
                        Button {
                            editing = KitchenLinkScheduleDraft(shift: shift)
                        } label: {
                            planRow(shift)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("schedule.shift.\(shift.id)")
                    }
                }
            }
        }
    }

    /// „17:00–23:00 · 2 von 3 · eine fehlt" — der Satz sagt Fenster, Stand und
    /// Lücke in der Reihenfolge, in der man sie liest.
    private func shortfallText(_ gap: KitchenLinkStaffingCoverage) -> String {
        var parts = [KitchenLinkV2ScheduleDateText.range(gap.startsAt, gap.endsAt)]
        if let station = gap.stationLabel { parts.append(station) }
        parts.append("\(gap.plannedHeadcount) von \(gap.targetHeadcount)")
        parts.append(gap.missing == 1 ? "eine fehlt" : "\(gap.missing) fehlen")
        return parts.joined(separator: " · ")
    }

    private func planRow(_ shift: KitchenLinkPlannedShift) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(shift.displayName)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text([
                    KitchenLinkV2ScheduleDateText.range(shift.startsAt, shift.endsAt),
                    shift.placeLine
                ].compactMap { $0 }.joined(separator: " · "))
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                if shift.status == .declined, let reason = shift.declineReason {
                    Text("abgelehnt: \(reason)")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                }
            }
            Spacer(minLength: 0)
            statusBadge(shift.status)
        }
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
        .contentShape(Rectangle())
    }

    private func statusBadge(_ status: KitchenLinkShiftPlanStatus) -> some View {
        Text(status.label)
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(
                status == .declined
                    ? KitchenLinkV2Palette.Urgency.waitingText
                    : (status == .accepted
                        ? KitchenLinkV2Palette.Urgency.freshSymbol
                        : KitchenLinkV2Palette.Content.muted)
            )
            .padding(.horizontal, KitchenLinkV2Spacing.xSmall)
            .background(
                KitchenLinkV2Palette.Surface.recessed,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.label, style: .continuous)
            )
    }
}

/// Was der Bogen bearbeitet: ein neuer Eintrag an einem Tag oder eine
/// vorhandene Schicht.
struct KitchenLinkScheduleDraft: Identifiable {
    let id = UUID()
    let shiftID: String?
    let userID: String?
    let startsAt: Date
    let endsAt: Date
    let area: String
    let station: String?
    let note: String

    /// Neuer Eintrag: 17 bis 23 Uhr ist die häufigste Abendschicht und spart
    /// im Betrieb zwei Drehungen am Rad.
    init(day: Date) {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? day
        shiftID = nil
        userID = nil
        startsAt = start
        endsAt = cal.date(byAdding: .hour, value: 6, to: start) ?? start
        area = ""
        station = nil
        note = ""
    }

    init(shift: KitchenLinkPlannedShift) {
        shiftID = shift.id
        userID = shift.userID
        startsAt = shift.startsAt
        endsAt = shift.endsAt
        area = shift.area ?? ""
        station = shift.station
        note = shift.note ?? ""
    }
}

enum KitchenLinkV2ScheduleDateText {
    private static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let time = formatter("HH:mm")
    private static let weekdayLong = formatter("EEEE d. MMMM")
    private static let dayShort = formatter("EE d.M.")
    private static let dayNumeric = formatter("d.M.")
    private static let key = formatter("yyyyMMdd")

    static func range(_ from: Date, _ to: Date) -> String {
        "\(time.string(from: from))–\(time.string(from: to))"
    }

    static func dayAndRange(_ from: Date, _ to: Date) -> String {
        "\(dayShort.string(from: from)) · \(range(from, to))"
    }

    static func weekday(_ day: Date) -> String { weekdayLong.string(from: day) }

    /// Abwesenheiten werden in ganzen Tagen gedacht, nicht in Uhrzeiten.
    /// Das Ende ist exklusiv gespeichert, wird hier aber als **letzter Tag**
    /// gezeigt — „bis 27." liest sich niemand als „bis 26. um 24 Uhr".
    static func dayRange(_ from: Date, _ to: Date) -> String {
        let lastDay = to.addingTimeInterval(-1)
        let start = dayShort.string(from: from)
        guard !Calendar(identifier: .gregorian).isDate(from, inSameDayAs: lastDay) else {
            return start
        }
        return "\(start) – \(dayShort.string(from: lastDay))"
    }

    static func weekRange(_ start: Date) -> String {
        let end = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: 6, to: start) ?? start
        return "\(dayNumeric.string(from: start)) – \(dayNumeric.string(from: end))"
    }

    static func dayKey(_ day: Date) -> String { key.string(from: day) }
}
