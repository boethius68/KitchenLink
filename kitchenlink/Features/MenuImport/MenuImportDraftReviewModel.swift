import Foundation

/// Human-readable price situation of a draft entry, derived from its offers.
enum MenuImportEntryPriceState: Equatable {
    case fixed(cents: Int)
    case unpriced
    case other(kind: MenuImportPriceKind, rawPrice: String)

    static func state(for entry: MenuImportEntry) -> MenuImportEntryPriceState {
        guard let offer = entry.offers.first else {
            return .unpriced
        }
        if offer.priceKind == .fixed, let cents = offer.amountCents {
            return .fixed(cents: cents)
        }
        return .other(
            kind: offer.priceKind,
            rawPrice: offer.rawPrice ?? offer.priceKind.rawValue
        )
    }

    var displayText: String {
        switch self {
        case .fixed(let cents):
            return MenuImportPriceText.euro(cents: cents)
        case .unpriced:
            return "ohne Preis"
        case .other(let kind, let rawPrice):
            return "\(rawPrice) · \(kind.rawValue)"
        }
    }
}

enum MenuImportPriceText {
    static func euro(cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let magnitude = abs(cents)
        return "€ \(sign)\(magnitude / 100)," + String(format: "%02d", magnitude % 100)
    }

    /// Parses "12,90", "12.90" or "12" into cents. Empty or invalid -> nil.
    static func cents(from rawValue: String) -> Int? {
        let cleaned = rawValue
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        guard let value = Double(cleaned), value.isFinite, value >= 0, value < 10_000 else {
            return nil
        }
        return Int((value * 100).rounded())
    }
}

/// Why an entry needs human review, in words the operator can act on.
enum MenuImportReviewReason {
    static func reasons(for entry: MenuImportEntry) -> [String] {
        var reasons: [String] = []

        if MenuImportEntryPriceState.state(for: entry) == .unpriced {
            reasons.append("Kein Preis auf der Karte zugeordnet.")
        }
        if !entry.name.evidence.isLocated {
            reasons.append("Name ohne eigene Fundstelle auf der Seite.")
        }
        if let offer = entry.offers.first, !offer.evidence.isLocated {
            reasons.append("Preis ohne eigene Fundstelle; Wert stammt aus der Strukturerkennung.")
        }
        if entry.reviewState == .needsReview && reasons.isEmpty {
            reasons.append("Strukturell unsicher erkannt; bitte Zeile und Zuordnung prüfen.")
        }

        return reasons
    }
}

private func flattenedMenuImportSections(
    _ sections: [MenuImportSection]
) -> [MenuImportSection] {
    sections.flatMap { section in
        [section] + flattenedMenuImportSections(section.subsections)
    }
}

/// In-memory review session over one `MenuImportDraft`.
///
/// Every mutation keeps the draft valid against `MenuImportDraftValidator`.
/// Nothing is persisted and nothing reaches the sandbox menu until
/// `convertToSandboxSections()` is called explicitly.
@MainActor
final class MenuImportDraftReviewModel: ObservableObject {
    @Published private(set) var draft: MenuImportDraft

    init(draft: MenuImportDraft) {
        self.draft = draft
    }

    // MARK: - Lookup

    var sections: [MenuImportSection] {
        flattenedMenuImportSections(draft.sections)
    }

    var sectionOptions: [(id: String, title: String)] {
        sections.map { ($0.id, $0.title.value) }
    }

    func entry(withID entryID: String) -> MenuImportEntry? {
        for section in sections {
            if let entry = section.entries.first(where: { $0.id == entryID }) {
                return entry
            }
        }
        return nil
    }

    func sectionID(ofEntry entryID: String) -> String? {
        sections.first { section in
            section.entries.contains { $0.id == entryID }
        }?.id
    }

    // MARK: - Resolution state

    /// Entries the operator still has to decide on before conversion:
    /// everything flagged `needsReview`, plus non-rejected entries that could
    /// not be converted because they carry no usable fixed price.
    var unresolvedEntryIDs: [String] {
        sections.flatMap(\.entries).compactMap { entry in
            guard entry.reviewState != .rejected else { return nil }
            let isFlagged = entry.reviewState == .needsReview
            let isConvertible = MenuImportDraftConverter.convertibleItem(from: entry) != nil
            return (isFlagged || !isConvertible) ? entry.id : nil
        }
    }

    var canConvert: Bool {
        unresolvedEntryIDs.isEmpty && !convertibleEntryCountIsZero
    }

    var unresolvedConvertibleEntryIDs: [String] {
        unresolvedEntryIDs.filter { entryID in
            guard let entry = entry(withID: entryID) else { return false }
            return MenuImportDraftConverter.convertibleItem(from: entry) != nil
        }
    }

