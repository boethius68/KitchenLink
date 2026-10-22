import SwiftUI

/// Zeitangaben der Kasse. Fest auf `de_DE`, wie überall sonst im Projekt: die
/// App ist durchgehend deutsch, also darf ein englisch eingestelltes Gerät
/// hier nicht „Jul 31 at 17:11" schreiben.
enum KitchenLinkV2ShiftDateText {
    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    private static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("d. MMM HH:mm")
        return formatter
    }()

    static func clock(_ date: Date) -> String { time.string(from: date) }
    static func dayClock(_ date: Date) -> String { dayAndTime.string(from: date) }
}

/// KL-SHIFT-001: „Kasse" — Betriebsschicht öffnen, führen und abschließen.
///
/// Der Bildschirm beantwortet eine Frage, bevor er irgendetwas anderes zeigt:
/// **ist die Kasse offen?** Ist sie zu, gibt es genau einen Knopf. Ist sie
/// offen, steht der erwartete Bargeldbestand ganz oben — das ist die Zahl,
/// gegen die am Abend gezählt wird, und alles darunter erklärt nur, wie sie
/// zustande kommt.
struct KitchenLinkV2ShiftView: View {
    @StateObject private var model = KitchenLinkShiftModel.make()
    @State private var showsCloseSheet = false
    /// KL-ROLE-002: welcher Handgriff gerade eine Freigabe braucht.
    @State private var pinRequest: PinRequest?

    /// Die drei rechtepflichtigen Handgriffe der Kasse. Als eigener Typ, damit
    /// `sheet(item:)` weiß, welches Blatt es öffnet — und damit die Aktion
    /// danach eindeutig ist.
    private enum PinRequest: String, Identifiable {
        case open, movement, close

        var id: String { rawValue }

