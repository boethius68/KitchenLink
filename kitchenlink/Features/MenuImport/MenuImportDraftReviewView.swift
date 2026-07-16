import SwiftUI
import UIKit

struct MenuImportDraftReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceImages: [UIImage]
    let onApply: (MenuImportSandboxApplication) -> Void

    @State private var session: MenuImportReviewSession
    @State private var entrySelection: ReviewSelection?
    @State private var sectionSelection: ReviewSelection?
    @State private var conversionErrorMessage: String?

    init(
        draft: MenuImportDraft,
        sourceImages: [UIImage],
        onApply: @escaping (MenuImportSandboxApplication) -> Void
    ) {
        self.sourceImages = sourceImages
        self.onApply = onApply
        _session = State(initialValue: MenuImportReviewSession(draft: draft))
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                ForEach(session.sections) { section in
                    reviewSection(section)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                applyBar
            }
            .sheet(item: $entrySelection) { selection in
                if let entry = session.entry(id: selection.id) {
                    MenuImportEntryEditorView(
                        entry: entry,
                        priceState: session.priceState(for: entry),
                        reasons: session.reviewReasons(for: entry),
                        sourceImages: sourceImages
                    ) { name, description, price, kind in
                        let result = session.updateEntry(
                            id: entry.id,
                            name: name,
                            description: description,
                            priceText: price,
                            kind: kind
                        )
                        if case let .failure(error) = result {
                            return error.localizedDescription
                        }
                        return nil
                    }
                }
            }
            .sheet(item: $sectionSelection) { selection in
                if let section = session.sections.first(where: { $0.id == selection.id }) {
                    MenuImportSectionEditorView(
                        section: section,
                        sourceImages: sourceImages
                    ) { title in
                        session.updateSectionTitle(id: section.id, title: title)
                    }
                }
            }
            .alert("Übernahme noch nicht möglich", isPresented: conversionErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(conversionErrorMessage ?? "Bitte die offenen Punkte prüfen.")
            }
        }
        .interactiveDismissDisabled(session.unresolvedCount > 0)
        .accessibilityIdentifier("menuImport.draftReview")
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Quelle", value: session.draft.sourceDocument.displayName ?? sourceTitle)
            LabeledContent("Kategorien", value: "\(activeSectionCount)")
            LabeledContent("Artikel", value: "\(session.activeEntryCount)")

            if session.unresolvedCount > 0 {
                Label(
                    "\(session.unresolvedCount) offene Prüfung(en)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .accessibilityIdentifier("menuImport.unresolvedCount")
            } else {
                Label("Alles für die Sandbox geprüft", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if session.rejectedEntryCount > 0 {
                Label("\(session.rejectedEntryCount) Artikel verworfen", systemImage: "trash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Entwurf")
        } footer: {
            Text("Die Prüfung verändert weder ein veröffentlichtes Menü noch externe Daten. Erst der Button unten ersetzt das lokale Sandbox-Menü.")
        }
    }

    @ViewBuilder
    private func reviewSection(_ section: MenuImportReviewSectionSnapshot) -> some View {
        Section {
            if section.reviewState == .rejected {
                Button {
                    _ = session.restoreSection(id: section.id)
                } label: {
                    Label("Kategorie wiederherstellen", systemImage: "arrow.uturn.backward")
                }
            } else if section.entries.isEmpty {
                Text("Keine erkannten Artikel")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(section.entries, id: \.id) { entry in
                    entryRow(entry, in: section)
                }
            }
        } header: {
            sectionHeader(section)
        }
    }

    private func sectionHeader(_ section: MenuImportReviewSectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                if section.depth > 0 {
                    Image(systemName: "arrow.turn.down.right")
                        .accessibilityHidden(true)
                }
                Text(section.title)
                    .strikethrough(section.reviewState == .rejected)
                Spacer()
                reviewStateIcon(section.reviewState)
            }

            if section.reviewState != .rejected {
                let reasons = session.reviewReasons(for: section)
                if !reasons.isEmpty,
                   section.reviewState != .accepted,
                   section.reviewState != .edited {
                    Text(reasons.map(\.title).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .textCase(nil)
                }

                HStack(spacing: 14) {
                    Button("Bearbeiten") {
                        sectionSelection = ReviewSelection(id: section.id)
                    }
                    .accessibilityIdentifier("menuImport.editSection.\(section.id)")

                    if !reasons.isEmpty,
                       section.reviewState != .accepted,
                       section.reviewState != .edited {
                        Button("Bestätigen") {
                            _ = session.acceptSection(id: section.id)
                        }
                    }

                    Menu {
                        Button {
                            _ = session.moveSection(id: section.id, direction: .up)
                        } label: {
                            Label("Kategorie nach oben", systemImage: "arrow.up")
                        }
                        Button {
                            _ = session.moveSection(id: section.id, direction: .down)
                        } label: {
                            Label("Kategorie nach unten", systemImage: "arrow.down")
                        }
                        Button(role: .destructive) {
                            _ = session.rejectSection(id: section.id)
                        } label: {
                            Label("Kategorie verwerfen", systemImage: "trash")
                        }
                    } label: {
                        Label("Kategorieaktionen", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                }
                .font(.caption)
                .textCase(nil)
            }
        }
        .padding(.top, section.depth > 0 ? 8 : 0)
    }

    @ViewBuilder
    private func entryRow(_ entry: MenuImportEntry, in section: MenuImportReviewSectionSnapshot) -> some View {
        if entry.reviewState == .rejected {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name.value)
                        .strikethrough()
                    Text("Verworfen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Wiederherstellen") {
                    _ = session.restoreEntry(id: entry.id)
                }
                .font(.caption)
            }
            .accessibilityIdentifier("menuImport.rejectedEntry.\(entry.id)")
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    reviewStateIcon(entry.reviewState)
                    Text(entry.name.value)
                        .font(.headline)
                    Spacer()
                    priceLabel(for: entry)
                        .font(.subheadline.monospacedDigit())
                }

                if let description = entry.description?.value, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                let reasons = session.reviewReasons(for: entry)
                if !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(reasons, id: \.self) { reason in
                            Label(reason.title, systemImage: reason.blocksAcceptance ? "exclamationmark.circle.fill" : "info.circle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(reasons.contains(where: \.blocksAcceptance) ? .red : .orange)
                }

                HStack(spacing: 10) {
                    Button {
                        entrySelection = ReviewSelection(id: entry.id)
                    } label: {
                        Label("Prüfen", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("menuImport.reviewEntry.\(entry.id)")

                    if isAwaitingDecision(entry), session.canAccept(entry: entry) {
                        Button("Bestätigen") {
                            _ = session.acceptEntry(id: entry.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("menuImport.acceptEntry.\(entry.id)")
                    }

                    Spacer()

                    Menu {
                        Button {
                            _ = session.moveEntry(id: entry.id, direction: .up)
                        } label: {
                            Label("Nach oben", systemImage: "arrow.up")
                        }
                        Button {
                            _ = session.moveEntry(id: entry.id, direction: .down)
                        } label: {
                            Label("Nach unten", systemImage: "arrow.down")
                        }
                        Button(role: .destructive) {
                            _ = session.rejectEntry(id: entry.id)
                        } label: {
                            Label("Artikel verwerfen", systemImage: "trash")
                        }
                    } label: {
                        Label("Artikelaktionen", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("menuImport.entry.\(entry.id)")
        }
    }

    private var applyBar: some View {
        VStack(spacing: 8) {
            if session.unresolvedCount > 0 {
                Text("Noch \(session.unresolvedCount) offene Prüfung(en): korrigieren, bestätigen oder verwerfen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Nur lokale Sandbox · keine Veröffentlichung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                applyToSandbox()
            } label: {
                Label("Sandbox-Menü übernehmen", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!session.canCreateSandboxMenu)
            .accessibilityIdentifier("menuImport.applySandbox")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    private var activeSectionCount: Int {
        session.sections.filter { section in
            section.reviewState != .rejected && section.entries.contains { $0.reviewState != .rejected }
        }.count
    }

    private var sourceTitle: String {
        switch session.draft.sourceDocument.sourceType {
        case .camera: return "Dokumentkamera"
        case .photoLibrary: return "Fotomediathek"
        case .pdf: return "PDF"
        case .demoFixture: return "Beispielkarte"
        case .other: return "Import"
        }
    }

    private var conversionErrorBinding: Binding<Bool> {
        Binding(
            get: { conversionErrorMessage != nil },
            set: { isPresented in
                if !isPresented { conversionErrorMessage = nil }
            }
        )
    }

    private func isAwaitingDecision(_ entry: MenuImportEntry) -> Bool {
        entry.reviewState != .accepted &&
            entry.reviewState != .edited &&
            !session.reviewReasons(for: entry).isEmpty
    }

    @ViewBuilder
    private func priceLabel(for entry: MenuImportEntry) -> some View {
        switch session.priceState(for: entry) {
        case let .resolved(cents, _, _):
            Text(MenuImportReviewPriceFormatter.string(cents: cents))
        case .missing:
            Text("Preis fehlt")
                .foregroundStyle(.red)
        case let .unsupported(rawText, _):
            Text(rawText.isEmpty ? "Preis prüfen" : rawText)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func reviewStateIcon(_ state: MenuImportReviewState) -> some View {
        switch state {
        case .accepted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Bestätigt")
        case .edited:
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Korrigiert")
        case .needsReview, .unknown:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Prüfung nötig")
        case .rejected:
            Image(systemName: "trash.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Verworfen")
        case .unreviewed:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Automatisch erkannt")
        }
    }

    private func applyToSandbox() {
        do {
            let application = try session.makeSandboxApplication()
            onApply(application)
            dismiss()
        } catch {
            conversionErrorMessage = error.localizedDescription
        }
    }
}

private struct ReviewSelection: Identifiable {
    let id: String
}

private struct MenuImportEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let entry: MenuImportEntry
    let priceState: MenuImportReviewPriceState
    let reasons: [MenuImportReviewReason]
    let sourceImages: [UIImage]
    let onSave: (String, String, String, MenuItemKind) -> String?

    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var kind: MenuItemKind
    @State private var validationMessage: String?

    init(
        entry: MenuImportEntry,
        priceState: MenuImportReviewPriceState,
        reasons: [MenuImportReviewReason],
        sourceImages: [UIImage],
        onSave: @escaping (String, String, String, MenuItemKind) -> String?
    ) {
        self.entry = entry
        self.priceState = priceState
        self.reasons = reasons
        self.sourceImages = sourceImages
        self.onSave = onSave
        _name = State(initialValue: entry.name.value)
        _description = State(initialValue: entry.description?.value ?? "")
        switch priceState {
        case let .resolved(cents, _, _):
            _price = State(initialValue: MenuImportReviewPriceFormatter.string(cents: cents))
        case .missing:
            _price = State(initialValue: "")
        case let .unsupported(rawText, _):
            _price = State(initialValue: rawText)
        }
        _kind = State(initialValue: MenuItemKind(rawValue: entry.kind) ?? .food)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Originalbeleg") {
                    MenuImportEvidencePreview(
                        title: "Artikelzeile",
                        evidence: entry.name.evidence,
                        sourceImages: sourceImages
                    )

                    if let priceEvidence = entry.offers.first(where: { $0.priceKind != .delta })?.evidence,
                       priceEvidence != entry.name.evidence {
                        MenuImportEvidencePreview(
                            title: "Preiszeile",
                            evidence: priceEvidence,
                            sourceImages: sourceImages
                        )
                    }
                }

                if !reasons.isEmpty {
                    Section("Warum prüfen?") {
                        ForEach(reasons, id: \.self) { reason in
                            Label(reason.title, systemImage: reason.blocksAcceptance ? "exclamationmark.circle.fill" : "info.circle")
                                .foregroundStyle(reason.blocksAcceptance ? .red : .orange)
                        }
                    }
                }

                Section("Korrektur") {
                    TextField("Artikelname", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("menuImport.editor.name")

                    TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                        .lineLimit(2 ... 5)
                        .accessibilityIdentifier("menuImport.editor.description")

                    TextField("Preis, z. B. 12,50", text: $price)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("menuImport.editor.price")

                    Picker("Art", selection: $kind) {
                        Text("Essen").tag(MenuItemKind.food)
                        Text("Getränk").tag(MenuItemKind.drink)
                    }
                    .pickerStyle(.segmented)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Artikel prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        validationMessage = onSave(name, description, price, kind)
                        if validationMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("menuImport.editor.save")
                }
            }
        }
    }
}

private struct MenuImportSectionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let section: MenuImportReviewSectionSnapshot
    let sourceImages: [UIImage]
    let onSave: (String) -> Bool

    @State private var title: String
    @State private var showsValidation = false

    init(
        section: MenuImportReviewSectionSnapshot,
        sourceImages: [UIImage],
        onSave: @escaping (String) -> Bool
    ) {
        self.section = section
        self.sourceImages = sourceImages
        self.onSave = onSave
        _title = State(initialValue: section.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Originalbeleg") {
                    MenuImportEvidencePreview(
                        title: "Kategoriezeile",
                        evidence: section.evidence,
                        sourceImages: sourceImages
                    )
                }
                Section("Korrektur") {
                    TextField("Kategoriename", text: $title)
                        .textInputAutocapitalization(.words)
                    if showsValidation {
                        Text("Bitte einen Kategorienamen eingeben.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Kategorie prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if onSave(title) {
                            dismiss()
                        } else {
                            showsValidation = true
                        }
                    }
                }
            }
        }
    }
}

private struct MenuImportEvidencePreview: View {
    let title: String
    let evidence: MenuImportEvidence
    let sourceImages: [UIImage]

    private var crop: UIImage? {
        MenuImportEvidenceCropper.crop(evidence: evidence, from: sourceImages)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if let crop {
                Image(uiImage: crop)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 180)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Originalausschnitt von Seite \(evidence.pageIndex + 1)")
                    .accessibilityIdentifier("menuImport.evidenceCrop")
            } else {
                ContentUnavailableView(
                    "Originalbild nicht verfügbar",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Der erkannte Rohtext bleibt sichtbar.")
                )
                .frame(minHeight: 120)
            }

            Text("\"\(evidence.rawText)\"")
                .font(.body.monospaced())
                .textSelection(.enabled)

            Text("Seite \(evidence.pageIndex + 1) · \(evidence.method.rawValue) · \(Int((evidence.confidence * 100).rounded())) %")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }
}

private enum MenuImportEvidenceCropper {
    static func crop(evidence: MenuImportEvidence, from images: [UIImage]) -> UIImage? {
        guard images.indices.contains(evidence.pageIndex) else { return nil }
        let normalized = normalizedImage(images[evidence.pageIndex])
        guard let source = normalized.cgImage else { return nil }

        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        let box = evidence.boundingBox
        let normalizedX = max(0, min(1, box.x))
        let normalizedY = max(0, min(1, box.y))
        let normalizedWidth = max(0, min(1 - normalizedX, box.width))
        let normalizedHeight = max(0, min(1 - normalizedY, box.height))

        // Vision uses a lower-left origin. CGImage crops use an upper-left origin.
        var cropRect = CGRect(
            x: normalizedX * width,
            y: (1 - normalizedY - normalizedHeight) * height,
            width: normalizedWidth * width,
            height: normalizedHeight * height
        )
        let horizontalPadding = max(cropRect.width * 0.10, width * 0.02)
        let verticalPadding = max(cropRect.height * 1.25, height * 0.015)
        cropRect = cropRect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
        cropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: width, height: height)).integral

        guard cropRect.width >= 1, cropRect.height >= 1,
              let cropped = source.cropping(to: cropRect) else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}
