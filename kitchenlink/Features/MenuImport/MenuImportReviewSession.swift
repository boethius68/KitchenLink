import Foundation

enum MenuImportReviewMoveDirection: Sendable {
    case up
    case down
}

enum MenuImportReviewReason: Hashable, Sendable {
    case emptyName
    case missingPrice
    case unsupportedPrice(String)
    case nonFixedPrice(String)
    case sourceMarkedForReview
    case lowConfidence(Int)
    case unsupportedOptions
    case unsupportedStructure

    var title: String {
        switch self {
        case .emptyName:
            return "Name fehlt"
        case .missingPrice:
            return "Preis fehlt"
        case let .unsupportedPrice(label):
            return "Preisart \"\(label)\" prüfen"
        case let .nonFixedPrice(label):
            return "\(label) wird als Sandbox-Preis übernommen"
        case .sourceMarkedForReview:
            return "Erkennung ist unsicher"
        case let .lowConfidence(percent):
            return "Nur \(percent) % Erkennungssicherheit"
        case .unsupportedOptions:
            return "Mindestens eine Option hat keinen eindeutigen Preis"
        case .unsupportedStructure:
            return "Komplexe Menüstruktur kann nicht direkt übernommen werden"
        }
    }

    var blocksAcceptance: Bool {
        switch self {
        case .emptyName, .missingPrice, .unsupportedPrice, .unsupportedOptions, .unsupportedStructure:
            return true
        case .nonFixedPrice, .sourceMarkedForReview, .lowConfidence:
            return false
        }
    }
}

enum MenuImportReviewPriceState: Equatable, Sendable {
    case resolved(cents: Int, rawText: String, kind: MenuImportPriceKind)
    case missing
    case unsupported(rawText: String, kind: MenuImportPriceKind)

    var cents: Int? {
        switch self {
        case let .resolved(cents, _, _):
            return cents
        case .missing, .unsupported:
            return nil
        }
    }
}

struct MenuImportReviewSectionSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let depth: Int
    let reviewState: MenuImportReviewState
    let evidence: MenuImportEvidence
    let entries: [MenuImportEntry]
}

struct MenuImportSandboxConversionIssue: Identifiable, Equatable, Sendable {
    let id: String
    let sectionID: String
    let entryID: String?
    let message: String
}

struct MenuImportSandboxConversionError: Error, Equatable, LocalizedError, Sendable {
    let issues: [MenuImportSandboxConversionIssue]

    var errorDescription: String? {
        if issues.count == 1 {
            return issues[0].message
        }
        return "Vor der Übernahme sind noch \(issues.count) Punkte offen."
    }
}

struct MenuImportSandboxApplication {
    let sections: [MenuSectionData]
    let reviewedDraft: MenuImportDraft
}

enum MenuImportReviewEditError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case invalidPrice
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Der Artikel braucht einen Namen."
        case .invalidPrice:
            return "Bitte einen gültigen Preis wie 12,50 eingeben."
        case .entryNotFound:
            return "Der Artikel ist im Entwurf nicht mehr vorhanden."
        }
    }
}

struct MenuImportReviewSession: Sendable {
    private(set) var draft: MenuImportDraft

    init(draft: MenuImportDraft) {
        self.draft = draft
        normalizeOrders()
    }

    var sections: [MenuImportReviewSectionSnapshot] {
        Self.flattenedSections(draft.sections)
    }

    var activeEntryCount: Int {
        sections
            .filter { $0.reviewState != .rejected }
            .reduce(0) { count, section in
                count + section.entries.filter { $0.reviewState != .rejected }.count
            }
    }

    var rejectedEntryCount: Int {
        sections.reduce(0) { count, section in
            count + section.entries.filter { $0.reviewState == .rejected }.count
        }
    }

    var unresolvedCount: Int {
        unresolvedSectionCount + sections.reduce(0) { count, section in
            guard section.reviewState != .rejected else { return count }
            return count + section.entries.filter(isEntryUnresolved).count
        }
    }

    var unresolvedSectionCount: Int {
        sections.filter(isSectionUnresolved).count
    }

    var canCreateSandboxMenu: Bool {
        activeEntryCount > 0 && unresolvedCount == 0
    }

