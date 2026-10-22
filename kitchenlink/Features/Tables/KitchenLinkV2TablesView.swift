import CoreImage.CIFilterBuiltins
import SwiftUI

/// KL-TABLE-001: Tische anlegen, ordnen und ihren QR-Code aushängen.
///
/// Die Ansicht bleibt bewusst im Produktpfad statt in einem Einstellungsdialog:
/// Tische ändern sich im Betrieb (Terrasse auf, Tisch zusammengelegt), und der
/// QR-Code ist das, was der Gast anfasst. Keine technischen Verbindungsfelder
/// (Usability-Leitplanke) — angemeldet wird mit denselben vertrauten
/// Zugangsdaten wie unter „Service".
struct KitchenLinkV2TablesView: View {
    @StateObject private var model = KitchenLinkTablesModel()
    @State private var isAddingTable = false
    @State private var selectedTable: KitchenLinkVenueTable?

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    intro

                    switch model.phase {
                    case .idle, .loading:
                        loadingCard
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await model.signIn(email: email, password: password)
                        }
                    case .failed(let message):
                        failureCard(message)
                    case .ready:
                        if model.tables.isEmpty {
                            emptyCard
                        } else {
                            ForEach(model.groupedTables, id: \.area) { group in
                                areaSection(group.area, tables: group.tables)
                            }
                        }
                        addButton
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("tables.notice")
                    }
                }
                .padding(KitchenLinkV2Spacing.large)
            }
        }
        .navigationTitle("Tische")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    KitchenLinkV2FloorPlanView()
                } label: {
                    Label("Tischplan", systemImage: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityIdentifier("tables.openFloorPlan")
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $isAddingTable) {
            KitchenLinkTableEditorSheet(table: nil) { label, area, _ in
                await model.addTable(label: label, area: area)
            }
        }
        .sheet(item: $selectedTable) { table in
            KitchenLinkTableDetailSheet(
                table: table,
                guestURLText: model.guestURLText(for: table),
                guestURL: model.guestURL(for: table),
                onSave: { label, area, active in
                    await model.update(table: table, label: label, area: area, active: active)
                },
                onRotate: { await model.rotateToken(for: table) },
                onDelete: { await model.delete(table: table) }
            )
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            Text("Jeder Tisch hat seinen eigenen QR-Code.")
                .font(KitchenLinkV2Typography.section)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            Text("Gäste scannen ihn und bestellen für genau diesen Tisch. "
                 + "Küche und Service sehen dann, wohin die Bestellung gehört.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        KitchenLinkV2Card {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                ProgressView()
                Text("Tische werden geladen …")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
        }
    }

    private var emptyCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("Noch keine Tische")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("Lege deinen ersten Tisch an. Den QR-Code dazu bekommst du sofort.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
        }
    }

    private func failureCard(_ message: String) -> some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("Tische konnten nicht geladen werden")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                Text(message)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                Button("Erneut versuchen") {
                    Task { await model.load() }
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("tables.retry")
            }
        }
    }

    private func areaSection(
        _ area: String,
        tables: [KitchenLinkVenueTable]
    ) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text(area.uppercased())
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(tables.enumerated()), id: \.element.id) { index, table in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        Button {
                            selectedTable = table
                        } label: {
                            tableRow(table)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tables.row.\(table.label)")
                    }
                }
            }
        }
    }

    private func tableRow(_ table: KitchenLinkVenueTable) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            Image(systemName: table.token == nil ? "qrcode.viewfinder" : "qrcode")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(table.headline)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(subtitle(for: table))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(subtitleColor(for: table))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
        .contentShape(Rectangle())
    }

    private func subtitle(for table: KitchenLinkVenueTable) -> String {
        if !table.active {
            return "stillgelegt · nimmt keine Bestellungen an"
        }
        return table.token == nil ? "noch kein QR-Code" : "QR-Code aktiv"
    }

    private func subtitleColor(for table: KitchenLinkVenueTable) -> Color {
        table.active && table.token != nil
            ? KitchenLinkV2Palette.Content.secondary
            : KitchenLinkV2Palette.Urgency.waitingText
    }

    private var addButton: some View {
        Button("Tisch hinzufügen") {
            isAddingTable = true
        }
        .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
        .accessibilityIdentifier("tables.add")
    }
}

// MARK: - Anmeldung

/// Geteilte Anmeldekarte: dieselben vertrauten Zugangsdaten wie unter
/// „Service". Auch vom Kassieren genutzt (KL-PAY-001), damit es dafür keine
/// zweite Anmeldung gibt.
struct KitchenLinkTablesSignInCard: View {
    let onSignIn: (String, String) async -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("Anmelden")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("Dieselben Zugangsdaten wie unter „Service“.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                TextField("E-Mail", text: $email, prompt: Text(verbatim: "betreiber@restaurant.de"))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityIdentifier("tables.email")

                SecureField("Passwort", text: $password)
                    .textContentType(.password)
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityIdentifier("tables.password")

                Button(isWorking ? "Wird angemeldet …" : "Anmelden") {
                    isWorking = true
                    Task {
                        await onSignIn(email, password)
                        isWorking = false
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(isWorking || email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("tables.signIn")
            }
        }
    }
}

// MARK: - Tisch anlegen und bearbeiten

private struct KitchenLinkTableEditorSheet: View {
    let table: KitchenLinkVenueTable?
    let onSave: (String, String, Bool) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var area: String
    @State private var active: Bool
    @State private var isWorking = false

