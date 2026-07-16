import Foundation

struct MenuImportDraft: Codable, Equatable, Sendable {
    // This contract is intentionally pre-stable while scanner evidence expands.
    static let currentSchemaVersion = "0.1.0"

    let schemaVersion: String
    var id: String
    var sourceDocument: MenuImportSourceDocument
    var sections: [MenuImportSection]
    var declarations: [MenuImportDeclaration]
    var reviewState: MenuImportReviewState

    init(
        schemaVersion: String = MenuImportDraft.currentSchemaVersion,
        id: String = UUID().uuidString,
        sourceDocument: MenuImportSourceDocument,
        sections: [MenuImportSection] = [],
        declarations: [MenuImportDeclaration] = [],
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.sourceDocument = sourceDocument
        self.sections = sections
        self.declarations = declarations
        self.reviewState = reviewState
    }

    func validate(
        using validator: MenuImportDraftValidator = MenuImportDraftValidator()
    ) -> MenuImportValidationResult {
        validator.validate(self)
    }
}

enum MenuImportReviewState: String, Codable, Equatable, Sendable {
    case unreviewed
    case needsReview
    case accepted
    case edited
    case rejected
    case unknown
}

struct MenuImportSourceDocument: Codable, Equatable, Sendable {
    enum SourceType: String, Codable, Equatable, Sendable {
        case camera
        case photoLibrary
        case pdf
        case demoFixture
        case other
    }

    var id: String
    var sourceType: SourceType
    var sourceTypeDetail: String?
    var pageCount: Int
    var fingerprint: String
    var displayName: String?
    var originalURL: URL?

    init(
        id: String = UUID().uuidString,
        sourceType: SourceType,
        sourceTypeDetail: String? = nil,
        pageCount: Int,
        fingerprint: String,
        displayName: String? = nil,
        originalURL: URL? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceTypeDetail = sourceTypeDetail
        self.pageCount = pageCount
        self.fingerprint = fingerprint
        self.displayName = displayName
        self.originalURL = originalURL
    }
}

struct MenuImportNormalizedBoundingBox: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

enum MenuImportEvidenceMethod: String, Codable, Equatable, Sendable {
    case ocr
    case enhancedOCR
    case layoutRule
    case model
    case human
    case imported
    case other
    case unknown
}

struct MenuImportEvidence: Codable, Equatable, Sendable {
    var rawText: String
    var pageIndex: Int
    var boundingBox: MenuImportNormalizedBoundingBox
    var method: MenuImportEvidenceMethod
    var methodDetail: String?
    var confidence: Double
    var reviewState: MenuImportReviewState

    init(
        rawText: String,
        pageIndex: Int,
        boundingBox: MenuImportNormalizedBoundingBox,
        method: MenuImportEvidenceMethod,
        methodDetail: String? = nil,
        confidence: Double,
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.rawText = rawText
        self.pageIndex = pageIndex
        self.boundingBox = boundingBox
        self.method = method
        self.methodDetail = methodDetail
        self.confidence = confidence
        self.reviewState = reviewState
    }
}

struct MenuImportText: Codable, Equatable, Sendable {
    var value: String
    var languageTag: String?
    var evidence: MenuImportEvidence

    init(value: String, languageTag: String? = nil, evidence: MenuImportEvidence) {
        self.value = value
        self.languageTag = languageTag
        self.evidence = evidence
    }
}

struct MenuImportSection: Codable, Equatable, Sendable {
    var id: String
    var title: MenuImportText
    var order: Int
    var entries: [MenuImportEntry]
    var subsections: [MenuImportSection]
    var declarations: [MenuImportDeclaration]
    var continuedFromSectionID: String?
    var reviewState: MenuImportReviewState

    init(
        id: String = UUID().uuidString,
        title: MenuImportText,
        order: Int,
        entries: [MenuImportEntry] = [],
        subsections: [MenuImportSection] = [],
        declarations: [MenuImportDeclaration] = [],
        continuedFromSectionID: String? = nil,
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.entries = entries
        self.subsections = subsections
        self.declarations = declarations
        self.continuedFromSectionID = continuedFromSectionID
        self.reviewState = reviewState
    }
}

