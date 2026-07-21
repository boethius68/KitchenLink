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
    /// Karteweite Legende für nicht-standardisierte Codes (Standardcodes a–p /
    /// 1–14 liefert die App ohnehin). Wird beim Sichern in jede Sektion
    /// geschrieben, damit die Icon-Anzeige jeden Code zuordnen kann.
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
                        MenuEditorItemEditor(item: $item, menuLegend: $menuLegend)
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
        }
        .navigationTitle(item.displayName.isEmpty ? "Gericht" : item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
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

/// Auswahl der Allergen-/Zusatzstoff-Codes. Standardcodes (EU-Allergene a–p und
/// Zusatzstoffe 1–14) liefert die App mit Symbol und Klartext; zusätzlich lassen
/// sich Hauscodes mit eigener Bedeutung anlegen, die in die karteweite Legende
/// wandern.
struct MenuEditorAllergenPicker: View {
    @Binding var codes: [String]
    @Binding var menuLegend: [String: String]

    @State private var customCode = ""
    @State private var customMeaning = ""

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            group(title: "Allergene", codeList: MenuEditorCodes.standardAllergens)
            group(title: "Zusatzstoffe", codeList: MenuEditorCodes.standardAdditives)

            if !customCodes.isEmpty {
                Text("Eigene Codes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
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
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(codeList, id: \.self) { code in
                    chip(code: code, title: AllergenCatalog.definitionsByCode[code]?.title ?? "Code \(code.uppercased())")
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
            HStack(spacing: 5) {
                Image(systemName: definition?.icon ?? "questionmark.circle.fill")
                    .font(.caption2)
                VStack(alignment: .leading, spacing: 0) {
                    Text(code.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel("\(title), Code \(code.uppercased())")
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
        let standard = Set(MenuEditorCodes.standardAllergens + MenuEditorCodes.standardAdditives)
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
                    Spacer()
                    MenuEditorPriceField(cents: $variant.priceCents)
                        .frame(maxWidth: 90)
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
    static let standardAllergens = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]
    static let standardAdditives = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14"]

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
