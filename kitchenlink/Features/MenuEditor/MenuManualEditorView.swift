import SwiftUI

/// Manueller Speisekarten-Editor.
///
/// Der Betreiber baut seine Karte hier vollständig von Hand: Kategorien,
/// Gerichte, Beschreibungen, Preise, Varianten/Portionen/Extras sowie
/// Allergen-/Zusatzstoff-Kennzeichnung. Die Kennzeichnung wird über den
/// app-eigenen `AllergenCatalog` als EINHEITLICHE Icons dargestellt — der
/// Betreiber wählt nur die Codes, die App liefert Symbol und Klartext. Für
/// nicht standardisierte Hauscodes lässt sich eine eigene Legende (Code→Text)
/// pflegen.
///
/// Der Editor arbeitet auf demselben leichten Modell (`MenuSectionData`), das
/// auch der Import erzeugt und das der Veröffentlichungs-Pfad
/// (`MenuPublishSheet`) konsumiert. So bildet die Handeingabe exakt ab, was der
/// Import treffen muss, und beide münden in denselben Publish-Weg.
struct MenuManualEditorView: View {
    @EnvironmentObject private var store: KitchenLinkStore

    @State private var sections: [MenuSectionData] = []
    /// Karteweite Legende für nicht-standardisierte Hauscodes. Die 14
    /// EU-Allergene, die relevanten Kennzeichnungstexte und E-Nummern liefert
    /// die App ohnehin. Beim Sichern wird die Legende in jede Sektion
    /// geschrieben, damit die Icon-Anzeige jeden Quellcode zuordnen kann.
    @State private var menuLegend: [String: String] = [:]
    @State private var loaded = false
    @State private var showPublish = false
    @State private var showPreview = false
    @State private var showResetConfirm = false
    @State private var lastSavedAt: Date?

