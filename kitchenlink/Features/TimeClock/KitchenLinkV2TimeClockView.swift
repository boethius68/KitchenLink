import SwiftUI

/// KL-TIME-001: „Zeiterfassung" — die Stempeluhr.
///
/// Der Bildschirm beantwortet eine Frage, bevor er alles andere zeigt: **bin
/// ich auf der Uhr?** Der Knopf dafür ist der größte auf der Seite, weil er im
/// Betrieb mit nassen Händen im Vorbeigehen getroffen wird.
struct KitchenLinkV2TimeClockView: View {
    @StateObject private var model = KitchenLinkTimeClockModel.make()
    @State private var entryToCorrect: KitchenLinkTeamTimeEntry?

    /// Treibt nur die Anzeige. Gebucht wird ausschließlich, was der Server sagt.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    switch model.phase {
                    case .loading:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Zeiten werden geladen …")
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
                        clockCard
                        if !model.status.today.isEmpty {
                            todaySection
                        }
                        if model.canSeeTeam {
                            teamSection
                        }
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("time.notice")
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Zeiterfassung")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await model.load() }
        .onReceive(clock) { model.advance(to: $0) }
        .sheet(item: $entryToCorrect) { entry in
            KitchenLinkV2TimeCorrectionSheet(entry: entry) { endedAt, reason in
                await model.correct(entry, endedAt: endedAt, reason: reason)
                entryToCorrect = nil
            } onCancel: {
                entryToCorrect = nil
            }
        }
    }

    // MARK: - Die Uhr

    private var clockCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                HStack {
                    Text(model.status.clockedIn
                         ? (model.status.onBreak ? "IN DER PAUSE" : "AUF DER UHR")
                         : "NICHT EINGESTEMPELT")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .accessibilityIdentifier("time.state")
                    Spacer(minLength: 0)
                    if let started = model.status.startedAt {
                        Text("seit \(KitchenLinkV2ShiftDateText.clock(started))")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .kitchenLinkV2TabularNumbers()
                    }
                }

                Text(model.status.onBreak
                     ? KitchenLinkDurationText.running(model.runningBreakSeconds)
                     : KitchenLinkDurationText.running(model.runningNetSeconds))
                    .font(KitchenLinkV2Typography.display)
                    .kitchenLinkV2TabularNumbers()
                    .accessibilityIdentifier("time.running")

                if model.status.onBreak {
                    Text("Die Arbeitszeit steht still, solange die Pause läuft.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }

                HStack {
                    Text("Heute")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Spacer(minLength: 0)
                    Text(KitchenLinkDurationText.hoursMinutes(model.todayNetSeconds))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .kitchenLinkV2TabularNumbers()
                        .accessibilityIdentifier("time.todayTotal")
                }
                .frame(minHeight: 32)

                Button(model.status.clockedIn ? "Ausstempeln" : "Einstempeln") {
                    Task { await model.toggleClock() }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(model.phase == .working)
                .accessibilityIdentifier("time.toggleClock")

                if model.status.clockedIn {
                    if !model.status.onBreak {
                        Picker("Art", selection: $model.breakKind) {
                            ForEach(KitchenLinkBreakKind.allCases, id: \.self) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("time.breakKind")
                    }

                    Button(model.status.onBreak ? "Pause beenden" : "Pause beginnen") {
                        Task { await model.toggleBreak() }
                    }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .disabled(model.phase == .working)
                    .accessibilityIdentifier("time.toggleBreak")
                }
            }
        }
    }

    // MARK: - Eigener Tag

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("HEUTE")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.status.today.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(timeRange(entry.startedAt, entry.endedAt))
                                    .font(KitchenLinkV2Typography.primaryLine)
                                    .kitchenLinkV2TabularNumbers()
                                if entry.totals.breakSeconds > 0 {
                                    Text("davon \(KitchenLinkDurationText.hoursMinutes(entry.totals.breakSeconds)) Pause")
                                        .font(KitchenLinkV2Typography.meta)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                } else if entry.corrected {
                                    Text("korrigiert")
                                        .font(KitchenLinkV2Typography.meta)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(KitchenLinkDurationText.hoursMinutes(entry.totals.netSeconds))
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .kitchenLinkV2TabularNumbers()
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        }
                        .padding(.horizontal, KitchenLinkV2Spacing.large)
                        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }

    // MARK: - Team

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
            if !model.forgottenClockOuts.isEmpty {
                KitchenLinkV2Card {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                        HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                                .accessibilityHidden(true)
                            Text("Seit über zwölf Stunden auf der Uhr — fast sicher ein "
                                 + "vergessener Ausstempel. Bis das korrigiert ist, kommt "
                                 + "die Person nicht wieder auf die Uhr.")
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityIdentifier("time.forgottenWarning")

                        ForEach(model.forgottenClockOuts) { entry in
                            Button("\(entry.displayName) ausstempeln") {
                                entryToCorrect = entry
                            }
                            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                            .accessibilityIdentifier("time.correct.\(entry.id)")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("WER ARBEITET GERADE")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                if model.onTheClock.isEmpty {
                    KitchenLinkV2Card {
                        Text("Gerade steht niemand auf der Uhr.")
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                } else {
                    KitchenLinkV2Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(model.onTheClock.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                                }
                                teamRow(entry)
                            }
                        }
                    }
                }
            }

            if !model.finishedToday.isEmpty {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                    Text("HEUTE ABGESCHLOSSEN")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                    KitchenLinkV2Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(model.finishedToday.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                                }
                                teamRow(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private func teamRow(_ entry: KitchenLinkTeamTimeEntry) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: KitchenLinkV2Spacing.xSmall) {
                    Text(entry.displayName)
                        .font(KitchenLinkV2Typography.primaryLine)
                    if entry.onBreak {
                        Text("PAUSE")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .padding(.horizontal, KitchenLinkV2Spacing.xSmall)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(
                                    cornerRadius: KitchenLinkV2Radius.label, style: .continuous
                                )
                            )
                    }
                }
                Text([entry.roleName, timeRange(entry.startedAt, entry.endedAt)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                if entry.corrected, let reason = entry.correctionReason {
                    Text("korrigiert: \(reason)")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }
            }
            Spacer(minLength: 0)
            Text(KitchenLinkDurationText.hoursMinutes(entry.totals.netSeconds))
                .font(KitchenLinkV2Typography.secondaryLine)
                .kitchenLinkV2TabularNumbers()
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
    }

    private func timeRange(_ start: Date?, _ end: Date?) -> String {
        guard let start else { return "" }
        let from = KitchenLinkV2ShiftDateText.clock(start)
        guard let end else { return "seit \(from)" }
        return "\(from) – \(KitchenLinkV2ShiftDateText.clock(end))"
    }
}