    init(
        table: KitchenLinkVenueTable?,
        onSave: @escaping (String, String, Bool) async -> Void
    ) {
        self.table = table
        self.onSave = onSave
        _label = State(initialValue: table?.label ?? "")
        _area = State(initialValue: table?.area ?? "")
        _active = State(initialValue: table?.active ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tisch") {
                    TextField("Bezeichnung", text: $label, prompt: Text("z. B. 7 oder Theke"))
                        .accessibilityIdentifier("tableEditor.label")
                    TextField("Bereich", text: $area, prompt: Text("z. B. Gastraum"))
                        .accessibilityIdentifier("tableEditor.area")
                }
                if table != nil {
                    Section {
                        Toggle("Nimmt Bestellungen an", isOn: $active)
                            .accessibilityIdentifier("tableEditor.active")
                    } footer: {
                        Text("Stillgelegte Tische weisen gescannte QR-Codes ab, "
                             + "bleiben aber mit ihrer Historie erhalten.")
                    }
                }
            }
            .navigationTitle(table == nil ? "Neuer Tisch" : "Tisch bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        isWorking = true
                        Task {
                            await onSave(label, area, active)
                            isWorking = false
                            dismiss()
                        }
                    }
                    .disabled(isWorking || label.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("tableEditor.save")
                }
            }
        }
        .tint(KitchenLinkV2Palette.Content.primary)
    }
}

// MARK: - QR-Code und Tischdetails

private struct KitchenLinkTableDetailSheet: View {
    let table: KitchenLinkVenueTable
    let guestURLText: String?
    let guestURL: URL?
    let onSave: (String, String, Bool) async -> Void
    let onRotate: () async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var qrCode = KitchenLinkLocalGuestQRCodeModel()
    @State private var isEditing = false
    @State private var isConfirmingRotate = false
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(spacing: KitchenLinkV2Spacing.large) {
                        qrCard
                        actions
                    }
                    .padding(KitchenLinkV2Spacing.large)
                }
            }
            .navigationTitle(table.headline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        // Der app-weite Legacy-Tint (dunkles Petrol aus `KitchenTheme`) ist im
        // Dunkelmodus auf der Navigationsleiste kaum lesbar. Die V2-Inhalts-
        // farbe passt sich hell/dunkel an.
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await qrCode.render(for: guestURL) }
        .sheet(isPresented: $isEditing) {
            KitchenLinkTableEditorSheet(table: table) { label, area, active in
                await onSave(label, area, active)
                dismiss()
            }
        }
        .confirmationDialog(
            "Neuen QR-Code ausgeben?",
            isPresented: $isConfirmingRotate,
            titleVisibility: .visible
        ) {
            Button("Neuen Code ausgeben", role: .destructive) {
                Task {
                    await onRotate()
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der bisher gedruckte Code auf diesem Tisch funktioniert danach nicht mehr.")
        }
        .confirmationDialog(
            "Tisch löschen?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Tische mit Bestellungen lassen sich nicht löschen — leg sie stattdessen still.")
        }
    }

    private var qrCard: some View {
        KitchenLinkV2Card {
            VStack(spacing: KitchenLinkV2Spacing.medium) {
                if let rendered = qrCode.renderedQRCode {
                    Image(decorative: rendered.cgImage, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 240)
                        // Der Code wird abfotografiert: immer hell hinterlegt,
                        // auch im Dunkelmodus.
                        .padding(KitchenLinkV2Spacing.medium)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control))
                        // `Image(decorative:)` ist für VoiceOver unsichtbar;
                        // erst `accessibilityElement` macht daraus ein Element
                        // mit Namen (und damit auch prüfbar).
                        .accessibilityElement()
                        .accessibilityLabel("QR-Code für \(table.headline)")
                        .accessibilityIdentifier("tableDetail.qrCode")
                } else if qrCode.isRendering {
                    ProgressView().frame(height: 240)
                } else {
                    VStack(spacing: KitchenLinkV2Spacing.small) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        Text("Für diesen Tisch gibt es noch keinen QR-Code.")
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 240)
                }

                if let guestURLText {
                    Text(guestURLText)
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("tableDetail.guestURL")
                }

                if !table.active {
                    Text("Dieser Tisch ist stillgelegt. Ein gescannter Code wird abgewiesen.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actions: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            if let guestURL {
                ShareLink(item: guestURL) {
                    Text("QR-Code teilen oder drucken")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .accessibilityIdentifier("tableDetail.share")
            }

            Button("Tisch bearbeiten") { isEditing = true }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("tableDetail.edit")

            Button("Neuen QR-Code ausgeben") { isConfirmingRotate = true }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("tableDetail.rotate")

            // Die Farbe gehört an den Text: der Button-Style setzt selbst eine
            // `foregroundStyle`, ein Modifier außen daran bliebe wirkungslos.
            Button {
                isConfirmingDelete = true
            } label: {
                Text("Tisch löschen")
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
            .accessibilityIdentifier("tableDetail.delete")
        }
    }
}