    private var convertibleEntryCountIsZero: Bool {
        !sections.flatMap(\.entries).contains {
            $0.reviewState != .rejected
                && MenuImportDraftConverter.convertibleItem(from: $0) != nil
        }
    }

    // MARK: - Mutations

    func setEntryName(_ entryID: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateEntry(entryID) { entry in
            guard entry.name.value != trimmed else { return }
            entry.name.value = trimmed
            entry.reviewState = .edited
        }
    }

    /// Sets or replaces the fixed price. `nil` removes the price again.
    /// A human-entered price carries explicit human evidence anchored near the
    /// entry name but marked as not located on the page.
    func setEntryPrice(_ entryID: String, cents: Int?) {
        mutateEntry(entryID) { entry in
            if let cents {
                let existingBasis = entry.offers.first?.basis ?? "per_item"
                entry.offers = [
                    MenuImportOffer(
                        id: "\(entry.id)-review-offer",
                        priceKind: .fixed,
                        amountCents: cents,
                        currencyCode: "EUR",
                        rawPrice: MenuImportPriceText.euro(cents: cents),
                        basis: existingBasis,
                        evidence: MenuImportEvidence(
                            rawText: MenuImportPriceText.euro(cents: cents),
                            pageIndex: entry.name.evidence.pageIndex,
                            boundingBox: entry.name.evidence.boundingBox,
                            method: .human,
                            methodDetail: "review-entered-price",
                            confidence: 1.0,
                            reviewState: .edited,
                            isLocated: false
                        )
                    )
                ]
            } else {
                entry.offers = []
            }
            entry.reviewState = .edited
        }
    }

    func acceptEntry(_ entryID: String) {
        mutateEntry(entryID) { entry in
            guard MenuImportDraftConverter.convertibleItem(from: entry) != nil else {
                return
            }
            entry.reviewState = .accepted
        }
    }

    /// Explicitly accepts every unresolved entry that already has a usable
    /// fixed price. Unpriced candidates remain unresolved for individual
    /// correction or rejection.
    func acceptAllConvertibleEntries() {
        let acceptedIDs = Set(unresolvedConvertibleEntryIDs)
        guard !acceptedIDs.isEmpty else { return }

        for entryID in acceptedIDs {
            mutateEntry(entryID) { entry in
                entry.reviewState = .accepted
            }
        }
    }

    func rejectEntry(_ entryID: String) {
        mutateEntry(entryID) { entry in
            entry.reviewState = .rejected
        }
    }

    func restoreEntry(_ entryID: String) {
        mutateEntry(entryID) { entry in
            entry.reviewState = .needsReview
        }
    }

    /// Moves an entry to another section, appending it at the end and
    /// renormalizing the sibling orders in both sections.
    func moveEntry(_ entryID: String, toSectionID targetSectionID: String) {
        guard let sourceSectionID = sectionID(ofEntry: entryID),
              sourceSectionID != targetSectionID else { return }

        var updatedSections = draft.sections
        guard var entry = Self.removeEntry(entryID, from: &updatedSections) else {
            return
        }
        entry.reviewState = entry.reviewState == .needsReview ? .needsReview : .edited
        guard Self.appendEntry(entry, to: targetSectionID, in: &updatedSections) else {
            return
        }
        draft.sections = updatedSections
    }

    // MARK: - Conversion

    /// Explicit, operator-triggered conversion into the legacy sandbox model.
    /// Returns `nil` while unresolved entries remain.
    func convertToSandboxSections() -> [MenuSectionData]? {
        guard canConvert else { return nil }
        return MenuImportDraftConverter.convert(draft)
    }

    // MARK: - Helpers

    private func mutateEntry(
        _ entryID: String,
        _ transform: (inout MenuImportEntry) -> Void
    ) {
        Self.mutateEntry(entryID, in: &draft.sections, transform)
    }

    @discardableResult
    private static func mutateEntry(
        _ entryID: String,
        in sections: inout [MenuImportSection],
        _ transform: (inout MenuImportEntry) -> Void
    ) -> Bool {
        for sectionIndex in sections.indices {
            if let entryIndex = sections[sectionIndex].entries.firstIndex(where: {
                $0.id == entryID
            }) {
                transform(&sections[sectionIndex].entries[entryIndex])
                return true
            }
            if mutateEntry(
                entryID,
                in: &sections[sectionIndex].subsections,
                transform
            ) {
                return true
            }
        }
        return false
    }