    func entry(id: String) -> MenuImportEntry? {
        for section in sections {
            if let entry = section.entries.first(where: { $0.id == id }) {
                return entry
            }
        }
        return nil
    }

    func priceState(for entry: MenuImportEntry) -> MenuImportReviewPriceState {
        Self.resolvePrice(from: entry.offers)
    }

    func reviewReasons(for entry: MenuImportEntry) -> [MenuImportReviewReason] {
        var reasons: [MenuImportReviewReason] = []

        if entry.name.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append(.emptyName)
        }

        switch priceState(for: entry) {
        case .missing:
            reasons.append(.missingPrice)
        case let .unsupported(rawText, kind):
            reasons.append(.unsupportedPrice(rawText.isEmpty ? kind.rawValue : rawText))
        case let .resolved(_, _, kind) where kind != .fixed && kind != .free:
            reasons.append(.nonFixedPrice(Self.priceKindLabel(kind)))
        case .resolved:
            break
        }

        if hasUnrepresentableOptions(entry) {
            reasons.append(.unsupportedOptions)
        }
        if !entry.quantities.isEmpty || !entry.bundleComponents.isEmpty {
            reasons.append(.unsupportedStructure)
        }

        let evidence = entryEvidence(entry)
        if entry.reviewState == .needsReview || entry.reviewState == .unknown ||
            evidence.contains(where: { $0.reviewState == .needsReview || $0.reviewState == .unknown }) {
            reasons.append(.sourceMarkedForReview)
        }
        if let lowestConfidence = evidence.map(\.confidence).min(), lowestConfidence < 0.70 {
            reasons.append(.lowConfidence(Int((lowestConfidence * 100).rounded())))
        }