        var permission: KitchenLinkVenuePermission {
            switch self {
            case .open: .shiftOpen
            case .movement: .cashMovement
            case .close: .shiftClose
            }
        }
    }

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    switch model.phase {
                    case .loading:
                        loadingCard
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await model.signIn(email: email, password: password)
                        }
                    case .failed(let message):
                        failureCard(message)
                    case .ready, .working:
                        if model.isOpen {
                            openShiftBody
                        } else {
                            closedShiftBody
                        }
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("shift.notice")
                    }

                    if !model.history.isEmpty {
                        historySection
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Kasse")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: KitchenLinkV2Spacing.small) {
                    NavigationLink {
                        KitchenLinkV2CashbookView()
                    } label: {
                        Label("Kassenbuch", systemImage: "book.closed")
                            .font(KitchenLinkV2Typography.compactSection)
                    }
                    .accessibilityIdentifier("shift.open_cashbook")

                    ShareLink(
                        item: KitchenLinkCSVExporter.exportShiftSummaryCSV(
                            shift: model.report.shift,
                            totals: model.totals
                        ),
                        preview: SharePreview("Kassenbericht.csv")
                    ) {
                        Label("CSV", systemImage: "square.and.arrow.up")
                            .font(KitchenLinkV2Typography.compactSection)
                    }
                    .accessibilityIdentifier("shift.export_csv")
                }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showsCloseSheet) { closeSheet }
        .sheet(item: $pinRequest) { request in
            KitchenLinkV2ManagerPinSheet(
                permission: request.permission,
                note: request.permission.label
            ) { override in
                Task { await perform(request, with: override) }
            }
        }
        .sheet(item: closeResultBinding) { result in
            KitchenLinkV2ZReportSheet(result: result) { model.dismissClose() }
        }
    }

    /// Führt den freigegebenen Handgriff sofort aus: der Token gilt nur
    /// wenige Minuten und genau einmal.
    private func perform(_ request: PinRequest, with override: KitchenLinkManagerOverride) async {
        switch request {
        case .open: await model.openShift(overrideToken: override.token)
        case .movement: await model.bookMovement(overrideToken: override.token)
        case .close: await model.closeShift(overrideToken: override.token)
        }
    }

    /// `lastClose` als `Identifiable`-Quelle für das Beleg-Sheet.
    private var closeResultBinding: Binding<KitchenLinkShiftCloseIdentified?> {
        Binding(
            get: { model.lastClose.map(KitchenLinkShiftCloseIdentified.init) },
            set: { if $0 == nil { model.dismissClose() } }
        )
    }

    // MARK: - Zustände

    private var loadingCard: some View {
        KitchenLinkV2Card {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                ProgressView()
                Text("Kassenstand wird geladen …")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
        }
    }

    private func failureCard(_ message: String) -> some View {
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
    }

    // MARK: - Kasse zu

    private var closedShiftBody: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
            KitchenLinkV2Card {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                    Text("DIE KASSE IST ZU")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .accessibilityIdentifier("shift.state.closed")

                    Text("Schicht öffnen")
                        .font(KitchenLinkV2Typography.section)

                    Text("Alle Geräte dieses Lokals arbeiten danach auf derselben "
                         + "Schicht. Der Anfangsbestand ist das Wechselgeld in der "
                         + "Schublade — er darf auch leer bleiben.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    switch model.gate(for: .shiftOpen) {
                    case .blocked(let note):
                        warning(note, identifier: "shift.openDenied")
                    case .allowed, .needsAuthorization:
                        // Bei fehlendem Recht bleibt das Feld sichtbar: der
                        // Anfangsbestand wird eingetragen und die Freigabe
                        // danach geholt. Umgekehrt liefe der kurzlebige Token
                        // ab, während jemand die Schublade zählt.
                        euroField(
                            "Anfangsbestand",
                            text: $model.openingCashText,
                            identifier: "shift.openingCash"
                        )

                        if case .needsAuthorization(let note) = model.gate(for: .shiftOpen) {
                            warning(note, identifier: "shift.openDenied")
                            Button("Freigabe holen und öffnen") { pinRequest = .open }
                                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                                .disabled(model.phase == .working)
                                .accessibilityIdentifier("shift.openWithPin")
                        } else {
                            Button("Schicht öffnen") { Task { await model.openShift() } }
                                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                                .disabled(model.phase == .working || !model.canOpenShift)
                                .accessibilityIdentifier("shift.open")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Kasse offen

    private var openShiftBody: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
            expectedCashCard
            revenueCard

            // Bargeld bewegen und abschließen sind rechtepflichtig. Wer sie
            // nicht hat, sieht die Kasse weiterhin — sie zu lesen ist Alltag,
            // sie anzufassen nicht.
            if case .blocked(let note) = model.gate(for: .cashMovement) {
                KitchenLinkV2Card {
                    warning(note, identifier: "shift.movementDenied")
                }
            } else {
                movementCard
            }

            if case .blocked(let note) = model.gate(for: .shiftClose) {
                KitchenLinkV2Card {
                    warning(note, identifier: "shift.closeDenied")
                }
            } else {
                Button("Kasse zählen und abschließen") { showsCloseSheet = true }
                    .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                    .disabled(model.phase == .working)
                    .accessibilityIdentifier("shift.startClose")
            }
        }
    }

    /// Die eine Zahl, gegen die gezählt wird.
    private var expectedCashCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack {
                    Text("IN DER SCHUBLADE ERWARTET")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Spacer(minLength: 0)
                    if let openedAt = model.report.shift?.openedAt {
                        Text("seit \(KitchenLinkV2ShiftDateText.clock(openedAt))")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .kitchenLinkV2TabularNumbers()
                    }
                }

                Text(KitchenLinkV2AmountText.euro(cents: model.totals.expectedCashCents))
                    .font(KitchenLinkV2Typography.display)
                    .kitchenLinkV2TabularNumbers()
                    .accessibilityIdentifier("shift.expectedCash")

                cashLine("Anfangsbestand", model.totals.openingCashCents)
                cashLine("Barzahlungen inkl. Trinkgeld", model.totals.cashPaymentsCents)
                if model.totals.depositCents > 0 {
                    cashLine("Einlagen", model.totals.depositCents)
                }
                if model.totals.expenseCents > 0 {
                    cashLine("Ausgaben", -model.totals.expenseCents)
                }
                if model.totals.payoutCents > 0 {
                    cashLine("Entnahmen", -model.totals.payoutCents)
                }

                if model.report.unassignedCashCents > 0 {
                    warning(
                        "\(KitchenLinkV2AmountText.euro(cents: model.report.unassignedCashCents)) "
                        + "wurden bar angenommen, während keine Schicht offen war. "
                        + "Der Betrag zählt hier nicht mit.",
                        identifier: "shift.unassignedWarning"
                    )
                }

                if model.hasOpenTablesWarning {
                    warning(
                        "\(model.report.openTableSessions) Rechnung"
                        + (model.report.openTableSessions == 1 ? "" : "en")
                        + " noch offen. Dieses Geld fehlt beim Zählen.",
                        identifier: "shift.openTablesWarning"
                    )
                }
            }
        }
    }

    private var revenueCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("UMSATZ DIESER SCHICHT")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                cashLine("Einnahmen", model.totals.revenueCents, emphasized: true)
                cashLine("Trinkgeld", model.totals.tipCents)
                if model.totals.refundedCents > 0 {
                    cashLine("Storniert", -model.totals.refundedCents)
                }

                if !model.totals.byMethod.isEmpty {
                    Divider()
                        .overlay(KitchenLinkV2Palette.Border.subtle)
                        .padding(.vertical, KitchenLinkV2Spacing.xSmall)

                    ForEach(model.totals.byMethod) { method in
                        HStack {
                            Text(method.label)
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            Text("· \(method.count)")
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            Spacer(minLength: 0)
                            Text(KitchenLinkV2AmountText.euro(cents: method.amountCents))
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .kitchenLinkV2TabularNumbers()
                        }
                        .frame(minHeight: 28)
                    }
                }
            }
        }
    }

    private var movementCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("Bargeld bewegen")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("Lieferant bar bezahlt, Wechselgeld nachgelegt oder Geld in "
                     + "den Tresor gebracht — jede Bewegung ändert, was am Abend "
                     + "in der Schublade liegen muss.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Art", selection: $model.movementKind) {
                    ForEach(KitchenLinkCashMovementKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("shift.movementKind")

                euroField(
                    "Betrag",
                    text: $model.movementAmountText,
                    identifier: "shift.movementAmount"
                )

                TextField("Grund", text: $model.movementReason, prompt: Text("z. B. Gemüsekiste"))
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityIdentifier("shift.movementReason")

                if case .needsAuthorization(let note) = model.gate(for: .cashMovement) {
                    warning(note, identifier: "shift.movementDenied")
                    Button("Freigabe holen und buchen") { pinRequest = .movement }
                        .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                        .disabled(!model.isReadyToBookMovement)
                        .accessibilityIdentifier("shift.bookMovementWithPin")
                } else {
                    Button("\(model.movementKind.label) buchen") {
                        Task { await model.bookMovement() }
                    }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .disabled(!model.canBookMovement)
                    .accessibilityIdentifier("shift.bookMovement")
                }
            }
        }
    }

    // MARK: - Abschluss

    private var closeSheet: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                                Text("Zähl die Schublade.")
                                    .font(KitchenLinkV2Typography.section)
                                Text("Trag ein, was du tatsächlich findest — nicht, "
                                     + "was erwartet wird. Eine Abweichung wird "
                                     + "festgehalten, nicht verhindert.")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                euroField(
                                    "Gezähltes Bargeld",
                                    text: $model.countedCashText,
                                    identifier: "shift.countedCash"
                                )

                                if let variance = model.previewVarianceCents {
                                    varianceLine(variance)
                                }

                                TextField(
                                    "Notiz",
                                    text: $model.closeNote,
                                    prompt: Text("optional, z. B. Grund der Abweichung")
                                )
                                .padding(KitchenLinkV2Spacing.medium)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(
                                        cornerRadius: KitchenLinkV2Radius.control, style: .continuous
                                    )
                                )
                                .accessibilityIdentifier("shift.closeNote")
                            }
                        }

                        if model.hasOpenTablesWarning {
                            KitchenLinkV2Card {
                                warning(
                                    "\(model.report.openTableSessions) Rechnung"
                                    + (model.report.openTableSessions == 1 ? "" : "en")
                                    + " sind noch offen. Wenn du jetzt abschließt, "
                                    + "fehlt dieses Geld in der Zählung.",
                                    identifier: "shift.closeWarning"
                                )
                            }
                        }

                        // Erst zählen, dann freigeben lassen: der Token gilt
                        // nur wenige Minuten, und eine Schublade zählt sich
                        // nicht in Sekunden.
                        if case .needsAuthorization(let note) = model.gate(for: .shiftClose) {
                            KitchenLinkV2Card {
                                warning(note, identifier: "shift.closeDenied")
                            }
                            Button("Freigabe holen und abschließen") {
                                showsCloseSheet = false
                                pinRequest = .close
                            }
                            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                            .disabled(!model.isReadyToClose)
                            .accessibilityIdentifier("shift.confirmCloseWithPin")
                        } else {
                            Button("Schicht abschließen") {
                                showsCloseSheet = false
                                Task { await model.closeShift() }
                            }
                            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                            .disabled(!model.canClose)
                            .accessibilityIdentifier("shift.confirmClose")
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Kassenabschluss")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showsCloseSheet = false }
                }
            }
        }
    }

    // MARK: - Rückblick

    private var historySection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("LETZTE ABSCHLÜSSE")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.history.enumerated()), id: \.element.id) { index, shift in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        historyRow(shift)
                    }
                }
            }
        }
    }

    private func historyRow(_ shift: KitchenLinkShift) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(shift.zNumber.map { "Z-Bericht \($0)" } ?? "Laufende Schicht")
                    .font(KitchenLinkV2Typography.primaryLine)
                if let closedAt = shift.closedAt {
                    Text(KitchenLinkV2ShiftDateText.dayClock(closedAt))
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }
            }
            Spacer(minLength: 0)
            if let variance = shift.varianceCents {
                Text(KitchenLinkV2AmountText.euro(cents: variance))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .kitchenLinkV2TabularNumbers()
                    .foregroundStyle(
                        variance == 0
                            ? KitchenLinkV2Palette.Content.secondary
                            : KitchenLinkV2Palette.Urgency.waitingText
                    )
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
    }

    // MARK: - Bausteine

    private func euroField(
        _ label: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            Text("€")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            TextField(label, text: text, prompt: Text("0,00"))
                .keyboardType(.decimalPad)
                .kitchenLinkV2TabularNumbers()
                .accessibilityIdentifier(identifier)
        }
        .padding(KitchenLinkV2Spacing.medium)
        .background(
            KitchenLinkV2Palette.Surface.recessed,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
        )
    }

    private func cashLine(_ label: String, _ cents: Int, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            Spacer(minLength: 0)
            Text(KitchenLinkV2AmountText.euro(cents: cents))
                .font(emphasized
                      ? KitchenLinkV2Typography.primaryLine
                      : KitchenLinkV2Typography.secondaryLine)
                .kitchenLinkV2TabularNumbers()
        }
        .frame(minHeight: 28)
    }

    private func varianceLine(_ cents: Int) -> some View {
        HStack {
            Text(cents == 0 ? "Kasse stimmt" : (cents > 0 ? "Überschuss" : "Fehlbetrag"))
                .font(KitchenLinkV2Typography.primaryLine)
            Spacer(minLength: 0)
            Text(KitchenLinkV2AmountText.euro(cents: cents))
                .font(KitchenLinkV2Typography.primaryLine)
                .kitchenLinkV2TabularNumbers()
                .foregroundStyle(
                    cents == 0
                        ? KitchenLinkV2Palette.Urgency.freshSymbol
                        : KitchenLinkV2Palette.Urgency.waitingText
                )
        }
        .frame(minHeight: 32)
        .accessibilityIdentifier("shift.variancePreview")
    }

    private func warning(_ text: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                .accessibilityHidden(true)
            Text(text)
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, KitchenLinkV2Spacing.xSmall)
        .accessibilityIdentifier(identifier)
    }
}

