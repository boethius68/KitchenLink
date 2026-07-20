import SwiftUI
import UIKit

/// Crops evidence regions out of the original page images. Vision bounding
/// boxes are normalized with a bottom-left origin, so the vertical axis is
/// flipped into UIKit's top-left space before cropping.
enum MenuImportEvidenceCropper {
    static func cropRect(
        for box: MenuImportNormalizedBoundingBox,
        imageSize: CGSize,
        paddingFraction: CGFloat = 0.015
    ) -> CGRect {
        let topLeftY = 1 - box.y - box.height
        var rect = CGRect(
            x: CGFloat(box.x) * imageSize.width,
            y: CGFloat(topLeftY) * imageSize.height,
            width: CGFloat(box.width) * imageSize.width,
            height: CGFloat(box.height) * imageSize.height
        )

        let paddingX = imageSize.width * paddingFraction
        let paddingY = imageSize.height * paddingFraction
        rect = rect.insetBy(dx: -paddingX, dy: -paddingY)
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }

    static func crop(
        page: UIImage,
        box: MenuImportNormalizedBoundingBox
    ) -> UIImage? {
        // Render once to normalize orientation and scale before cropping.
        let pixelSize = CGSize(
            width: page.size.width * page.scale,
            height: page.size.height * page.scale
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            page.draw(in: CGRect(origin: .zero, size: pixelSize))
        }

        let rect = cropRect(for: box, imageSize: pixelSize)
        guard rect.width >= 1, rect.height >= 1,
              let cgImage = normalized.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Evidence-based review of a `MenuImportDraft` before anything reaches the
/// sandbox menu. Unpriced and structurally uncertain entries must be resolved
/// (corrected, moved or discarded) before the explicit conversion unlocks.
struct MenuImportDraftReviewView: View {
    @ObservedObject var model: MenuImportDraftReviewModel
    let pages: [UIImage]
    let onApply: ([MenuSectionData]) -> Void

    private struct SelectedEntry: Identifiable {
        let id: String
    }

    private struct PublishPayload: Identifiable {
        let id = UUID()
        let sections: [MenuSectionData]
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: SelectedEntry?
    @State private var publishPayload: PublishPayload?

    var body: some View {
        NavigationStack {
            ZStack {
                KitchenLinkV2Palette.Surface.base
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                        summary

                        ForEach(model.sections, id: \.id) { section in
                            sectionBlock(section)
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, KitchenLinkV2Spacing.large)
                    .padding(.vertical, KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    actionBar
                }
            }
            .navigationTitle("Import prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .accessibilityIdentifier("draftReview.close")
                }
            }
            .sheet(item: $selectedEntry) { selected in
                MenuImportEntryDetailView(
                    model: model,
                    entryID: selected.id,
                    pages: pages
                )
                .id(selected.id)
            }
            .sheet(item: $publishPayload) { payload in
                MenuPublishSheet(sections: payload.sections)
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private var summary: some View {
        let entries = model.sections.flatMap(\.entries)
        let unresolved = model.unresolvedEntryIDs.count

        return VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            Text("Erkannter Entwurf")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

            Text("\(entries.count) Einträge · \(unresolved) zu klären")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(unresolved > 0
                    ? KitchenLinkV2Palette.Urgency.waitingText
                    : KitchenLinkV2Palette.Content.secondary)
                .kitchenLinkV2TabularNumbers()
                .accessibilityIdentifier("draftReview.summary")

            Text("Jeder Eintrag zeigt seine Fundstelle auf der Originalseite. Preislose oder unsichere Kandidaten müssen korrigiert, verschoben oder verworfen werden, bevor der Entwurf die Sandbox ersetzt.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionBlock(_ section: MenuImportSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title.value)
                .font(KitchenLinkV2Typography.section)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .padding(.bottom, KitchenLinkV2Spacing.small)

            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                entryRow(entry)
                if index < section.entries.count - 1 {
                    Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                }
            }
        }
    }

    private func entryRow(_ entry: MenuImportEntry) -> some View {
        Button {
            selectedEntry = SelectedEntry(id: entry.id)
        } label: {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name.value)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(entry.reviewState == .rejected
                            ? KitchenLinkV2Palette.Content.muted
                            : KitchenLinkV2Palette.Content.primary)
                        .strikethrough(entry.reviewState == .rejected)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(stateLine(for: entry))
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(stateColor(for: entry))
                }

                Spacer(minLength: KitchenLinkV2Spacing.small)

                Text(MenuImportEntryPriceState.state(for: entry).displayText)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(priceColor(for: entry))
                    .kitchenLinkV2TabularNumbers()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
            .padding(.vertical, KitchenLinkV2Spacing.medium)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draftReview.entry.\(entry.id)")
        .accessibilityValue(rowStateValue(for: entry))
    }

    private func rowStateValue(for entry: MenuImportEntry) -> String {
        guard model.unresolvedEntryIDs.contains(entry.id) else {
            return "geklärt"
        }
        if case .unpriced = MenuImportEntryPriceState.state(for: entry) {
            return "offen · ohne Preis"
        }
        return "offen"
    }

    private func stateLine(for entry: MenuImportEntry) -> String {
        switch entry.reviewState {
        case .needsReview:
            return MenuImportReviewReason.reasons(for: entry).first ?? "zu prüfen"
        case .accepted:
            return "übernommen"
        case .edited:
            return "bearbeitet"
        case .rejected:
            return "verworfen"
        case .unreviewed, .unknown:
            return "automatisch erkannt"
        }
    }

    private func stateColor(for entry: MenuImportEntry) -> Color {
        switch entry.reviewState {
        case .needsReview:
            return KitchenLinkV2Palette.Urgency.waitingText
        case .accepted, .edited:
            return KitchenLinkV2Palette.Urgency.freshText
        case .rejected, .unreviewed, .unknown:
            return KitchenLinkV2Palette.Content.muted
        }
    }

    private func priceColor(for entry: MenuImportEntry) -> Color {
        if case .unpriced = MenuImportEntryPriceState.state(for: entry),
           entry.reviewState != .rejected {
            return KitchenLinkV2Palette.Urgency.waitingText
        }
        return KitchenLinkV2Palette.Content.primary
    }

    private var actionBar: some View {
        let unresolved = model.unresolvedEntryIDs.count
        let unresolvedConvertible = model.unresolvedConvertibleEntryIDs.count

        return VStack(spacing: KitchenLinkV2Spacing.small) {
            if unresolved > 0 {
                Text("\(unresolved) Einträge müssen vor der Übernahme noch geklärt werden.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Nächsten offenen Eintrag prüfen") {
                    if let entryID = model.unresolvedEntryIDs.first {
                        selectedEntry = SelectedEntry(id: entryID)
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .accessibilityIdentifier("draftReview.nextOpen")

                if unresolvedConvertible > 0 {
                    Button("Alle \(unresolvedConvertible) bepreisten übernehmen") {
                        model.acceptAllConvertibleEntries()
                    }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .accessibilityIdentifier("draftReview.acceptAllPriced")
                    .accessibilityHint("Preislose Einträge bleiben zur einzelnen Prüfung offen.")
                }
            } else {
                Button {
                    if let sections = model.convertToSandboxSections() {
                        onApply(sections)
                        dismiss()
                    }
                } label: {
                    Text("In Sandbox-Menü übernehmen")
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .accessibilityIdentifier("draftReview.convert")

                Button("Online veröffentlichen") {
                    if let sections = model.convertToSandboxSections() {
                        publishPayload = PublishPayload(sections: sections)
                    }
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("draftReview.publishOnline")
                .accessibilityHint("Veröffentlicht die geprüfte Karte im Gast-Web.")
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.top, KitchenLinkV2Spacing.medium)
        .padding(.bottom, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
    }
}

/// Detail sheet for one draft entry: original page crop, raw OCR text, price
/// state, review reasons and the correction actions.
struct MenuImportEntryDetailView: View {
    @ObservedObject var model: MenuImportDraftReviewModel
    let entryID: String
    let pages: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @State private var nameText = ""
    @State private var priceText = ""
    @State private var loadedEntryID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KitchenLinkV2Palette.Surface.base
                    .ignoresSafeArea()

                if let entry = model.entry(withID: entryID) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                            evidenceBlock(for: entry)
                            reasonsBlock(for: entry)
                            correctionBlock(for: entry)
                            resolutionBlock(for: entry)
                        }
                        .frame(maxWidth: 680)
                        .padding(KitchenLinkV2Spacing.large)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Text("Eintrag nicht gefunden.")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
            }
            .navigationTitle("Eintrag prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        commitFields()
                        dismiss()
                    }
                    .accessibilityIdentifier("draftReview.detail.done")
                }
            }
            .onAppear(perform: loadFieldsIfNeeded)
            .onChange(of: entryID) {
                loadFieldsIfNeeded()
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    // MARK: - Evidence

    private func evidenceBlock(for entry: MenuImportEntry) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("FUNDSTELLE")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.35)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            evidenceCrop(
                evidence: entry.name.evidence,
                caption: "Name · Seite \(entry.name.evidence.pageIndex + 1) · „\(entry.name.evidence.rawText)“"
            )

            if let offer = entry.offers.first {
                evidenceCrop(
                    evidence: offer.evidence,
                    caption: "Preis · „\(offer.rawPrice)“ · Quelle: \(offer.evidence.rawText)"
                )
            }

            if let description = entry.description {
                evidenceCrop(
                    evidence: description.evidence,
                    caption: "Beschreibung · „\(description.value)“"
                )
            }
        }
    }

    @ViewBuilder
    private func evidenceCrop(evidence: MenuImportEvidence, caption: String) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            if evidence.isLocated,
               pages.indices.contains(evidence.pageIndex),
               let crop = MenuImportEvidenceCropper.crop(
                   page: pages[evidence.pageIndex],
                   box: evidence.boundingBox
               ) {
                Image(uiImage: crop)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(
                        cornerRadius: KitchenLinkV2Radius.compact,
                        style: .continuous
                    ))
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.compact,
                            style: .continuous
                        )
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                    }
                    .accessibilityLabel("Originalausschnitt: \(caption)")
            } else {
                HStack(spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "questionmark.square.dashed")
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .accessibilityHidden(true)
                    Text("Keine eigene Fundstelle auf der Seite — Wert stammt aus der Strukturerkennung.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(KitchenLinkV2Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(
                        cornerRadius: KitchenLinkV2Radius.compact,
                        style: .continuous
                    )
                )
            }

            Text(caption)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reasons

    @ViewBuilder
    private func reasonsBlock(for entry: MenuImportEntry) -> some View {
        let reasons = MenuImportReviewReason.reasons(for: entry)
        if !reasons.isEmpty {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("PRÜFGRUND")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.35)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                ForEach(reasons, id: \.self) { reason in
                    HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.small) {
                        KitchenLinkV2OperationGlyph(
                            operation: .change,
                            color: KitchenLinkV2Palette.Urgency.waitingSymbol,
                            size: 11
                        )
                        Text(reason)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Correction

    private func correctionBlock(for entry: MenuImportEntry) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("KORRIGIEREN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.35)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text("Name")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                TextField("Name", text: $nameText)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .textFieldStyle(.plain)
                    .padding(KitchenLinkV2Spacing.medium)
                    .frame(minHeight: 44)
                    .background(
                        KitchenLinkV2Palette.Surface.raised,
                        in: RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control,
                            style: .continuous
                        )
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1.5)
                    }
                    .accessibilityIdentifier("draftReview.detail.name")
            }

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text("Preis in Euro (leer = ohne Preis)")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                TextField("z. B. 12,90", text: $priceText)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(KitchenLinkV2Spacing.medium)
                    .frame(minHeight: 44)
                    .background(
                        KitchenLinkV2Palette.Surface.raised,
                        in: RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control,
                            style: .continuous
                        )
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1.5)
                    }
                    .accessibilityIdentifier("draftReview.detail.price")
            }

            if model.sectionOptions.count > 1 {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                    Text("Abschnitt")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Picker("Abschnitt", selection: sectionBinding) {
                        ForEach(model.sectionOptions, id: \.id) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("draftReview.detail.sectionPicker")
                }
            }
        }
    }

    private var sectionBinding: Binding<String> {
        Binding(
            get: { model.sectionID(ofEntry: entryID) ?? "" },
            set: { newSectionID in
                commitFields()
                model.moveEntry(entryID, toSectionID: newSectionID)
            }
        )
    }

    // MARK: - Resolution

    private func resolutionBlock(for entry: MenuImportEntry) -> some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            if entry.reviewState == .rejected {
                Button("Wiederherstellen") {
                    model.restoreEntry(entryID)
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("draftReview.detail.restore")
            } else {
                if !acceptIsPossible {
                    Text("Ohne Preis kann der Eintrag nicht übernommen werden — Preis eintragen oder Eintrag verwerfen.")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Eintrag übernehmen") {
                    commitFields()
                    model.acceptEntry(entryID)
                    dismiss()
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(!acceptIsPossible)
                .accessibilityIdentifier("draftReview.detail.accept")

                Button("Eintrag verwerfen") {
                    model.rejectEntry(entryID)
                    dismiss()
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("draftReview.detail.reject")
            }
        }
    }

    /// The sandbox menu is price-bound, so acceptance requires a parseable
    /// price in the field. Unpriced entries are priced or discarded instead
    /// of being accepted into a state that could never convert.
    private var acceptIsPossible: Bool {
        MenuImportPriceText.cents(
            from: priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        ) != nil
    }

    private func loadFieldsIfNeeded() {
        // Field state must never leak from a previously shown entry into the
        // next one; reload whenever this sheet shows a different entry ID.
        guard loadedEntryID != entryID, let entry = model.entry(withID: entryID) else { return }
        loadedEntryID = entryID
        nameText = entry.name.value
        if case .fixed(let cents) = MenuImportEntryPriceState.state(for: entry) {
            priceText = String(format: "%d,%02d", cents / 100, cents % 100)
        } else {
            priceText = ""
        }
    }

    private func commitFields() {
        // Guard against committing stale fields that belong to another entry.
        guard loadedEntryID == entryID else { return }
        guard let entry = model.entry(withID: entryID) else { return }

        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty, trimmedName != entry.name.value {
            model.setEntryName(entryID, to: trimmedName)
        }

        let trimmedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentState = MenuImportEntryPriceState.state(for: entry)
        if trimmedPrice.isEmpty {
            if case .fixed = currentState {
                model.setEntryPrice(entryID, cents: nil)
            }
        } else if let cents = MenuImportPriceText.cents(from: trimmedPrice) {
            if currentState != .fixed(cents: cents) {
                model.setEntryPrice(entryID, cents: cents)
            }
        }
    }
}