        return Self.deduplicated(reasons)
    }

    func reviewReasons(for section: MenuImportReviewSectionSnapshot) -> [MenuImportReviewReason] {
        var reasons: [MenuImportReviewReason] = []
        if section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append(.emptyName)
        }
        if section.reviewState == .needsReview || section.reviewState == .unknown ||
            section.evidence.reviewState == .needsReview || section.evidence.reviewState == .unknown {
            reasons.append(.sourceMarkedForReview)
        }
        if section.evidence.confidence < 0.70 {
            reasons.append(.lowConfidence(Int((section.evidence.confidence * 100).rounded())))
        }
        return Self.deduplicated(reasons)
    }

    func canAccept(entry: MenuImportEntry) -> Bool {
        !reviewReasons(for: entry).contains(where: \.blocksAcceptance) &&
            priceState(for: entry).cents != nil
    }

    mutating func acceptEntry(id: String) -> Bool {
        guard let current = entry(id: id), canAccept(entry: current) else { return false }
        return Self.mutateEntry(id: id, in: &draft.sections) { entry in
            entry.reviewState = .accepted
        }
    }

    mutating func rejectEntry(id: String) -> Bool {
        Self.mutateEntry(id: id, in: &draft.sections) { entry in
            entry.reviewState = .rejected
        }
    }

    mutating func restoreEntry(id: String) -> Bool {
        Self.mutateEntry(id: id, in: &draft.sections) { entry in
            entry.reviewState = .needsReview
        }
    }

    mutating func updateEntry(
        id: String,
        name: String,
        description: String,
        priceText: String,
        kind: MenuItemKind
    ) -> Result<Void, MenuImportReviewEditError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.emptyName) }
        guard let cents = MenuImportReviewPriceFormatter.cents(from: priceText) else {
            return .failure(.invalidPrice)
        }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let didUpdate = Self.mutateEntry(id: id, in: &draft.sections) { entry in
            entry.name.value = trimmedName
            entry.name.evidence.reviewState = .edited
            entry.kind = kind.rawValue

            if trimmedDescription.isEmpty {
                entry.description = nil
            } else if entry.description != nil {
                entry.description?.value = trimmedDescription
                entry.description?.evidence.reviewState = .edited
            } else {
                var evidence = entry.name.evidence
                evidence.rawText = trimmedDescription
                evidence.method = .human
                evidence.methodDetail = "reviewer-added-description"
                evidence.confidence = 1
                evidence.reviewState = .edited
                entry.description = MenuImportText(
                    value: trimmedDescription,
                    languageTag: "de",
                    evidence: evidence
                )
            }

            let rawPrice = MenuImportReviewPriceFormatter.string(cents: cents)
            if let offerIndex = entry.offers.firstIndex(where: { $0.priceKind != .delta }) {
                entry.offers[offerIndex].priceKind = .fixed
                entry.offers[offerIndex].amountCents = cents
                entry.offers[offerIndex].deltaCents = nil
                entry.offers[offerIndex].minimumAmountCents = nil
                entry.offers[offerIndex].maximumAmountCents = nil
                entry.offers[offerIndex].currencyCode = "EUR"
                entry.offers[offerIndex].rawPrice = rawPrice
                entry.offers[offerIndex].evidence.reviewState = .edited
            } else {
                var evidence = entry.name.evidence
                evidence.rawText = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
                evidence.method = .human
                evidence.methodDetail = "reviewer-added-price"
                evidence.confidence = 1
                evidence.reviewState = .edited
                entry.offers.insert(
                    MenuImportOffer(
                        id: "\(entry.id)-reviewed-price",
                        priceKind: .fixed,
                        amountCents: cents,
                        currencyCode: "EUR",
                        rawPrice: rawPrice,
                        basis: "per_item",
                        evidence: evidence
                    ),
                    at: 0
                )
            }
            entry.reviewState = .edited
        }

        return didUpdate ? .success(()) : .failure(.entryNotFound)
    }

    mutating func acceptSection(id: String) -> Bool {
        guard let section = sections.first(where: { $0.id == id }),
              !section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return Self.mutateSection(id: id, in: &draft.sections) { section in
            section.reviewState = .accepted
        }
    }

    mutating func updateSectionTitle(id: String, title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        return Self.mutateSection(id: id, in: &draft.sections) { section in
            section.title.value = trimmedTitle
            section.title.evidence.reviewState = .edited
            section.reviewState = .edited
        }
    }

    mutating func rejectSection(id: String) -> Bool {
        Self.mutateSection(id: id, in: &draft.sections) { section in
            section.reviewState = .rejected
        }
    }

    mutating func restoreSection(id: String) -> Bool {
        Self.mutateSection(id: id, in: &draft.sections) { section in
            section.reviewState = .needsReview
        }
    }

    mutating func moveEntry(id: String, direction: MenuImportReviewMoveDirection) -> Bool {
        Self.moveEntry(id: id, direction: direction, in: &draft.sections)
    }

    mutating func moveSection(id: String, direction: MenuImportReviewMoveDirection) -> Bool {
        Self.moveSection(id: id, direction: direction, in: &draft.sections)
    }

    func makeSandboxApplication() throws -> MenuImportSandboxApplication {
        let issues = conversionIssues()
        guard issues.isEmpty else {
            throw MenuImportSandboxConversionError(issues: issues)
        }

        let legend = declarationLegend()
        let convertedSections = sections.compactMap { section -> MenuSectionData? in
            guard section.reviewState != .rejected else { return nil }
            let activeEntries = section.entries.filter { $0.reviewState != .rejected }
            guard !activeEntries.isEmpty else { return nil }
            let sectionKind = Self.sectionKind(for: activeEntries)
            let convertedItems = activeEntries.map { entry in
                MenuItemData(
                    id: entry.id,
                    name: entry.name.value.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: entry.description?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    priceCents: Self.resolvePrice(from: entry.offers).cents ?? 0,
                    kind: MenuItemKind(rawValue: entry.kind) ?? sectionKind,
                    variants: Self.legacyVariants(from: entry),
                    allergenCodes: Self.allergenCodes(from: entry.declarations)
                )
            }
            let confidenceValues = [section.evidence.confidence] + activeEntries.map { $0.name.evidence.confidence }
            return MenuSectionData(
                id: section.id,
                title: section.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: "Importiert und geprüft",
                kind: sectionKind,
                items: convertedItems,
                importConfidence: confidenceValues.min() ?? 1,
                allergenLegend: legend.isEmpty ? nil : legend
            )
        }

        var reviewedDraft = draft
        reviewedDraft.reviewState = .accepted
        return MenuImportSandboxApplication(sections: convertedSections, reviewedDraft: reviewedDraft)
    }

    private func isEntryUnresolved(_ entry: MenuImportEntry) -> Bool {
        guard entry.reviewState != .rejected else { return false }
        if reviewReasons(for: entry).contains(where: \.blocksAcceptance) {
            return true
        }
        guard entry.reviewState != .accepted && entry.reviewState != .edited else { return false }
        return !reviewReasons(for: entry).isEmpty || entry.reviewState == .needsReview || entry.reviewState == .unknown
    }

    private func isSectionUnresolved(_ section: MenuImportReviewSectionSnapshot) -> Bool {
        guard section.reviewState != .rejected else { return false }
        if section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        guard section.reviewState != .accepted && section.reviewState != .edited else { return false }
        return !reviewReasons(for: section).isEmpty
    }

    private func conversionIssues() -> [MenuImportSandboxConversionIssue] {
        var issues: [MenuImportSandboxConversionIssue] = []

        for section in sections where section.reviewState != .rejected {
            if isSectionUnresolved(section) {
                issues.append(
                    MenuImportSandboxConversionIssue(
                        id: "\(section.id)-section-review",
                        sectionID: section.id,
                        entryID: nil,
                        message: "Kategorie \"\(section.title)\" muss bestätigt oder korrigiert werden."
                    )
                )
            }

            for entry in section.entries where entry.reviewState != .rejected {
                if isEntryUnresolved(entry) {
                    issues.append(
                        MenuImportSandboxConversionIssue(
                            id: "\(entry.id)-entry-review",
                            sectionID: section.id,
                            entryID: entry.id,
                            message: "\"\(entry.name.value)\" muss bestätigt, korrigiert oder verworfen werden."
                        )
                    )
                }
            }
        }

        if activeEntryCount == 0 {
            issues.append(
                MenuImportSandboxConversionIssue(
                    id: "empty-menu",
                    sectionID: "",
                    entryID: nil,
                    message: "Mindestens ein Artikel muss für das Sandbox-Menü übrig bleiben."
                )
            )
        }
        return issues
    }

    private func hasUnrepresentableOptions(_ entry: MenuImportEntry) -> Bool {
        entry.optionGroups
            .flatMap(\.choices)
            .filter { $0.reviewState != .rejected }
            .contains { Self.resolveChoicePrice($0).cents == nil }
    }

    private func entryEvidence(_ entry: MenuImportEntry) -> [MenuImportEvidence] {
        var result = [entry.name.evidence]
        if let description = entry.description {
            result.append(description.evidence)
        }
        result.append(contentsOf: entry.offers.map(\.evidence))
        return result
    }

    private func declarationLegend() -> [String: String] {
        let declarations = draft.declarations + sections.flatMap { snapshot in
            draftSection(id: snapshot.id)?.declarations ?? []
        }
        var result: [String: String] = [:]
        for declaration in declarations {
            guard let code = declaration.localCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty else { continue }
            let raw = declaration.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = code + " "
            let title = raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
            if !title.isEmpty, result[code] == nil {
                result[code] = title
            }
        }
        return result
    }

    private func draftSection(id: String) -> MenuImportSection? {
        Self.findSection(id: id, in: draft.sections)
    }

    private mutating func normalizeOrders() {
        Self.normalizeOrders(in: &draft.sections)
    }

    private static func resolvePrice(from offers: [MenuImportOffer]) -> MenuImportReviewPriceState {
        guard let offer = offers.first(where: { $0.priceKind != .delta }) else { return .missing }
        switch offer.priceKind {
        case .fixed, .from:
            guard let cents = offer.amountCents, cents >= 0 else {
                return .unsupported(rawText: offer.rawPrice, kind: offer.priceKind)
            }
            return .resolved(cents: cents, rawText: offer.rawPrice, kind: offer.priceKind)
        case .free:
            return .resolved(cents: 0, rawText: offer.rawPrice, kind: .free)
        case .range, .market, .onRequest, .included, .unknown, .delta:
            return .unsupported(rawText: offer.rawPrice, kind: offer.priceKind)
        }
    }

    private static func resolveChoicePrice(_ choice: MenuImportChoice) -> MenuImportReviewPriceState {
        if choice.kind == MenuItemOptionKind.extra.rawValue,
           let offer = choice.offers.first(where: { $0.priceKind == .delta }),
           let cents = offer.deltaCents, cents >= 0 {
            return .resolved(cents: cents, rawText: offer.rawPrice, kind: .delta)
        }
        return resolvePrice(from: choice.offers)
    }

    private static func legacyVariants(from entry: MenuImportEntry) -> [MenuItemVariant] {
        entry.optionGroups
            .sorted { $0.order < $1.order }
            .flatMap { group in
                group.choices
                    .filter { $0.reviewState != .rejected }
                    .sorted { $0.order < $1.order }
                    .compactMap { choice in
                        guard let cents = resolveChoicePrice(choice).cents else { return nil }
                        return MenuItemVariant(
                            id: choice.id,
                            name: choice.name.value,
                            priceCents: cents,
                            kind: MenuItemOptionKind(rawValue: choice.kind) ?? .variant
                        )
                    }
            }
    }

    private static func allergenCodes(from declarations: [MenuImportDeclaration]) -> String? {
        var seen: Set<String> = []
        let codes = declarations.compactMap(\.localCode).filter { code in
            let normalized = code.lowercased()
            return !normalized.isEmpty && seen.insert(normalized).inserted
        }
        return codes.isEmpty ? nil : codes.joined(separator: ",")
    }

    private static func sectionKind(for entries: [MenuImportEntry]) -> MenuItemKind {
        let kinds = entries.compactMap { MenuItemKind(rawValue: $0.kind) }
        let drinks = kinds.filter { $0 == .drink }.count
        return drinks > kinds.count / 2 ? .drink : .food
    }

    private static func priceKindLabel(_ kind: MenuImportPriceKind) -> String {
        switch kind {
        case .fixed: return "Festpreis"
        case .from: return "Ab-Preis"
        case .range: return "Preisspanne"
        case .market: return "Tagespreis"
        case .onRequest: return "auf Anfrage"
        case .included: return "inklusive"
        case .free: return "kostenlos"
        case .delta: return "Aufpreis"
        case .unknown: return "unbekannt"
        }
    }

    private static func deduplicated(_ reasons: [MenuImportReviewReason]) -> [MenuImportReviewReason] {
        var seen: Set<MenuImportReviewReason> = []
        return reasons.filter { seen.insert($0).inserted }
    }

    private static func flattenedSections(
        _ sections: [MenuImportSection],
        depth: Int = 0
    ) -> [MenuImportReviewSectionSnapshot] {
        sections.sorted { $0.order < $1.order }.flatMap { section in
            let snapshot = MenuImportReviewSectionSnapshot(
                id: section.id,
                title: section.title.value,
                depth: depth,
                reviewState: section.reviewState,
                evidence: section.title.evidence,
                entries: section.entries.sorted { $0.order < $1.order }
            )
            return [snapshot] + flattenedSections(section.subsections, depth: depth + 1)
        }
    }

    private static func mutateEntry(
        id: String,
        in sections: inout [MenuImportSection],
        mutation: (inout MenuImportEntry) -> Void
    ) -> Bool {
        for sectionIndex in sections.indices {
            if let entryIndex = sections[sectionIndex].entries.firstIndex(where: { $0.id == id }) {
                mutation(&sections[sectionIndex].entries[entryIndex])
                return true
            }
            if mutateEntry(id: id, in: &sections[sectionIndex].subsections, mutation: mutation) {
                return true
            }
        }
        return false
    }

    private static func mutateSection(
        id: String,
        in sections: inout [MenuImportSection],
        mutation: (inout MenuImportSection) -> Void
    ) -> Bool {
        for sectionIndex in sections.indices {
            if sections[sectionIndex].id == id {
                mutation(&sections[sectionIndex])
                return true
            }
            if mutateSection(id: id, in: &sections[sectionIndex].subsections, mutation: mutation) {
                return true
            }
        }
        return false
    }

    private static func moveEntry(
        id: String,
        direction: MenuImportReviewMoveDirection,
        in sections: inout [MenuImportSection]
    ) -> Bool {
        for sectionIndex in sections.indices {
            if let entryIndex = sections[sectionIndex].entries.firstIndex(where: { $0.id == id }) {
                let destination = direction == .up ? entryIndex - 1 : entryIndex + 1
                guard sections[sectionIndex].entries.indices.contains(destination) else { return false }
                sections[sectionIndex].entries.swapAt(entryIndex, destination)
                for index in sections[sectionIndex].entries.indices {
                    sections[sectionIndex].entries[index].order = index
                }
                return true
            }
            if moveEntry(id: id, direction: direction, in: &sections[sectionIndex].subsections) {
                return true
            }
        }
        return false
    }

    private static func moveSection(
        id: String,
        direction: MenuImportReviewMoveDirection,
        in sections: inout [MenuImportSection]
    ) -> Bool {
        if let sectionIndex = sections.firstIndex(where: { $0.id == id }) {
            let destination = direction == .up ? sectionIndex - 1 : sectionIndex + 1
            guard sections.indices.contains(destination) else { return false }
            sections.swapAt(sectionIndex, destination)
            for index in sections.indices {
                sections[index].order = index
            }
            return true
        }
        for index in sections.indices {
            if moveSection(id: id, direction: direction, in: &sections[index].subsections) {
                return true
            }
        }
        return false
    }

    private static func normalizeOrders(in sections: inout [MenuImportSection]) {
        sections.sort { $0.order < $1.order }
        for sectionIndex in sections.indices {
            sections[sectionIndex].order = sectionIndex
            sections[sectionIndex].entries.sort { $0.order < $1.order }
            for entryIndex in sections[sectionIndex].entries.indices {
                sections[sectionIndex].entries[entryIndex].order = entryIndex
            }
            normalizeOrders(in: &sections[sectionIndex].subsections)
        }
    }

    private static func findSection(id: String, in sections: [MenuImportSection]) -> MenuImportSection? {
        for section in sections {
            if section.id == id { return section }
            if let match = findSection(id: id, in: section.subsections) { return match }
        }
        return nil
    }
}