struct MenuImportEntry: Codable, Equatable, Sendable {
    var id: String
    var kind: String
    var name: MenuImportText
    var description: MenuImportText?
    var itemNumber: String?
    var order: Int
    var offers: [MenuImportOffer]
    var quantities: [MenuImportQuantity]
    var optionGroups: [MenuImportOptionGroup]
    var bundleComponents: [MenuImportBundleComponent]
    var declarations: [MenuImportDeclaration]
    var reviewState: MenuImportReviewState

    init(
        id: String = UUID().uuidString,
        kind: String = "unknown",
        name: MenuImportText,
        description: MenuImportText? = nil,
        itemNumber: String? = nil,
        order: Int,
        offers: [MenuImportOffer] = [],
        quantities: [MenuImportQuantity] = [],
        optionGroups: [MenuImportOptionGroup] = [],
        bundleComponents: [MenuImportBundleComponent] = [],
        declarations: [MenuImportDeclaration] = [],
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.description = description
        self.itemNumber = itemNumber
        self.order = order
        self.offers = offers
        self.quantities = quantities
        self.optionGroups = optionGroups
        self.bundleComponents = bundleComponents
        self.declarations = declarations
        self.reviewState = reviewState
    }
}

enum MenuImportPriceKind: String, Codable, Equatable, Sendable {
    case fixed
    case from
    case range
    case market
    case onRequest
    case included
    case free
    case delta
    case unknown
}

struct MenuImportOffer: Codable, Equatable, Sendable {
    var id: String
    var priceKind: MenuImportPriceKind
    var amountCents: Int?
    var deltaCents: Int?
    var minimumAmountCents: Int?
    var maximumAmountCents: Int?
    var currencyCode: String?
    var rawPrice: String

    /// Open value such as `per_item`, `per_person`, or source-specific wording.
    var basis: String
    var appliesToQuantityID: String?
    var evidence: MenuImportEvidence

    init(
        id: String = UUID().uuidString,
        priceKind: MenuImportPriceKind,
        amountCents: Int? = nil,
        deltaCents: Int? = nil,
        minimumAmountCents: Int? = nil,
        maximumAmountCents: Int? = nil,
        currencyCode: String? = nil,
        rawPrice: String,
        basis: String = "unknown",
        appliesToQuantityID: String? = nil,
        evidence: MenuImportEvidence
    ) {
        self.id = id
        self.priceKind = priceKind
        self.amountCents = amountCents
        self.deltaCents = deltaCents
        self.minimumAmountCents = minimumAmountCents
        self.maximumAmountCents = maximumAmountCents
        self.currencyCode = currencyCode
        self.rawPrice = rawPrice
        self.basis = basis
        self.appliesToQuantityID = appliesToQuantityID
        self.evidence = evidence
    }
}

struct MenuImportQuantity: Codable, Equatable, Sendable {
    var id: String
    var rawText: String
    var value: Double?

    /// Open unit value; normalization is provider-owned and may remain `unknown`.
    var unit: String
    var kind: String
    var evidence: MenuImportEvidence

    init(
        id: String = UUID().uuidString,
        rawText: String,
        value: Double? = nil,
        unit: String = "unknown",
        kind: String = "unknown",
        evidence: MenuImportEvidence
    ) {
        self.id = id
        self.rawText = rawText
        self.value = value
        self.unit = unit
        self.kind = kind
        self.evidence = evidence
    }
}

struct MenuImportSelectionRule: Codable, Equatable, Sendable {
    var minimum: Int?
    var maximum: Int?
    var freeSelectionCount: Int?
    var mode: String
    var allowsRepeats: Bool?

    init(
        minimum: Int? = nil,
        maximum: Int? = nil,
        freeSelectionCount: Int? = nil,
        mode: String = "unknown",
        allowsRepeats: Bool? = nil
    ) {
        self.minimum = minimum
        self.maximum = maximum
        self.freeSelectionCount = freeSelectionCount
        self.mode = mode
        self.allowsRepeats = allowsRepeats
    }
}

struct MenuImportOptionGroup: Codable, Equatable, Sendable {
    var id: String
    var title: MenuImportText
    var order: Int
    var selectionRule: MenuImportSelectionRule
    var choices: [MenuImportChoice]
    var reviewState: MenuImportReviewState

    init(
        id: String = UUID().uuidString,
        title: MenuImportText,
        order: Int,
        selectionRule: MenuImportSelectionRule,
        choices: [MenuImportChoice] = [],
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.selectionRule = selectionRule
        self.choices = choices
        self.reviewState = reviewState
    }
}