    private static func removeEntry(
        _ entryID: String,
        from sections: inout [MenuImportSection]
    ) -> MenuImportEntry? {
        for sectionIndex in sections.indices {
            if let entryIndex = sections[sectionIndex].entries.firstIndex(where: {
                $0.id == entryID
            }) {
                let entry = sections[sectionIndex].entries.remove(at: entryIndex)
                for index in sections[sectionIndex].entries.indices {
                    sections[sectionIndex].entries[index].order = index
                }
                return entry
            }
            if let entry = removeEntry(
                entryID,
                from: &sections[sectionIndex].subsections
            ) {
                return entry
            }
        }
        return nil
    }

    private static func appendEntry(
        _ entry: MenuImportEntry,
        to sectionID: String,
        in sections: inout [MenuImportSection]
    ) -> Bool {
        for sectionIndex in sections.indices {
            if sections[sectionIndex].id == sectionID {
                var appendedEntry = entry
                appendedEntry.order = sections[sectionIndex].entries.count
                sections[sectionIndex].entries.append(appendedEntry)
                return true
            }
            if appendEntry(
                entry,
                to: sectionID,
                in: &sections[sectionIndex].subsections
            ) {
                return true
            }
        }
        return false
    }
}

/// Maps a reviewed draft back into the legacy sandbox menu model. Rejected
/// entries are dropped; entries without a usable fixed price never convert.
enum MenuImportDraftConverter {
    static func convert(_ draft: MenuImportDraft) -> [MenuSectionData] {
        let legend = documentLegend(from: draft.declarations)

        return flattenedMenuImportSections(draft.sections).compactMap { section in
            let items = section.entries.compactMap { entry -> MenuItemData? in
                guard entry.reviewState != .rejected else { return nil }
                return convertibleItem(from: entry)
            }
            guard !items.isEmpty else { return nil }

            let dominantKind = items.reduce(into: [MenuItemKind: Int]()) { counts, item in
                counts[item.kind, default: 0] += 1
            }
            .max { $0.value < $1.value }?.key ?? .food

            return MenuSectionData(
                id: "reviewed-\(section.id)",
                title: section.title.value,
                subtitle: "Importiert · geprüft",
                kind: dominantKind,
                items: items,
                importConfidence: section.title.evidence.confidence,
                allergenLegend: legend.isEmpty ? nil : legend
            )
        }
    }

    static func convertibleItem(from entry: MenuImportEntry) -> MenuItemData? {
        guard case .fixed(let cents) = MenuImportEntryPriceState.state(for: entry) else {
            return nil
        }

        let variants: [MenuItemVariant] = entry.optionGroups.flatMap { group in
            group.choices.compactMap { choice -> MenuItemVariant? in
                guard let offer = choice.offers.first else { return nil }
                let priceCents: Int?
                let priceKind: MenuItemOptionPriceKind?
                switch offer.priceKind {
                case .fixed:
                    priceCents = offer.amountCents
                    priceKind = .fixed
                case .delta:
                    priceCents = offer.deltaCents
                    priceKind = .delta
                case .included, .free:
                    priceCents = 0
                    priceKind = offer.priceKind == .free ? .free : .included
                default:
                    priceCents = nil
                    priceKind = nil
                }
                guard let priceCents, let priceKind else { return nil }
                return MenuItemVariant(
                    id: choice.id,
                    name: choice.name.value,
                    priceCents: priceCents,
                    kind: MenuItemOptionKind(rawValue: choice.kind) ?? .variant,
                    priceKind: priceKind,
                    groupID: group.id,
                    groupTitle: group.title.value,
                    minimumSelections: group.selectionRule.minimum,
                    maximumSelections: group.selectionRule.maximum,
                    selectionMode: group.selectionRule.mode,
                    freeSelectionCount: group.selectionRule.freeSelectionCount,
                    allowsRepeats: group.selectionRule.allowsRepeats
                )
            }
        }

        let codes = entry.declarations
            .compactMap(\.localCode)
            .filter { !$0.isEmpty }

        return MenuItemData(
            id: "reviewed-\(entry.id)",
            name: entry.name.value,
            description: entry.description?.value ?? "Automatisch importiert",
            priceCents: cents,
            kind: MenuItemKind(rawValue: entry.kind) ?? .food,
            variants: variants,
            allergenCodes: codes.isEmpty ? nil : codes.joined(separator: ","),
            priceBasis: entry.offers.first(where: { $0.priceKind == .fixed })?.basis
        )
    }

    static func documentLegend(
        from declarations: [MenuImportDeclaration]
    ) -> [String: String] {
        declarations.reduce(into: [String: String]()) { legend, declaration in
            guard let code = declaration.localCode, legend[code] == nil else { return }
            var title = declaration.rawText
            if title.lowercased().hasPrefix(code.lowercased()) {
                title = String(title.dropFirst(code.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            legend[code] = title.isEmpty ? declaration.rawText : title
        }
    }
}