enum MenuImportReviewPriceFormatter {
    static func cents(from input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDashPrice = trimmed
            .replacingOccurrences(of: ",-", with: ",00")
            .replacingOccurrences(of: ".-", with: ".00")
        guard !normalizedDashPrice.isEmpty, !normalizedDashPrice.contains("-") else { return nil }

        let numeric = normalizedDashPrice.filter { $0.isNumber || $0 == "," || $0 == "." }
        guard numeric.contains(where: \.isNumber) else { return nil }

        let separators = numeric.indices.filter { numeric[$0] == "," || numeric[$0] == "." }
        let decimalSeparator = separators.last.flatMap { index -> String.Index? in
            let digitsAfter = numeric[numeric.index(after: index)...].filter(\.isNumber).count
            return (1 ... 2).contains(digitsAfter) ? index : nil
        }

        let eurosDigits: String
        let fractionDigits: String
        if let decimalSeparator {
            eurosDigits = String(numeric[..<decimalSeparator].filter(\.isNumber))
            fractionDigits = String(numeric[numeric.index(after: decimalSeparator)...].filter(\.isNumber))
        } else {
            eurosDigits = String(numeric.filter(\.isNumber))
            fractionDigits = ""
        }

        guard let euros = Int(eurosDigits.isEmpty ? "0" : eurosDigits) else { return nil }
        let fraction: Int
        switch fractionDigits.count {
        case 0:
            fraction = 0
        case 1:
            guard let value = Int(fractionDigits) else { return nil }
            fraction = value * 10
        case 2:
            guard let value = Int(fractionDigits) else { return nil }
            fraction = value
        default:
            return nil
        }
        guard euros <= (Int.max - fraction) / 100 else { return nil }
        return euros * 100 + fraction
    }

    static func string(cents: Int) -> String {
        let euros = cents / 100
        let remainder = abs(cents % 100)
        return "\(euros),\(String(format: "%02d", remainder)) €"
    }
}