struct MenuImportChoice: Codable, Equatable, Sendable {
    var id: String
    var name: MenuImportText
    var kind: String
    var order: Int
    var offers: [MenuImportOffer]
    var quantity: MenuImportQuantity?
    var declarations: [MenuImportDeclaration]
    var reviewState: MenuImportReviewState

    init(
        id: String = UUID().uuidString,
        name: MenuImportText,
        kind: String = "unknown",
        order: Int,
        offers: [MenuImportOffer] = [],
        quantity: MenuImportQuantity? = nil,
        declarations: [MenuImportDeclaration] = [],
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.order = order
        self.offers = offers
        self.quantity = quantity
        self.declarations = declarations
        self.reviewState = reviewState
    }
}

struct MenuImportBundleComponent: Codable, Equatable, Sendable {
    var id: String
    var title: MenuImportText
    var kind: String
    var order: Int
    var quantity: MenuImportQuantity?
    var optionGroup: MenuImportOptionGroup?
    var declarations: [MenuImportDeclaration]
    var reviewState: MenuImportReviewState

    init(
        id: String = UUID().uuidString,
        title: MenuImportText,
        kind: String = "unknown",
        order: Int,
        quantity: MenuImportQuantity? = nil,
        optionGroup: MenuImportOptionGroup? = nil,
        declarations: [MenuImportDeclaration] = [],
        reviewState: MenuImportReviewState = .unreviewed
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.order = order
        self.quantity = quantity
        self.optionGroup = optionGroup
        self.declarations = declarations
        self.reviewState = reviewState
    }
}

struct MenuImportDeclaration: Codable, Equatable, Sendable {
    var id: String

    /// Open values avoid treating the discovery taxonomy as a product ontology.
    var kind: String
    var rawText: String
    var localCode: String?
    var canonicalID: String?
    var claim: String
    var scope: String
    var evidence: MenuImportEvidence

    init(
        id: String = UUID().uuidString,
        kind: String = "unknown",
        rawText: String,
        localCode: String? = nil,
        canonicalID: String? = nil,
        claim: String = "unknown",
        scope: String = "unknown",
        evidence: MenuImportEvidence
    ) {
        self.id = id
        self.kind = kind
        self.rawText = rawText
        self.localCode = localCode
        self.canonicalID = canonicalID
        self.claim = claim
        self.scope = scope
        self.evidence = evidence
    }
}

enum MenuImportValidationSeverity: String, Codable, Equatable, Sendable {
    case error
    case warning
}

enum MenuImportValidationCode: String, Codable, Equatable, Sendable {
    case unsupportedSchemaVersion
    case duplicateID
    case emptyID
    case invalidPageCount
    case emptyFingerprint
    case emptyText
    case emptyRawText
    case invalidPageIndex
    case invalidBoundingBox
    case invalidConfidence
    case invalidOrder
    case duplicateOrder
    case invalidPrice
    case invalidQuantity
    case invalidSelectionRange
    case emptyOpenValue
    case missingPrice
}

struct MenuImportValidationIssue: Codable, Equatable, Sendable {
    var severity: MenuImportValidationSeverity
    var code: MenuImportValidationCode
    var path: String
    var message: String
}

struct MenuImportValidationResult: Codable, Equatable, Sendable {
    var issues: [MenuImportValidationIssue]