    var body: some View {
        List {
            if sections.isEmpty {
                emptyState
            } else {
                ForEach($sections) { $section in
                    NavigationLink {
                        MenuEditorSectionEditor(section: $section, menuLegend: $menuLegend)
                    } label: {
                        sectionRow(section)
                    }
                }
                .onDelete { sections.remove(atOffsets: $0) }
                .onMove { sections.move(fromOffsets: $0, toOffset: $1) }
            }

            Section {
                Button {
                    addCategory()
                } label: {
                    Label("Kategorie hinzufügen", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("menuEditor.addCategory")
            }

            if !sections.isEmpty {
                Section {
                    Button {
                        showPreview = true
                    } label: {
                        Label("Vorschau wie für Gäste", systemImage: "eye")
                    }
                    .accessibilityIdentifier("menuEditor.preview")
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Auf Demo-Karte zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    savedFooter
                }

                Section("Test-Import") {
                    Button {
                        sections = KombueseMenuPreview.sections
                        menuLegend = Self.unionLegend(from: sections)
                        showPreview = true
                    } label: {
                        Label("Kombüse Kappeln (opencode.ai/zen)", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .navigationTitle("Karte bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Veröffentlichen") {
                    persist()
                    showPublish = true
                }
                .disabled(publishableSections.isEmpty)
                .accessibilityIdentifier("menuEditor.publish")
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
        .onAppear(perform: loadIfNeeded)
        .onChange(of: sections) { _, _ in persistIfLoaded() }
        .onChange(of: menuLegend) { _, _ in persistIfLoaded() }
        .sheet(isPresented: $showPublish) {
            MenuPublishSheet(sections: publishableSections)
        }
        .sheet(isPresented: $showPreview) {
            MenuEditorPreviewView(sections: sectionsWithLegend, menuLegend: menuLegend)
        }
        .confirmationDialog(
            "Karte auf die Demo zurücksetzen?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Zurücksetzen", role: .destructive) {
                store.resetMenuToDemo()
                loaded = false
                loadIfNeeded()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle manuell erfassten Kategorien und Gerichte werden durch die Demo-Karte ersetzt.")
        }
    }

    // MARK: - Rows

    private func sectionRow(_ section: MenuSectionData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: section.kind.icon)
                    .font(.caption)
                    .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                Text(section.title.isEmpty ? "Ohne Titel" : section.title)
                    .font(.headline)
            }
            Text("\(section.items.count) \(section.items.count == 1 ? "Gericht" : "Gerichte")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("Noch keine Kategorien")
                .font(.headline)
            Text("Lege deine erste Kategorie an (z. B. „Vorspeisen“, „Pizza“, „Getränke“) und füge dann Gerichte hinzu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, KitchenLinkV2Spacing.small)
    }

    @ViewBuilder
    private var savedFooter: some View {
        if let lastSavedAt {
            Text("Automatisch gesichert · \(lastSavedAt.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("Änderungen werden automatisch auf diesem iPhone gesichert.")
        }
    }

    // MARK: - Derived

    /// Sektionen mit der karteweiten Legende in jede Sektion geschrieben.
    private var sectionsWithLegend: [MenuSectionData] {
        sections.map { section in
            var copy = section
            copy.allergenLegend = menuLegend.isEmpty ? nil : menuLegend
            return copy
        }
    }

    /// Für die Veröffentlichung: nur Kategorien mit mindestens einem Gericht,
    /// das einen Namen trägt.
    private var publishableSections: [MenuSectionData] {
        sectionsWithLegend.compactMap { section in
            let named = section.items.filter { !$0.displayName.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !named.isEmpty else { return nil }
            var copy = section
            copy.items = named
            return copy
        }
    }

    // MARK: - Actions

    private func loadIfNeeded() {
        guard !loaded else { return }
        sections = store.menuSections
        menuLegend = Self.unionLegend(from: store.menuSections)
        loaded = true
    }

    private func addCategory() {
        let newSection = MenuSectionData(
            id: "manual-section-\(UUID().uuidString)",
            title: "",
            subtitle: "",
            kind: .food,
            items: []
        )
        sections.append(newSection)
    }

    private func persistIfLoaded() {
        guard loaded else { return }
        persist()
    }

    private func persist() {
        store.updateMenuSections(sectionsWithLegend)
        lastSavedAt = Date()
    }

    /// Vereint die Legenden aller Sektionen zu einer karteweiten Legende.
    static func unionLegend(from sections: [MenuSectionData]) -> [String: String] {
        var result: [String: String] = [:]
        for section in sections {
            for (code, title) in section.allergenLegend ?? [:] {
                let key = code.lowercased()
                if result[key] == nil { result[key] = title }
            }
        }
        return result
    }
}

// MARK: - Section editor

/// Bearbeitet eine Kategorie: Titel, Art (Essen/Getränk), Unterzeile und die
/// Liste der Gerichte (hinzufügen, sortieren, löschen, bearbeiten).
struct MenuEditorSectionEditor: View {
    @Binding var section: MenuSectionData
    @Binding var menuLegend: [String: String]

    var body: some View {
        List {
            Section("Kategorie") {
                TextField("Titel", text: $section.title)
                    .accessibilityIdentifier("menuEditor.sectionTitle")
                TextField("Unterzeile (optional)", text: $section.subtitle)
                Picker("Art", selection: $section.kind) {
                    ForEach(MenuItemKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.icon).tag(kind)
                    }
                }
            }

            Section("Gerichte") {
                if section.items.isEmpty {
                    Text("Noch keine Gerichte in dieser Kategorie.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach($section.items) { $item in
                    NavigationLink {
                        MenuEditorItemEditor(
                            item: $item, menuLegend: $menuLegend,
                            categoryName: section.title,
                            categoryKind: section.kind.rawValue
                        )
                    } label: {
                        itemRow(item)
                    }
                }
                .onDelete { section.items.remove(atOffsets: $0) }
                .onMove { section.items.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    addItem()
                } label: {
                    Label("Gericht hinzufügen", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("menuEditor.addItem")
            }
        }
        .navigationTitle(section.title.isEmpty ? "Kategorie" : section.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private func itemRow(_ item: MenuItemData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.displayName.isEmpty ? "Ohne Namen" : item.displayName)
                    .font(.body)
                Spacer()
                Text(PriceFormatter.string(cents: item.priceCents))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let codes = item.resolvedAllergenCodes, !codes.isEmpty {
                AllergenBadgesRow(rawCodes: codes, legendByCode: menuLegend.isEmpty ? nil : menuLegend)
            }
        }
        .padding(.vertical, 2)
    }

    private func addItem() {
        let newItem = MenuItemData(
            id: "manual-item-\(UUID().uuidString)",
            name: "",
            description: "",
            priceCents: 0,
            kind: section.kind
        )
        section.items.append(newItem)
    }
}

// MARK: - Item editor

/// Bearbeitet ein einzelnes Gericht mit allen Feldern, die auch der Import
/// abbilden muss: Name, Beschreibung, Preis, Art, Allergen-/Zusatzstoff-Codes
/// (als einheitliche Icons) sowie Varianten/Portionen/Extras.
struct MenuEditorItemEditor: View {
    @Binding var item: MenuItemData
    @Binding var menuLegend: [String: String]
    let categoryName: String
    let categoryKind: String

    @StateObject private var cloudModel = MenuEditorItemModel()

    @State private var showDeleteConfirm = false
    @State private var showSchedule = false

    private var hasSession: Bool { cloudModel.hasSession }

    var body: some View {
        List {
            Section("Gericht") {
                TextField("Name", text: $item.name)
                    .accessibilityIdentifier("menuEditor.itemName")
                ZStack(alignment: .topLeading) {
                    if item.description.isEmpty {
                        Text("Beschreibung (optional)")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $item.description)
                        .frame(minHeight: 72)
                }
                HStack {
                    Text("Preis")
                    Spacer()
                    MenuEditorPriceField(cents: $item.priceCents)
                        .frame(maxWidth: 120)
                    Text("€")
                        .foregroundStyle(.secondary)
                }
                Picker("Art", selection: $item.kind) {
                    ForEach(MenuItemKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.icon).tag(kind)
                    }
                }
            }

            Section {
                MenuEditorAllergenPicker(codes: allergenBinding, menuLegend: $menuLegend)
            } header: {
                Text("Allergene & Zusatzstoffe")
            } footer: {
                if let codes = item.resolvedAllergenCodes, !codes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("So sehen Gäste die Kennzeichnung:")
                        AllergenBadgesRow(rawCodes: codes, legendByCode: menuLegend.isEmpty ? nil : menuLegend)
                    }
                    .padding(.top, 4)
                } else {
                    Text("Wähle die zutreffenden Codes. Die App zeigt dazu einheitliche Symbole und den Klartext.")
                }
            }

            Section("Varianten, Portionen & Extras") {
                MenuEditorVariantsEditor(variants: $item.variants)
            }

            Section("Cloud & Verfügbarkeit") {
                if hasSession {
                    if !cloudModel.validationErrors.isEmpty {
                        ForEach(cloudModel.validationErrors) { error in
                            Label(error.errorDescription ?? "", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        cloudUpsert()
                    } label: {
                        HStack {
                            if cloudModel.cloudState == .saving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Label("In Cloud speichern", systemImage: "icloud.and.arrow.up")
                        }
                    }
                    .disabled(item.displayName.trimmingCharacters(in: .whitespaces).isEmpty || cloudModel.cloudState == .saving)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            if cloudModel.cloudState == .deleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Label("Aus Cloud löschen", systemImage: "trash")
                        }
                    }
                    .disabled(cloudModel.cloudState == .deleting)
                } else {
                    Text("Melde dich in der Service-Ansicht an, um Änderungen in der Cloud zu speichern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Verfügbar", isOn: $item.available)
                    .onChange(of: item.available) { _, newValue in
                        if !newValue { showSchedule = false }
                    }

                if item.available {
                    Button {
                        showSchedule.toggle()
                    } label: {
                        Label(
                            showSchedule || item.availableFrom != nil || item.availableUntil != nil
                                ? "Zeitsteuerung aktiv" : "Zeitsteuerung",
                            systemImage: showSchedule || item.availableFrom != nil || item.availableUntil != nil
                                ? "clock.badge.checkmark" : "clock"
                        )
                    }

                    if showSchedule || item.availableFrom != nil || item.availableUntil != nil {
                        DatePicker("Sichtbar ab",
                                   selection: Binding(
                                    get: { item.availableFrom ?? Date() },
                                    set: { item.availableFrom = $0 }
                                   ),
                                   displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Sichtbar bis",
                                   selection: Binding(
                                    get: { item.availableUntil ?? Date().addingTimeInterval(86400) },
                                    set: { item.availableUntil = $0 }
                                   ),
                                   displayedComponents: [.date, .hourAndMinute])
                        Button("In Cloud speichern") {
                            cloudAvailability()
                        }
                        .disabled(cloudModel.cloudState == .saving)
                    }
                }

                switch cloudModel.cloudState {
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .error(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                case .saving, .deleting:
                    Label(cloudModel.cloudState == .saving ? "Speichere …" : "Lösche …",
                          systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .idle:
                    EmptyView()
                }
            }
        }
        .navigationTitle(item.displayName.isEmpty ? "Gericht" : item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
        .confirmationDialog(
            "\(item.displayName) aus der Cloud löschen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { cloudDelete() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Gericht wird dauerhaft aus der veröffentlichten Karte entfernt.")
        }
    }

    private func cloudUpsert() {
        Task { await cloudModel.saveToCloud(item: item, categoryName: categoryName, categoryKind: categoryKind) }
    }

    private func cloudDelete() {
        Task { await cloudModel.deleteFromCloud(item: item) }
    }

    private func cloudAvailability() {
        Task { await cloudModel.updateAvailability(item: item) }
    }

    /// Bindet den kombinierten Code-String des Gerichts als geordnete Liste.
    private var allergenBinding: Binding<[String]> {
        Binding(
            get: { MenuEditorCodes.list(from: item.allergenCodes) },
            set: { item.allergenCodes = MenuEditorCodes.string(from: $0) }
        )
    }
}

// MARK: - Allergen picker

/// Auswahl der 14 EU-Hauptallergene, der für lose Ware einschlägigen
/// Zusatzstoffangaben und weiterer Verbraucherhinweise. Hauscodes aus einer
/// bestehenden Kartenlegende bleiben zusätzlich möglich.
struct MenuEditorAllergenPicker: View {
    @Binding var codes: [String]
    @Binding var menuLegend: [String: String]

    @State private var customCode = ""
    @State private var customMeaning = ""

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            group(title: "Allergene", codeList: MenuEditorCodes.standardAllergens)
            group(title: "Zusatzstoffhinweise", codeList: MenuEditorCodes.standardAdditives)
            group(title: "Weitere Hinweise", codeList: MenuEditorCodes.additionalNotices)

            if !customCodes.isEmpty {
                Text("Eigene Codes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(customCodes, id: \.self) { code in
                        chip(code: code, title: menuLegend[code] ?? "Code \(code.uppercased())")
                    }
                }
            }

            customEntry
        }
        .padding(.vertical, 4)
    }

    private func group(title: String, codeList: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: codeList.count, by: 2)), id: \.self) { index in
                    GridRow {
                        chip(
                            code: codeList[index],
                            title: AllergenCatalog.definitionsByCode[codeList[index]]?.title ?? "Code \(codeList[index].uppercased())"
                        )
                        if index + 1 < codeList.count {
                            chip(
                                code: codeList[index + 1],
                                title: AllergenCatalog.definitionsByCode[codeList[index + 1]]?.title ?? "Code \(codeList[index + 1].uppercased())"
                            )
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
    }

    private func chip(code: String, title: String) -> some View {
        let selected = codes.contains(code)
        let definition = AllergenCatalog.definitions(for: code, customTitles: menuLegend.isEmpty ? nil : menuLegend).first
        return Button {
            toggle(code)
        } label: {
            HStack(spacing: 8) {
                FoodDeclarationGlyphView(glyph: definition?.glyph ?? .unknown, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                    if code.count <= 4 {
                        Text("Code \(code.uppercased())")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                (selected ? KitchenLinkV2Palette.Brand.grape.opacity(0.18) : KitchenLinkV2Palette.Surface.recessed),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Border.control, lineWidth: 1)
            }
            .foregroundStyle(selected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Content.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(code.count <= 4 ? "\(title), Code \(code.uppercased())" : title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var customEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Eigenen Code anlegen")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("Code", text: $customCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                TextField("Bedeutung (z. B. vegan)", text: $customMeaning)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addCustom()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(normalizedCustomCode.isEmpty || customMeaning.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var customCodes: [String] {
        let standard = Set(MenuEditorCodes.standardAllergens + MenuEditorCodes.standardAdditives + MenuEditorCodes.additionalNotices)
        return codes.filter { !standard.contains($0) }
    }

    private var normalizedCustomCode: String {
        customCode.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func toggle(_ code: String) {
        if let index = codes.firstIndex(of: code) {
            codes.remove(at: index)
        } else {
            codes.append(code)
        }
    }

    private func addCustom() {
        let code = normalizedCustomCode
        let meaning = customMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !meaning.isEmpty else { return }
        menuLegend[code] = meaning
        if !codes.contains(code) { codes.append(code) }
        customCode = ""
        customMeaning = ""
    }
}

// MARK: - Variants editor

/// Bearbeitet Varianten/Portionen/Extras eines Gerichts (Name, Preis, Art).
struct MenuEditorVariantsEditor: View {
    @Binding var variants: [MenuItemVariant]

    var body: some View {
        if variants.isEmpty {
            Text("Keine Varianten. Zum Beispiel „Klein/Groß“ (Portion), „mit Pommes“ (Extra) oder „Pute statt Kalb“ (Variante).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        ForEach($variants) { $variant in
            VStack(spacing: 6) {
                TextField("Bezeichnung", text: $variant.name)
                HStack {
                    Picker("Art", selection: $variant.kind) {
                        ForEach(MenuItemOptionKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: variant.kind) { oldKind, newKind in
                        let oldDefault = MenuItemOptionPriceKind.legacyDefault(
                            for: oldKind,
                            priceCents: variant.priceCents
                        )
                        if variant.priceKind == oldDefault {
                            variant.priceKind = .legacyDefault(
                                for: newKind,
                                priceCents: variant.priceCents
                            )
                        }
                    }
                    Spacer()
                    MenuEditorPriceField(cents: $variant.priceCents)
                        .frame(maxWidth: 90)
                        .onChange(of: variant.priceCents) { oldPrice, newPrice in
                            // Positive Preisänderungen behalten die explizite
                            // Semantik (z. B. Delta statt Gesamtpreis). Nur der
                            // Wechsel von/zu kostenlos braucht eine neue Ableitung.
                            if (oldPrice == 0) != (newPrice == 0) {
                                variant.priceKind = .legacyDefault(
                                    for: variant.kind,
                                    priceCents: newPrice
                                )
                            }
                        }
                    Text("€").foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .onDelete { variants.remove(atOffsets: $0) }

        Button {
            variants.append(
                MenuItemVariant(
                    id: "manual-option-\(UUID().uuidString)",
                    name: "",
                    priceCents: 0,
                    kind: .portion
                )
            )
        } label: {
            Label("Variante hinzufügen", systemImage: "plus.circle")
        }
    }
}

// MARK: - Price field

/// Eingabefeld für einen Preis in Euro, das intern Cent (Int) bindet.
struct MenuEditorPriceField: View {
    @Binding var cents: Int
    @State private var text = ""

    var body: some View {
        TextField("0,00", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .onAppear { text = Self.format(cents) }
            .onChange(of: text) { _, newValue in
                let parsed = Self.parse(newValue)
                if parsed != cents { cents = parsed }
            }
            .onChange(of: cents) { _, newValue in
                if Self.parse(text) != newValue { text = Self.format(newValue) }
            }
    }

    static func format(_ cents: Int) -> String {
        guard cents != 0 else { return "" }
        return String(format: "%.2f", Double(cents) / 100.0).replacingOccurrences(of: ".", with: ",")
    }

    static func parse(_ raw: String) -> Int {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        let filtered = normalized.filter { $0.isNumber || $0 == "." }
        guard let value = Double(filtered) else { return 0 }
        return Int((value * 100).rounded())
    }
}

// MARK: - Preview

/// Zeigt die Karte so, wie Gäste sie sehen — inklusive der einheitlichen
/// Allergen-Icons — damit der Betreiber sein Ergebnis vor der Veröffentlichung
/// prüfen kann.
struct MenuEditorPreviewView: View {
    let sections: [MenuSectionData]
    let menuLegend: [String: String]

    var body: some View {
        MenuImportGuestPreviewView(
            sections: sections.map { section in
                var copy = section
                copy.allergenLegend = menuLegend.isEmpty ? section.allergenLegend : menuLegend
                return copy
            },
            title: "Vorschau der Speisekarte"
        )
    }
}

// MARK: - Code helpers

/// Reine Hilfslogik für den kombinierten Allergen-Code-String eines Gerichts.
enum MenuEditorCodes {
    static let standardAllergens = AllergenCatalog.standardAllergens.map(\.code)
    static let standardAdditives = AllergenCatalog.standardAdditives.map(\.code)
    static let additionalNotices = AllergenCatalog.additionalNotices.map(\.code)

    /// Zerlegt "a,c,g" in ["a","c","g"] (klein, getrimmt, ohne Dubletten,
    /// Reihenfolge erhalten).
    static func list(from raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",;/| ").union(.whitespacesAndNewlines)
        var seen: Set<String> = []
        var result: [String] = []
        for part in raw.components(separatedBy: separators) {
            let token = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !token.isEmpty, !seen.contains(token) else { continue }
            seen.insert(token)
            result.append(token)
        }
        return result
    }

    /// Fügt eine Code-Liste zu "a,c,g" zusammen; leere Liste → nil.
    static func string(from codes: [String]) -> String? {
        codes.isEmpty ? nil : codes.joined(separator: ",")
    }
}

// MARK: - Kombüse Kappeln Import-Daten (Gemma 4 lokal)

/// Auto-generiert aus Gemma 4 (Ollama lokal) Extraktion der Kombüse Kappeln Speisekarte 2025.
enum KombueseMenuPreview {
    static let title = "Kombüse Kappeln (Gemma 4)"
    static let subtitle = "Importiert · lokal via Ollama · Gemma 4"

    static var sections: [MenuSectionData] {
        [
            MenuSectionData(id: "ks-02", title: "Alkoholfreie Getränke", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-0", name: "Sinalco Cola", description: "", priceCents: 310, kind: .drink, variants: [
                MenuItemVariant(id: "kv-0-0", name: "0,4l", priceCents: 480, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: "1"),
            MenuItemData(id: "ki-1", name: "Sinalco Orange", description: "", priceCents: 310, kind: .drink, variants: [
                MenuItemVariant(id: "kv-1-0", name: "0,4l", priceCents: 480, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: "1"),
            MenuItemData(id: "ki-2", name: "Sinalco Zitrone", description: "", priceCents: 310, kind: .drink, variants: [
                MenuItemVariant(id: "kv-2-0", name: "0,4l", priceCents: 480, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: "1"),
            MenuItemData(id: "ki-3", name: "Sinalco Spezi", description: "", priceCents: 310, kind: .drink, variants: [
                MenuItemVariant(id: "kv-3-0", name: "0,4l", priceCents: 480, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: "1,3"),
            MenuItemData(id: "ki-4", name: "Wasser (still oder mit Kohlensäure)", description: "", priceCents: 320, kind: .drink, variants: [
                MenuItemVariant(id: "kv-4-0", name: "größere Größe", priceCents: 440, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: nil),
            MenuItemData(id: "ki-5", name: "Schorle: Apfel-, Johannisbeere- oder Rhabarbersaft", description: "", priceCents: 390, kind: .drink, variants: [
                MenuItemVariant(id: "kv-5-0", name: "größere Größe", priceCents: 480, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: nil),
            MenuItemData(id: "ki-6", name: "Saft: Apfel, Johannisbeere, Orange, KiBa", description: "", priceCents: 320, kind: .drink, variants: [
                MenuItemVariant(id: "kv-6-0", name: "größere Größe", priceCents: 440, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: nil),
            MenuItemData(id: "ki-7", name: "Bitter Lemon", description: "", priceCents: 260, kind: .drink, variants: [
                MenuItemVariant(id: "kv-7-0", name: "größere Größe", priceCents: 390, kind: MenuItemOptionKind.portion, priceKind: MenuItemOptionPriceKind.fixed)
            ], allergenCodes: nil),
            MenuItemData(id: "ki-8", name: "Bionade Holunder", description: "", priceCents: 420, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-9", name: "Bionade Eistee (Pfirsich oder Zitrone)", description: "", priceCents: 420, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-02b", title: "Hausgemachte Limonade", subtitle: "0,33l", kind: .drink, items: [
            MenuItemData(id: "ki-10", name: "Hausgemachte Limonade", description: "Wahlweise mit: Holunder, Mango oder Pfirsich-Geschmack", priceCents: 580, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-03", title: "Biere", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-11", name: "Astra", description: "auch als Alster", priceCents: 390, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-12", name: "Duckstein", description: "obergäriges, dunkles", priceCents: 420, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-13", name: "Flensburger Pilsener", description: "", priceCents: 380, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-14", name: "Flensburger Alkoholfrei", description: "", priceCents: 380, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-15", name: "Guinness", description: "vom Fass", priceCents: 520, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-16", name: "Becks", description: "vom Fass", priceCents: 390, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-17", name: "König Ludwig Weißbier", description: "im Stein 0,5l", priceCents: 480, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-18", name: "Alster (Pils mit Zitrone)", description: "", priceCents: 420, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-03b", title: "Wein und Sekt", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-19", name: "Weisswein trocken", description: "0,2l", priceCents: 580, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-20", name: "Rotwein trocken", description: "0,2l", priceCents: 580, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-21", name: "Rose", description: "0,2l", priceCents: 580, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-22", name: "Sekt", description: "0,1l", priceCents: 650, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-23", name: "Hausmarke Rotwein", description: "0,2l", priceCents: 520, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-04", title: "Cocktails", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-24", name: "Aperol-Spritz", description: "", priceCents: 650, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-25", name: "Andalö-Spritz", description: "", priceCents: 650, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-26", name: "Lillet Wildberry", description: "", priceCents: 650, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-27", name: "Lillet Peach", description: "", priceCents: 650, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-04b", title: "Longdrinks", subtitle: "2cl Spirituose", kind: .drink, items: [
            MenuItemData(id: "ki-28", name: "Weinbrand-Cola", description: "", priceCents: 450, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-29", name: "Korn-Cola", description: "", priceCents: 450, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-30", name: "Whiskey-Cola", description: "", priceCents: 550, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-31", name: "Wodka-Lemon", description: "", priceCents: 550, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-32", name: "Rum-Cola", description: "", priceCents: 590, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-33", name: "Havanna-Cola", description: "", priceCents: 650, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-04c", title: "Bitter, Klare & Weinbrand", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-34", name: "Oldesloer Weizenkorn", description: "", priceCents: 220, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-35", name: "Jubiläums-Aquavit", description: "", priceCents: 320, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-36", name: "Jägermeister", description: "", priceCents: 240, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-37", name: "Linie", description: "", priceCents: 320, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-38", name: "Andalò", description: "", priceCents: 270, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-39", name: "Ouzo", description: "", priceCents: 300, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-40", name: "Küstennebel", description: "", priceCents: 300, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-41", name: "Helbing Aquavit", description: "", priceCents: 340, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-42", name: "Helbing", description: "", priceCents: 280, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-43", name: "Rum", description: "", priceCents: 320, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-44", name: "Grappa", description: "", priceCents: 380, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-45", name: "Ramazzotti", description: "", priceCents: 350, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-46", name: "Obstler", description: "", priceCents: 290, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-47", name: "Wodka", description: "", priceCents: 250, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-05", title: "Kaffee und mehr", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-48", name: "Becher Crema", description: "", priceCents: 350, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-49", name: "Espresso", description: "", priceCents: 290, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-50", name: "Doppelter Espresso", description: "", priceCents: 340, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-51", name: "Latte Macchiato", description: "", priceCents: 410, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-52", name: "Affogato", description: "", priceCents: 580, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-53", name: "Tee", description: "verschiedene Sorten", priceCents: 320, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-54", name: "Heiße Schokolade", description: "", priceCents: 420, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-55", name: "Karamell-Sirup", description: "Monin-Sirup", priceCents: 50, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-56", name: "Haselnuss-Sirup", description: "Monin-Sirup", priceCents: 50, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-57", name: "Vanille-Sirup", description: "Monin-Sirup", priceCents: 50, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-05b", title: "Heiße Getränke mit Schuss", subtitle: "", kind: .drink, items: [
            MenuItemData(id: "ki-58", name: "Tote Tante", description: "", priceCents: 600, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-59", name: "Pharisäer", description: "", priceCents: 600, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-60", name: "Irish Coffee", description: "", priceCents: 600, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-61", name: "Lumumba", description: "", priceCents: 600, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-62", name: "Italienische Schokolade", description: "", priceCents: 600, kind: .drink, allergenCodes: nil),
            MenuItemData(id: "ki-63", name: "Grog", description: "heißer Rum mit Zitrone", priceCents: 520, kind: .drink, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-06", title: "Salate", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-64", name: "Großer gemischter Salat", description: "", priceCents: 1180, kind: .food, allergenCodes: "c"),
            MenuItemData(id: "ki-65", name: "Kleiner gemischter Salat", description: "", priceCents: 520, kind: .food, allergenCodes: "c"),
            MenuItemData(id: "ki-66", name: "Lachs-Salat", description: "", priceCents: 1920, kind: .food, allergenCodes: "a,c,d"),
            MenuItemData(id: "ki-67", name: "Salat mit gebratenem Lachsfilet", description: "", priceCents: 1860, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-68", name: "Scampi-Salat", description: "", priceCents: 1520, kind: .food, allergenCodes: "b,c"),
            MenuItemData(id: "ki-69", name: "Salat mit acht gebratenen Scampi", description: "", priceCents: 1520, kind: .food, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-06b", title: "Ofenkartoffel in Folie", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-70", name: "Klassik", description: "Ofenkartoffel mit Kräuterquark", priceCents: 960, kind: .food, allergenCodes: "c,g,m,1,3"),
            MenuItemData(id: "ki-71", name: "mit Sour Creme und Salatbeilage", description: "", priceCents: 1590, kind: .food, allergenCodes: "c"),
            MenuItemData(id: "ki-72", name: "mit Matjes", description: "", priceCents: 1490, kind: .food, allergenCodes: "c,g,m,1,3"),
            MenuItemData(id: "ki-73", name: "mit Hähnchen", description: "", priceCents: 1660, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-74", name: "mit Räucherlachs", description: "", priceCents: 1660, kind: .food, allergenCodes: "c,g,m,1,3"),
            MenuItemData(id: "ki-75", name: "mit Garnelen", description: "", priceCents: 1660, kind: .food, allergenCodes: "b,c,g,m,1,3")
            ]),
            MenuSectionData(id: "ks-07", title: "Fischgerichte", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-76", name: "Gebratene Heringe", description: "mit Bratkartoffeln und Salatbeilage", priceCents: 1680, kind: .food, allergenCodes: "a,c,d,1,3"),
            MenuItemData(id: "ki-77", name: "Kleiner Fischteller", description: "Filet von Rotbarsch, Seelachs & Scholle", priceCents: 2420, kind: .food, allergenCodes: "a,c,d,g,m,1,3"),
            MenuItemData(id: "ki-78", name: "Großer Fischteller", description: "Filet von Rotbarsch, Seelachs & Scholle", priceCents: 2790, kind: .food, allergenCodes: "a,c,d,g,m,1,3"),
            MenuItemData(id: "ki-79", name: "Scholle 'Büsumer Art'", description: "mit Bratkartoffeln, Dillsenfsoße & Salatbeilage", priceCents: 2480, kind: .food, allergenCodes: "a,b,c,d,1,3"),
            MenuItemData(id: "ki-80", name: "Scholle 'Finkenwerder Art'", description: "mit Speck, Bratkartoffeln & Salatbeilage", priceCents: 2360, kind: .food, allergenCodes: "a,c,d,1,3"),
            MenuItemData(id: "ki-81", name: "Schollenfilet paniert", description: "mit Bratkartoffeln, Remoulade & Salatbeilage", priceCents: 2190, kind: .food, allergenCodes: "a,c,d,g,m,1,3"),
            MenuItemData(id: "ki-82", name: "Paniertes Seelachsfilet", description: "mit Bratkartoffeln, Remoulade & Salatbeilage", priceCents: 2190, kind: .food, allergenCodes: "a,c,d,g,m,1,3"),
            MenuItemData(id: "ki-83", name: "Gebratenes Seelachsfilet", description: "mit Dillsenfsoße, Salzkartoffeln & Salatbeilage", priceCents: 2190, kind: .food, allergenCodes: "a,c,d,g,m,1,3"),
            MenuItemData(id: "ki-84", name: "Gebratenes Seelachsfilet", description: "auf Blattspinat mit Salzkartoffeln & Salatbeilage", priceCents: 2390, kind: .food, allergenCodes: "a,c,d,1,3"),
            MenuItemData(id: "ki-85", name: "Backfisch* paniert", description: "mit Bratkartoffeln, Remoulade & Salatbeilage", priceCents: 1560, kind: .food, allergenCodes: "a,c,d,g,m,1,3")
            ]),
            MenuSectionData(id: "ks-08", title: "Fischgerichte (weitere)", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-86", name: "Zanderfilet", description: "auf frischem Gemüse, dazu zerlassene Butter & Salzkartoffeln", priceCents: 2420, kind: .food, allergenCodes: "a,c,d,g"),
            MenuItemData(id: "ki-87", name: "Zanderfilet", description: "mit Dillsenfsauce, Bratkartoffeln & Salatbeilage", priceCents: 2190, kind: .food, allergenCodes: "a,c,d,g"),
            MenuItemData(id: "ki-88", name: "Lachsfilet, gebraten", description: "mit Dillsenfsoße, Salzkartoffeln & Salatbeilage", priceCents: 2320, kind: .food, allergenCodes: "a,c,d,g"),
            MenuItemData(id: "ki-89", name: "Garnelenteller", description: "mit Gemüse, Knoblauch-Dip & Brötchen", priceCents: 2260, kind: .food, allergenCodes: "a,b,c,1"),
            MenuItemData(id: "ki-90", name: "Neptunteller", description: "Matjes, Brat- und Bismarckhering mit Hausfrauensoße", priceCents: 1880, kind: .food, allergenCodes: "c,d,g,1,3"),
            MenuItemData(id: "ki-91", name: "Matjes 'Hausfrauen Art'", description: "mit Hausfrauensoße und Salzkartoffeln", priceCents: 1750, kind: .food, allergenCodes: "c,d,g"),
            MenuItemData(id: "ki-92", name: "Matjes 'Hans Albers'", description: "mit Garnelen, Zwiebelringen und Salzkartoffeln", priceCents: 1820, kind: .food, allergenCodes: "b,c,d,g"),
            MenuItemData(id: "ki-93", name: "Saure Bratheringe (kalt)", description: "mit Bratkartoffeln und Salatbeilage", priceCents: 1690, kind: .food, allergenCodes: "c,d,g,1,3"),
            MenuItemData(id: "ki-94", name: "Hausgemachtes Labskaus", description: "mit Spiegelei, Roter Beete, Gewürzgurke und Bismarckhering", priceCents: 1890, kind: .food, allergenCodes: "c,d,g")
            ]),
            MenuSectionData(id: "ks-09", title: "Fleischgerichte", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-95", name: "Schnitzel 'Holstein'", description: "mit Spiegelei, Bacon, Bratkartoffeln & Salatbeilage", priceCents: 1860, kind: .food, allergenCodes: "a,c,1,3"),
            MenuItemData(id: "ki-96", name: "Champignon-Rahm-Schnitzel", description: "mit Champignonrahmsauce, Bratkartoffeln & Salatbeilage", priceCents: 1860, kind: .food, allergenCodes: "a,c,g,1,3"),
            MenuItemData(id: "ki-97", name: "Pfeffer-Rahm-Schnitzel", description: "mit Pfefferrahmsauce, Bratkartoffeln & Salatbeilage", priceCents: 1860, kind: .food, allergenCodes: "a,c,g,1,3"),
            MenuItemData(id: "ki-98", name: "Zigeuner-Schnitzel", description: "mit Zigeunersauce, Bratkartoffeln & Salatbeilage", priceCents: 1860, kind: .food, allergenCodes: "a,c,1,3"),
            MenuItemData(id: "ki-99", name: "Schnitzel 'Wiener Art'", description: "paniertes Schweineschnitzel mit Zitrone & Bratkartoffeln", priceCents: 1620, kind: .food, allergenCodes: "a,c"),
            MenuItemData(id: "ki-100", name: "Rumpsteak", description: "mit Kräuterbutter, Bratkartoffeln & Salatbeilage", priceCents: 2260, kind: .food, allergenCodes: "a,c,g"),
            MenuItemData(id: "ki-101", name: "Rumpsteak", description: "mit gebratenen Pilzen & Zwiebeln", priceCents: 2600, kind: .food, allergenCodes: "c"),
            MenuItemData(id: "ki-102", name: "Pfeffersteak", description: "mit Pfeffersauce, Pommes Frites", priceCents: 2700, kind: .food, allergenCodes: "c,g,1,3"),
            MenuItemData(id: "ki-103", name: "Hähnchenbrust", description: "gegrillt, mit Bratkartoffeln & Salatbeilage", priceCents: 1480, kind: .food, allergenCodes: "a,c"),
            MenuItemData(id: "ki-104", name: "Cordon Bleu", description: "gefüllt mit Schinken und Käse, Bratkartoffeln & Salatbeilage", priceCents: 1980, kind: .food, allergenCodes: "a,c,g,1,3"),
            MenuItemData(id: "ki-105", name: "Bratwurst", description: "mit Pommes Frites und Salatbeilage", priceCents: 980, kind: .food, allergenCodes: "a,c,1,3"),
            MenuItemData(id: "ki-106", name: "Currywurst", description: "mit Pommes Frites und Salatbeilage", priceCents: 1080, kind: .food, allergenCodes: "a,c,1,3"),
            MenuItemData(id: "ki-107", name: "Frikadelle", description: "Hausgemacht, mit Bratkartoffeln & Salatbeilage", priceCents: 1080, kind: .food, allergenCodes: "a,c,1,3")
            ]),
            MenuSectionData(id: "ks-10", title: "Für Senioren", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-108", name: "Kleines Schnitzel 'Wiener Art'", description: "paniertes Schweineschnitzel mit Zitrone & Bratkartoffeln", priceCents: 1250, kind: .food, allergenCodes: "a,c"),
            MenuItemData(id: "ki-109", name: "Kleines Hähnchensteak", description: "mit Bratkartoffeln und Salatbeilage", priceCents: 1230, kind: .food, allergenCodes: "a,c"),
            MenuItemData(id: "ki-110", name: "Kleines paniertes Seelachsfilet", description: "mit Bratkartoffeln, Remoulade und Salatbeilage", priceCents: 1420, kind: .food, allergenCodes: "a,c,d"),
            MenuItemData(id: "ki-111", name: "Kleines Schollenfilet paniert", description: "mit Bratkartoffeln, Remoulade und Salatbeilage", priceCents: 1390, kind: .food, allergenCodes: "a,c,d"),
            MenuItemData(id: "ki-112", name: "Ein Matjesfilet 'Hausfrauen Art'", description: "mit Hausfrauensoße und Salzkartoffeln", priceCents: 1290, kind: .food, allergenCodes: "c,d,g")
            ]),
            MenuSectionData(id: "ks-10b", title: "Für kleine Seeräuber", subtitle: "bis 12 Jahre", kind: .food, items: [
            MenuItemData(id: "ki-113", name: "'Schweinchen Schlau'", description: "kleines Schweineschnitzel mit Bratkartoffeln", priceCents: 990, kind: .food, allergenCodes: "a,c"),
            MenuItemData(id: "ki-114", name: "'Kapitän Hook'", description: "Backfisch mit Bratkartoffeln & Remoulade", priceCents: 980, kind: .food, allergenCodes: "a,c,d,g,m,1"),
            MenuItemData(id: "ki-115", name: "Chicken-Nuggets", description: "mit Pommes Frites", priceCents: 980, kind: .food, allergenCodes: "a,c")
            ]),
            MenuSectionData(id: "ks-10c", title: "Vegane Gerichte", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-116", name: "Vegane Bratwurst", description: "mit Pommes Frites und Salatbeilage", priceCents: 1080, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-117", name: "Ofenkartoffel", description: "mit Grillgemüse", priceCents: 1480, kind: .food, allergenCodes: nil)
            ]),
            MenuSectionData(id: "ks-11", title: "Nachspeisen", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-118", name: "Rote Grütze", description: "mit Vanillesoße", priceCents: 580, kind: .food, allergenCodes: "c,g"),
            MenuItemData(id: "ki-119", name: "Eis", description: "3 Kugeln, verschiedene Sorten", priceCents: 520, kind: .food, allergenCodes: "c,g"),
            MenuItemData(id: "ki-120", name: "Apfelstrudel", description: "", priceCents: 620, kind: .food, allergenCodes: "a,c,g")
            ]),
            MenuSectionData(id: "ks-11b", title: "Beilagen", subtitle: "", kind: .food, items: [
            MenuItemData(id: "ki-121", name: "Pommes Frites", description: "", priceCents: 380, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-122", name: "Bratkartoffeln", description: "", priceCents: 420, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-123", name: "Salatbeilage", description: "", priceCents: 320, kind: .food, allergenCodes: nil),
            MenuItemData(id: "ki-124", name: "Kräuterquark", description: "", priceCents: 280, kind: .food, allergenCodes: "a,c,g"),
            MenuItemData(id: "ki-125", name: "Remoulade", description: "", priceCents: 150, kind: .food, allergenCodes: "a,c,g")
            ]),
        ]
    }
}