/// `KitchenLinkShiftClose` als `Identifiable` für `sheet(item:)`.
struct KitchenLinkShiftCloseIdentified: Identifiable, Equatable {
    let result: KitchenLinkShiftClose
    var id: String { result.shiftID }

    init(_ result: KitchenLinkShiftClose) { self.result = result }
}

/// Der Beleg des Abschlusses. Bewusst ein eigener Bildschirm: er ist das
/// Ergebnis des Tages und soll nicht zwischen den Eingabefeldern verschwinden.
struct KitchenLinkV2ZReportSheet: View {
    let result: KitchenLinkShiftCloseIdentified
    let onDismiss: () -> Void

    private var close: KitchenLinkShiftClose { result.result }

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                                Text("Z-BERICHT \(close.zNumber)")
                                    .font(KitchenLinkV2Typography.meta)
                                    .tracking(1.25)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                    .accessibilityIdentifier("shift.zNumber")

                                Text(close.isBalanced ? "Kasse stimmt." : "Abweichung festgehalten.")
                                    .font(KitchenLinkV2Typography.section)

                                line("Erwartet", close.expectedCashCents)
                                line("Gezählt", close.countedCashCents)
                                line(
                                    close.varianceCents > 0 ? "Überschuss" : "Fehlbetrag",
                                    close.varianceCents,
                                    highlighted: !close.isBalanced
                                )
                            }
                        }

                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                                Text("TAGESSUMMEN")
                                    .font(KitchenLinkV2Typography.meta)
                                    .tracking(1.25)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                                line("Einnahmen", close.totals.revenueCents)
                                line("Trinkgeld", close.totals.tipCents)
                                if close.totals.refundedCents > 0 {
                                    line("Storniert", close.totals.refundedCents)
                                }
                                ForEach(close.totals.byMethod) { method in
                                    line("\(method.label) · \(method.count)", method.amountCents)
                                }
                            }
                        }

                        Text("Sandbox-Beleg. Keine Fiskalisierung, kein "
                             + "steuerlich gültiger Z-Bericht.")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Abschluss")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { onDismiss() }
                        .accessibilityIdentifier("shift.dismissReport")
                }
            }
        }
    }

    private func line(_ label: String, _ cents: Int, highlighted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            Spacer(minLength: 0)
            Text(KitchenLinkV2AmountText.euro(cents: cents))
                .font(KitchenLinkV2Typography.secondaryLine)
                .kitchenLinkV2TabularNumbers()
                .foregroundStyle(
                    highlighted
                        ? KitchenLinkV2Palette.Urgency.waitingText
                        : KitchenLinkV2Palette.Content.primary
                )
        }
        .frame(minHeight: 28)
    }
}