    var errors: [MenuImportValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    var warnings: [MenuImportValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    var isValid: Bool {
        errors.isEmpty
    }
}

struct MenuImportDraftValidator: Sendable {
    func validate(_ draft: MenuImportDraft) -> MenuImportValidationResult {
        var context = ValidationContext(pageCount: draft.sourceDocument.pageCount)

        if draft.schemaVersion != MenuImportDraft.currentSchemaVersion {
            context.addError(
                .unsupportedSchemaVersion,
                path: "schemaVersion",
                message: "Expected schema version \(MenuImportDraft.currentSchemaVersion)."
            )
        }

        context.registerID(draft.id, path: "id")
        context.validateSourceDocument(draft.sourceDocument, path: "sourceDocument")
        context.validateDeclarations(draft.declarations, path: "declarations")
        context.validateSections(draft.sections, path: "sections")

        return MenuImportValidationResult(issues: context.issues)
    }
}

private struct ValidationContext {
    let pageCount: Int
    var issues: [MenuImportValidationIssue] = []
    private var registeredIDs: [String: String] = [:]

    init(pageCount: Int) {
        self.pageCount = pageCount
    }

    mutating func validateSourceDocument(
        _ sourceDocument: MenuImportSourceDocument,
        path: String
    ) {
        registerID(sourceDocument.id, path: "\(path).id")

        if sourceDocument.pageCount < 1 {
            addError(
                .invalidPageCount,
                path: "\(path).pageCount",
                message: "A source document must contain at least one page."
            )
        }

        if sourceDocument.fingerprint.isBlank {
            addError(
                .emptyFingerprint,
                path: "\(path).fingerprint",
                message: "The source fingerprint must not be empty."
            )
        }
    }

    mutating func validateSections(_ sections: [MenuImportSection], path: String) {
        validateOrders(sections.map(\.order), path: path)

        for (index, section) in sections.enumerated() {
            let sectionPath = "\(path)[\(index)]"
            registerID(section.id, path: "\(sectionPath).id")
            validateOrder(section.order, path: "\(sectionPath).order")
            validateText(section.title, path: "\(sectionPath).title")
            validateDeclarations(section.declarations, path: "\(sectionPath).declarations")
            validateEntries(section.entries, path: "\(sectionPath).entries")
            validateSections(section.subsections, path: "\(sectionPath).subsections")
        }
    }

    mutating func validateEntries(_ entries: [MenuImportEntry], path: String) {
        validateOrders(entries.map(\.order), path: path)

        for (index, entry) in entries.enumerated() {
            let entryPath = "\(path)[\(index)]"
            registerID(entry.id, path: "\(entryPath).id")
            validateOrder(entry.order, path: "\(entryPath).order")
            validateOpenValue(entry.kind, path: "\(entryPath).kind")
            validateText(entry.name, path: "\(entryPath).name")
            if let description = entry.description {
                validateText(description, path: "\(entryPath).description")
            }

            for (offerIndex, offer) in entry.offers.enumerated() {
                validateOffer(offer, path: "\(entryPath).offers[\(offerIndex)]")
            }
            for (quantityIndex, quantity) in entry.quantities.enumerated() {
                validateQuantity(quantity, path: "\(entryPath).quantities[\(quantityIndex)]")
            }
            validateOptionGroups(entry.optionGroups, path: "\(entryPath).optionGroups")
            validateBundleComponents(
                entry.bundleComponents,
                path: "\(entryPath).bundleComponents"
            )
            validateDeclarations(entry.declarations, path: "\(entryPath).declarations")

            if !entryContainsPrice(entry) {
                addWarning(
                    .missingPrice,
                    path: "\(entryPath).offers",
                    message: "No visible price was imported; the entry remains editable and valid."
                )
            }
        }
    }

    mutating func validateOffer(_ offer: MenuImportOffer, path: String) {
        registerID(offer.id, path: "\(path).id")
        validateRawText(offer.rawPrice, path: "\(path).rawPrice")
        validateOpenValue(offer.basis, path: "\(path).basis")
        validateEvidence(offer.evidence, path: "\(path).evidence")

        let fieldsAreNonnegative = [
            offer.amountCents,
            offer.minimumAmountCents,
            offer.maximumAmountCents
        ]
        .compactMap { $0 }
        .allSatisfy { $0 >= 0 }

        let isValid: Bool
        switch offer.priceKind {
        case .fixed:
            isValid = offer.amountCents != nil
                && offer.deltaCents == nil
                && offer.minimumAmountCents == nil
                && offer.maximumAmountCents == nil
        case .from:
            isValid = offer.amountCents == nil
                && offer.deltaCents == nil
                && offer.minimumAmountCents != nil
                && offer.maximumAmountCents == nil
        case .range:
            isValid = offer.amountCents == nil
                && offer.deltaCents == nil
                && offer.minimumAmountCents != nil
                && offer.maximumAmountCents != nil
                && offer.minimumAmountCents! <= offer.maximumAmountCents!
        case .market, .onRequest, .included, .unknown:
            isValid = offer.amountCents == nil
                && offer.deltaCents == nil
                && offer.minimumAmountCents == nil
                && offer.maximumAmountCents == nil
        case .free:
            isValid = offer.amountCents == 0
                && offer.deltaCents == nil
                && offer.minimumAmountCents == nil
                && offer.maximumAmountCents == nil
        case .delta:
            isValid = offer.amountCents == nil
                && offer.deltaCents != nil
                && offer.minimumAmountCents == nil
                && offer.maximumAmountCents == nil
        }

        if !fieldsAreNonnegative || !isValid {
            addError(
                .invalidPrice,
                path: path,
                message: "Absolute and delta price fields do not match priceKind \(offer.priceKind.rawValue)."
            )
        }
    }

    mutating func validateQuantity(_ quantity: MenuImportQuantity, path: String) {
        registerID(quantity.id, path: "\(path).id")
        validateRawText(quantity.rawText, path: "\(path).rawText")
        validateOpenValue(quantity.unit, path: "\(path).unit")
        validateOpenValue(quantity.kind, path: "\(path).kind")
        validateEvidence(quantity.evidence, path: "\(path).evidence")

        if let value = quantity.value, !value.isFinite || value < 0 {
            addError(
                .invalidQuantity,
                path: "\(path).value",
                message: "A normalized quantity must be finite and nonnegative."
            )
        }
    }

    mutating func validateOptionGroups(
        _ optionGroups: [MenuImportOptionGroup],
        path: String
    ) {
        validateOrders(optionGroups.map(\.order), path: path)

        for (index, group) in optionGroups.enumerated() {
            let groupPath = "\(path)[\(index)]"
            registerID(group.id, path: "\(groupPath).id")
            validateOrder(group.order, path: "\(groupPath).order")
            validateText(group.title, path: "\(groupPath).title")
            validateSelectionRule(group.selectionRule, path: "\(groupPath).selectionRule")
            validateChoices(group.choices, path: "\(groupPath).choices")
        }
    }

    mutating func validateSelectionRule(
        _ rule: MenuImportSelectionRule,
        path: String
    ) {
        validateOpenValue(rule.mode, path: "\(path).mode")

        let valuesAreNonnegative = [rule.minimum, rule.maximum, rule.freeSelectionCount]
            .compactMap { $0 }
            .allSatisfy { $0 >= 0 }
        let minimumDoesNotExceedMaximum = rule.minimum == nil
            || rule.maximum == nil
            || rule.minimum! <= rule.maximum!
        let freeCountFitsMaximum = rule.freeSelectionCount == nil
            || rule.maximum == nil
            || rule.freeSelectionCount! <= rule.maximum!

        if !valuesAreNonnegative || !minimumDoesNotExceedMaximum || !freeCountFitsMaximum {
            addError(
                .invalidSelectionRange,
                path: path,
                message: "Selection minimum, maximum, and free count contradict each other."
            )
        }
    }

    mutating func validateChoices(_ choices: [MenuImportChoice], path: String) {
        validateOrders(choices.map(\.order), path: path)

        for (index, choice) in choices.enumerated() {
            let choicePath = "\(path)[\(index)]"
            registerID(choice.id, path: "\(choicePath).id")
            validateOrder(choice.order, path: "\(choicePath).order")
            validateOpenValue(choice.kind, path: "\(choicePath).kind")
            validateText(choice.name, path: "\(choicePath).name")
            for (offerIndex, offer) in choice.offers.enumerated() {
                validateOffer(offer, path: "\(choicePath).offers[\(offerIndex)]")
            }
            if let quantity = choice.quantity {
                validateQuantity(quantity, path: "\(choicePath).quantity")
            }
            validateDeclarations(choice.declarations, path: "\(choicePath).declarations")
        }
    }

    mutating func validateBundleComponents(
        _ components: [MenuImportBundleComponent],
        path: String
    ) {
        validateOrders(components.map(\.order), path: path)

        for (index, component) in components.enumerated() {
            let componentPath = "\(path)[\(index)]"
            registerID(component.id, path: "\(componentPath).id")
            validateOrder(component.order, path: "\(componentPath).order")
            validateOpenValue(component.kind, path: "\(componentPath).kind")
            validateText(component.title, path: "\(componentPath).title")
            if let quantity = component.quantity {
                validateQuantity(quantity, path: "\(componentPath).quantity")
            }
            if let optionGroup = component.optionGroup {
                validateOptionGroups([optionGroup], path: "\(componentPath).optionGroup")
            }
            validateDeclarations(
                component.declarations,
                path: "\(componentPath).declarations"
            )
        }
    }

    mutating func validateDeclarations(
        _ declarations: [MenuImportDeclaration],
        path: String
    ) {
        for (index, declaration) in declarations.enumerated() {
            let declarationPath = "\(path)[\(index)]"
            registerID(declaration.id, path: "\(declarationPath).id")
            validateOpenValue(declaration.kind, path: "\(declarationPath).kind")
            validateRawText(declaration.rawText, path: "\(declarationPath).rawText")
            validateOpenValue(declaration.claim, path: "\(declarationPath).claim")
            validateOpenValue(declaration.scope, path: "\(declarationPath).scope")
            validateEvidence(declaration.evidence, path: "\(declarationPath).evidence")
        }
    }

    mutating func validateText(_ text: MenuImportText, path: String) {
        if text.value.isBlank {
            addError(
                .emptyText,
                path: "\(path).value",
                message: "Visible text must not be empty."
            )
        }
        validateEvidence(text.evidence, path: "\(path).evidence")
    }

    mutating func validateEvidence(_ evidence: MenuImportEvidence, path: String) {
        validateRawText(evidence.rawText, path: "\(path).rawText")

        if evidence.pageIndex < 0 || pageCount < 1 || evidence.pageIndex >= pageCount {
            addError(
                .invalidPageIndex,
                path: "\(path).pageIndex",
                message: "Evidence pageIndex must address a page in the source document."
            )
        }

        let box = evidence.boundingBox
        let values = [box.x, box.y, box.width, box.height]
        let valuesAreNormalized = values.allSatisfy { $0.isFinite && (0...1).contains($0) }
        let hasArea = box.width > 0 && box.height > 0
        let fitsPage = box.x + box.width <= 1 && box.y + box.height <= 1

        if !valuesAreNormalized || !hasArea || !fitsPage {
            addError(
                .invalidBoundingBox,
                path: "\(path).boundingBox",
                message: "Evidence bounding boxes must have positive area and remain within 0...1."
            )
        }

        if !evidence.confidence.isFinite || !(0...1).contains(evidence.confidence) {
            addError(
                .invalidConfidence,
                path: "\(path).confidence",
                message: "Evidence confidence must be within 0...1."
            )
        }
    }

    mutating func validateRawText(_ value: String, path: String) {
        if value.isBlank {
            addError(.emptyRawText, path: path, message: "Raw source text must not be empty.")
        }
    }

    mutating func validateOpenValue(_ value: String, path: String) {
        if value.isBlank {
            addError(
                .emptyOpenValue,
                path: path,
                message: "Use an explicit value such as 'unknown' instead of an empty string."
            )
        }
    }

    mutating func validateOrder(_ order: Int, path: String) {
        if order < 0 {
            addError(.invalidOrder, path: path, message: "Visible order must be nonnegative.")
        }
    }

    mutating func validateOrders(_ orders: [Int], path: String) {
        var seen: Set<Int> = []
        for order in orders where !seen.insert(order).inserted {
            addError(
                .duplicateOrder,
                path: path,
                message: "Sibling elements must not share visible order \(order)."
            )
        }
    }

    mutating func registerID(_ id: String, path: String) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else {
            addError(.emptyID, path: path, message: "Stable IDs must not be empty.")
            return
        }

        if let firstPath = registeredIDs[normalizedID] {
            addError(
                .duplicateID,
                path: path,
                message: "ID '\(normalizedID)' is already used at \(firstPath)."
            )
        } else {
            registeredIDs[normalizedID] = path
        }
    }

    mutating func addError(
        _ code: MenuImportValidationCode,
        path: String,
        message: String
    ) {
        issues.append(
            MenuImportValidationIssue(
                severity: .error,
                code: code,
                path: path,
                message: message
            )
        )
    }

    mutating func addWarning(
        _ code: MenuImportValidationCode,
        path: String,
        message: String
    ) {
        issues.append(
            MenuImportValidationIssue(
                severity: .warning,
                code: code,
                path: path,
                message: message
            )
        )
    }

    private func entryContainsPrice(_ entry: MenuImportEntry) -> Bool {
        if !entry.offers.isEmpty {
            return true
        }
        if entry.optionGroups.contains(where: { group in
            group.choices.contains(where: { !$0.offers.isEmpty })
        }) {
            return true
        }
        return entry.bundleComponents.contains(where: { component in
            component.optionGroup?.choices.contains(where: { !$0.offers.isEmpty }) == true
        })
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