/// Der Korrekturbogen. Blueprint §9.3 verlangt „Korrektur mit Freigabe und
/// Audit": der Grund ist Pflicht, und der ursprüngliche Stand bleibt erhalten.
struct KitchenLinkV2TimeCorrectionSheet: View {
    let entry: KitchenLinkTeamTimeEntry
    let onSave: (Date, String) async -> Void
    let onCancel: () -> Void

    @State private var endedAt = Date()
    @State private var reason = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                                Text("\(entry.displayName) ausstempeln")
                                    .font(KitchenLinkV2Typography.section)
                                if let started = entry.startedAt {
                                    Text("Eingestempelt am "
                                         + KitchenLinkV2ShiftDateText.dayClock(started)
                                         + ". Trag ein, wann die Arbeit tatsächlich endete.")
                                        .font(KitchenLinkV2Typography.secondaryLine)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                DatePicker(
                                    "Ende",
                                    selection: $endedAt,
                                    in: (entry.startedAt ?? .distantPast)...Date(),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .environment(\.locale, Locale(identifier: "de_DE"))
                                .accessibilityIdentifier("time.correctionEnd")

                                TextField(
                                    "Grund",
                                    text: $reason,
                                    prompt: Text(verbatim: "z. B. Ausstempeln vergessen")
                                )
                                .padding(KitchenLinkV2Spacing.medium)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(
                                        cornerRadius: KitchenLinkV2Radius.control,
                                        style: .continuous
                                    )
                                )
                                .accessibilityIdentifier("time.correctionReason")

                                Text("Der ursprüngliche Stand bleibt festgehalten — eine "
                                     + "Korrektur ergänzt ihn, sie ersetzt ihn nicht.")
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button(isWorking ? "Wird gespeichert …" : "Korrektur speichern") {
                            isWorking = true
                            Task {
                                await onSave(endedAt, reason)
                                isWorking = false
                            }
                        }
                        .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                        .disabled(isWorking || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("time.saveCorrection")
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Korrektur")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { onCancel() }
                }
            }
        }
    }
}
