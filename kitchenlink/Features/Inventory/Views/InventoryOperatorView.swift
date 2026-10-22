import SwiftUI

/// V2 `Bestand`: read-only Bestandsansicht über die echte
/// `InventoryProjection` der KL-INVENTORY-001-Domain. Kein zweites
/// Bestandsmodell — jede sichtbare Zahl kommt frisch aus dem Ledger.
///
/// Statusregel (`DESIGN_SYSTEM.md` §5/§6): Schwere → Dringlichkeit
/// (`ok`→neutral, `warning`→waiting, `critical`→critical). Zitrone
/// ausschließlich in der einzelnen Demo-Aktion, nie in einer Statusfarbe.
/// Bis ein `.stock`-Form-Muster vom Nutzer freigegeben ist, verzichtet die
/// Zeile bewusst auf einen Operations-Glyph und führt die Dringlichkeit
/// ausschließlich über Farbe und Klartext (`§6`: „bis ein eigenes Muster
/// definiert ist, bleiben Form und Klartext gemeinsam sichtbar").
struct InventoryOperatorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = InventoryOperatorModel()

    @State private var showBookMovementSheet = false
    @State private var showAuditSheet = false
    @State private var showSuggestionsSheet = false

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                    header
                    sectionList

                    if let status = model.statusMessage {
                        Text(status)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = model.lastError {
                        Text(error)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("inventory.error")
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.top, KitchenLinkV2Spacing.medium)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
        .navigationTitle("Bestand")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        loadDemo()
                    } label: {
                        Label("Demo-Szenario neu laden", systemImage: "arrow.clockwise")
                    }

                    Button {
                        showSuggestionsSheet = true
                    } label: {
                        Label("Bestellvorschläge", systemImage: "cart")
                    }

                    NavigationLink {
                        KitchenLinkV2PurchaseOrdersView()
                    } label: {
                        Label("Lieferantenbestellungen", systemImage: "shippingbox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .task {
            if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoInventory(),
               model.groups.isEmpty {
                let count = InventoryOperatorDemoSeeder.seed(into: model)
                if count > 0 {
                    model.statusMessage = "\(count) Bestandszeilen aus dem Demo-Szenario."
                }
            }
        }
        .sheet(isPresented: $showBookMovementSheet) {
            KitchenLinkBookMovementSheet(model: model)
        }
        .sheet(isPresented: $showAuditSheet) {
            KitchenLinkInventoryAuditSheet(model: model)
        }
        .sheet(isPresented: $showSuggestionsSheet) {
            KitchenLinkReplenishmentSuggestionsSheet(model: model)
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                headerTitle
                headerSummaryLabel
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                headerTitle
                Spacer()
                headerSummaryLabel
            }
        }
    }

    private var headerTitle: some View {
        Text("Bestand")
            .font(KitchenLinkV2Typography.display)
            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("inventory.title")
    }

    private var headerSummaryLabel: some View {
        Text(headerSummary)
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(headerSummaryColor)
            .kitchenLinkV2TabularNumbers()
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("inventory.summary")
    }

    private var headerSummary: String {
        if model.groups.isEmpty {
            return "leer"
        }
        if model.criticalCount > 0 {
            return "\(model.criticalCount) kritisch · \(model.totalRowCount) Positionen"
        }
        return "\(model.totalRowCount) Positionen"
    }

    private var headerSummaryColor: Color {
        model.criticalCount > 0
            ? KitchenLinkV2Palette.Urgency.criticalText
            : KitchenLinkV2Palette.Content.muted
    }

    @ViewBuilder
    private var sectionList: some View {
        if model.groups.isEmpty {
            Text("Kein Bestand geladen. Lade das Demo-Szenario, um die Sandbox-Fixture zu sehen.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("inventory.emptyState")
        } else {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                ForEach(model.groups) { group in
                    locationSection(group)
                }
            }
        }
    }

    private func locationSection(_ group: KitchenLinkV2InventoryLocationGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: KitchenLinkV2Spacing.small) {
                Text(group.locationName.uppercased())
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.35)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Spacer()
                Text("\(group.rows.count)")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .kitchenLinkV2TabularNumbers()
            }
            .padding(.bottom, KitchenLinkV2Spacing.small)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                    stockRow(row)
                    if index < group.rows.count - 1 {
                        Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                    }
                }
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lagerort \(group.locationName), \(group.rows.count) Positionen")
    }

    private func stockRow(_ row: KitchenLinkV2InventoryStockRow) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                    stockDescription(row)
                    stockAvailability(row, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
                    stockDescription(row)
                    Spacer(minLength: KitchenLinkV2Spacing.small)
                    stockAvailability(row, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.ingredientName). \(row.verb). verfügbar \(row.available.displayString()). Physisch \(row.physical.displayString()). Reserviert \(row.reserved.displayString()). \(row.detail)")
        .accessibilityIdentifier("inventory.row.\(row.id)")
    }

    private func stockDescription(_ row: KitchenLinkV2InventoryStockRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.ingredientName)
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(row.detail)
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(row.urgency == .neutral
                    ? KitchenLinkV2Palette.Content.secondary
                    : row.urgency.textColor)
                .fixedSize(horizontal: false, vertical: true)
            Text("Physisch \(row.physical.displayString()) · reserviert \(row.reserved.displayString())")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .kitchenLinkV2TabularNumbers()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stockAvailability(
        _ row: KitchenLinkV2InventoryStockRow,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(row.available.displayString())
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(row.urgency == .neutral
                    ? KitchenLinkV2Palette.Content.primary
                    : row.urgency.textColor)
                .kitchenLinkV2TabularNumbers()
            Text(row.verb)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(row.urgency.textColor)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var actionBar: some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            HStack(spacing: KitchenLinkV2Spacing.small) {
                Button {
                    showBookMovementSheet = true
                } label: {
                    Label("Buchen", systemImage: "plus.circle")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Action.persistentPrimary,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showAuditSheet = true
                } label: {
                    Label("Inventur", systemImage: "checklist")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Brand.grape,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showSuggestionsSheet = true
                } label: {
                    Label("Vorschläge", systemImage: "cart")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Surface.recessed,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }

            if model.groups.isEmpty {
                Button {
                    loadDemo()
                } label: {
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Image(systemName: "wand.and.stars")
                        Text("Demo-Szenario laden")
                    }
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.top, KitchenLinkV2Spacing.medium)
        .padding(.bottom, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
    }

    private func loadDemo() {
        model.statusMessage = "Demo-Szenario wird geladen..."
        let count = InventoryOperatorDemoSeeder.seed(into: model)
        if count > 0 {
            model.statusMessage = "\(count) Bestandszeilen aus dem Demo-Szenario."
        }
    }
}

// MARK: - Wareneingang & Bruch Buchen Sheet

struct KitchenLinkBookMovementSheet: View {
    @ObservedObject var model: InventoryOperatorModel
    @Environment(\.dismiss) private var dismiss

    enum MovementOption: String, CaseIterable, Identifiable {
        case receipt = "Wareneingang (+)"
        case waste = "Bruch / Verderb (-)"

        var id: String { rawValue }

        var kind: StockMovementKind {
            switch self {
            case .receipt: return .receipt
            case .waste: return .waste
            }
        }
    }

    @State private var selectedOption: MovementOption = .receipt
    @State private var selectedLocationID: String = ""
    @State private var selectedIngredientID: String = ""
    @State private var quantityText: String = ""
    @State private var note: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Buchungsart", selection: $selectedOption) {
                        ForEach(MovementOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Lagerort", selection: $selectedLocationID) {
                        ForEach(model.availableLocations) { loc in
                            Text(loc.name).tag(loc.id)
                        }
                    }

                    Picker("Zutat", selection: $selectedIngredientID) {
                        ForEach(model.availableIngredients) { ing in
                            Text(ing.name).tag(ing.id)
                        }
                    }

                    HStack {
                        TextField("Menge", text: $quantityText)
                            .keyboardType(.decimalPad)
                        if let ing = model.availableIngredients.first(where: { $0.id == selectedIngredientID }) {
                            Text(ing.baseUnit.shortSymbol)
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        }
                    }

                    TextField("Notiz (optional, z. B. Lieferschein #123)", text: $note)
                } header: {
                    Text("Buchungsdetails")
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Bestand buchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") {
                        book()
                    }
                    .font(KitchenLinkV2Typography.primaryButton)
                }
            }
            .onAppear {
                if selectedLocationID.isEmpty, let firstLoc = model.availableLocations.first {
                    selectedLocationID = firstLoc.id
                }
                if selectedIngredientID.isEmpty, let firstIng = model.availableIngredients.first {
                    selectedIngredientID = firstIng.id
                }
            }
        }
    }

    private func book() {
        let cleanText = quantityText.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: cleanText), decimal > 0 else {
            errorMessage = "Bitte eine gültige positive Menge angeben."
            return
        }

        do {
            try model.recordMovement(
                ingredientID: selectedIngredientID,
                locationID: selectedLocationID,
                kind: selectedOption.kind,
                amount: decimal,
                note: note.isEmpty ? nil : note
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Inventur-Zählung Sheet

struct KitchenLinkInventoryAuditSheet: View {
    @ObservedObject var model: InventoryOperatorModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLocationID: String = ""
    @State private var countedInputs: [String: String] = [:]
    @State private var auditNote: String = "Stichtags-Inventur"
    @State private var errorMessage: String? = nil

    private var currentGroup: KitchenLinkV2InventoryLocationGroup? {
        model.groups.first { $0.id == selectedLocationID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Lagerort", selection: $selectedLocationID) {
                    ForEach(model.availableLocations) { loc in
                        Text(loc.name).tag(loc.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    if let group = currentGroup {
                        Section {
                            ForEach(group.rows) { row in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.ingredientName)
                                            .font(KitchenLinkV2Typography.primaryLine)
                                        Text("Soll: \(row.physical.displayString())")
                                            .font(KitchenLinkV2Typography.meta)
                                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(spacing: 4) {
                                            TextField(
                                                "Ist",
                                                text: Binding(
                                                    get: { countedInputs[row.ingredientID] ?? "" },
                                                    set: { countedInputs[row.ingredientID] = $0 }
                                                )
                                            )
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 70)
                                            .textFieldStyle(.roundedBorder)

                                            Text(row.physical.unit.shortSymbol)
                                                .font(.system(size: 13))
                                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                        }

                                        if let input = countedInputs[row.ingredientID],
                                           let dec = Decimal(string: input.replacingOccurrences(of: ",", with: ".")) {
                                            let diff = dec - row.physical.amount
                                            Text(diff >= 0 ? "+\(diff)" : "\(diff)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(diff >= 0 ? .green : .red)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text("Gezählte Bestände eingeben")
                        } footer: {
                            Text("Abweichungen werden automatisch als Korrekturbuchungen in das Ledger übernommen.")
                        }
                    } else {
                        Text("Keine Bestände an diesem Lagerort.")
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                }
            }
            .navigationTitle("Inventur-Zählung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Abschließen") {
                        commitAudit()
                    }
                    .font(KitchenLinkV2Typography.primaryButton)
                    .disabled(countedInputs.isEmpty)
                }
            }
            .onAppear {
                if selectedLocationID.isEmpty, let firstLoc = model.availableLocations.first {
                    selectedLocationID = firstLoc.id
                }
            }
        }
    }

    private func commitAudit() {
        var counts: [String: Decimal] = [:]
        for (ingID, text) in countedInputs {
            let clean = text.replacingOccurrences(of: ",", with: ".")
            if let val = Decimal(string: clean), val >= 0 {
                counts[ingID] = val
            }
        }

        guard !counts.isEmpty else { return }

        do {
            try model.recordAudit(
                locationID: selectedLocationID,
                counts: counts,
                note: auditNote
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Bestellvorschläge Sheet

struct KitchenLinkReplenishmentSuggestionsSheet: View {
    @ObservedObject var model: InventoryOperatorModel
    @Environment(\.dismiss) private var dismiss

    @State private var suggestions: [ReplenishmentSuggestion] = []

    var body: some View {
        NavigationStack {
            List {
                if suggestions.isEmpty {
                    VStack(spacing: KitchenLinkV2Spacing.medium) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        Text("Alle Bestände über Mindestbestand")
                            .font(KitchenLinkV2Typography.primaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Text("Keine Bestellungen erforderlich.")
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    Section {
                        ForEach(suggestions) { sug in
                            let ingName = model.availableIngredients.first { $0.id == sug.ingredientID }?.name ?? sug.ingredientID
                            let locName = model.availableLocations.first { $0.id == sug.locationID }?.name ?? sug.locationID

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ingName)
                                        .font(KitchenLinkV2Typography.primaryLine)
                                    Text("Lagerort: \(locName) · Ziel: \(sug.target.displayString())")
                                        .font(KitchenLinkV2Typography.meta)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("+\(sug.shortfall.displayString())")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                                    Text("Bestellvorschlag")
                                        .font(.system(size: 11))
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Empfohlene Nachbestellungen")
                    } footer: {
                        Text("Berechnet aus Mindest- und Zielbestand gemäß Blueprint §11.")
                    }
                }
            }
            .navigationTitle("Bestellvorschläge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                suggestions = (try? model.replenishmentSuggestions()) ?? []
            }
        }
    }
}
