import CryptoKit
import Foundation

// MARK: - Provider-facing extraction contract

/// Lossless, page-scoped response expected from a semantic extraction provider.
///
/// The provider never writes `MenuSectionData`. It describes visible menu
/// structure and cites stable OCR line IDs; `MenuImportDraftAssembler` is the
/// only component that turns that response into the canonical import draft.
struct MenuImportPageExtraction: Codable, Equatable, Sendable {
    static let currentContractVersion = "1.0.0"

    var contractVersion: String
    var pageIndex: Int
    var pageKind: String
    var languages: [String]
    var sections: [MenuImportExtractedSection]
    var declarations: [MenuImportExtractedDeclaration]
    var reviewReasons: [MenuImportExtractedReviewReason]

    var recursiveEntryCount: Int {
        func count(_ sections: [MenuImportExtractedSection]) -> Int {
            sections.reduce(0) {
                $0 + $1.entries.count + count($1.subsections)
            }
        }
        return count(sections)
    }

    var permitsEmptyMenuResult: Bool {
        switch pageKind
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "") {
        case "cover", "information", "legend":
            return true
        default:
            return false
        }
    }
}

struct MenuImportExtractedLocalizedText: Codable, Equatable, Sendable {
    var value: String
    var languageTag: String?
    // `Ids` deliberately matches Foundation's snake_case conversion
    // (`evidence_line_ids` -> `evidenceLineIds`).
    var evidenceLineIds: [String]
}

struct MenuImportExtractedText: Codable, Equatable, Sendable {
    var value: String
    var languageTag: String?
    var evidenceLineIds: [String]
    var alternatives: [MenuImportExtractedLocalizedText]
}

struct MenuImportExtractedSection: Codable, Equatable, Sendable {
    var title: MenuImportExtractedText
    var order: Int
    var entries: [MenuImportExtractedEntry]
    var subsections: [MenuImportExtractedSection]
    var declarations: [MenuImportExtractedDeclaration]
    var reviewReasons: [MenuImportExtractedReviewReason]
}

struct MenuImportExtractedEntry: Codable, Equatable, Sendable {
    var kind: String
    var name: MenuImportExtractedText
    var description: MenuImportExtractedText?
    var itemNumber: String?
    var order: Int
    var offers: [MenuImportExtractedOffer]
    var quantities: [MenuImportExtractedQuantity]
    var optionGroups: [MenuImportExtractedOptionGroup]
    var bundleComponents: [MenuImportExtractedBundleComponent]
    var declarations: [MenuImportExtractedDeclaration]
    var reviewReasons: [MenuImportExtractedReviewReason]
}

struct MenuImportExtractedOffer: Codable, Equatable, Sendable {
    var label: MenuImportExtractedText?
    var priceKind: String
    var amountCents: Int?
    var deltaCents: Int?
    var minimumAmountCents: Int?
    var maximumAmountCents: Int?
    var currencyCode: String?
    var rawPrice: String?
    var basis: String
    var appliesToQuantityOrder: Int?
    var evidenceLineIds: [String]
}

struct MenuImportExtractedQuantity: Codable, Equatable, Sendable {
    var rawText: String
    var value: Double?
    var unit: String
    var kind: String
    var evidenceLineIds: [String]
}

struct MenuImportExtractedSelectionRule: Codable, Equatable, Sendable {
    var minimum: Int?
    var maximum: Int?
    var freeSelectionCount: Int?
    var mode: String
    var allowsRepeats: Bool?
}

struct MenuImportExtractedOptionGroup: Codable, Equatable, Sendable {
    var title: MenuImportExtractedText
    var order: Int
    var selectionRule: MenuImportExtractedSelectionRule
    var choices: [MenuImportExtractedChoice]
    var reviewReasons: [MenuImportExtractedReviewReason]
}

struct MenuImportExtractedChoice: Codable, Equatable, Sendable {
    var name: MenuImportExtractedText
    var description: MenuImportExtractedText?
    var kind: String
    var order: Int
    var offers: [MenuImportExtractedOffer]
    var quantity: MenuImportExtractedQuantity?
    var declarations: [MenuImportExtractedDeclaration]
    var reviewReasons: [MenuImportExtractedReviewReason]
}

struct MenuImportExtractedBundleComponent: Codable, Equatable, Sendable {
    var title: MenuImportExtractedText
    var description: MenuImportExtractedText?
    var kind: String
    var order: Int
    var quantity: MenuImportExtractedQuantity?
    var optionGroup: MenuImportExtractedOptionGroup?
    var offers: [MenuImportExtractedOffer]
    var declarations: [MenuImportExtractedDeclaration]
    var reviewReasons: [MenuImportExtractedReviewReason]
}

struct MenuImportExtractedDeclaration: Codable, Equatable, Sendable {
    var kind: String
    var rawText: String
    var alternatives: [MenuImportExtractedLocalizedText]?
    var localCode: String?
    // `canonical_id` becomes `canonicalId` with `.convertFromSnakeCase`.
    var canonicalId: String?
    var claim: String
    var scope: String
    var evidenceLineIds: [String]
}

struct MenuImportExtractedReviewReason: Codable, Equatable, Sendable {
    var code: String
    var path: String
    var message: String
    var severity: String
    var evidenceLineIds: [String]
}

// MARK: - Stable OCR evidence references

struct MenuImportEvidenceLineReference: Equatable, Sendable {
    let id: String
    let line: MenuImportOCRLine
}

struct MenuImportEvidenceLineIndex: Sendable {
    let references: [MenuImportEvidenceLineReference]

    private let linesByID: [String: MenuImportOCRLine]
    private let firstLineByPage: [Int: MenuImportOCRLine]

    init(lines: [MenuImportOCRLine]) {
        let usableLines = lines.enumerated().filter {
            !$0.element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let grouped = Dictionary(grouping: usableLines, by: \.element.pageIndex)
        var builtReferences: [MenuImportEvidenceLineReference] = []

        for pageIndex in grouped.keys.sorted() {
            let pageLines = (grouped[pageIndex] ?? []).sorted {
                let yDifference = abs($0.element.midY - $1.element.midY)
                if yDifference > 0.012 {
                    return $0.element.midY > $1.element.midY
                }
                if $0.element.minX != $1.element.minX {
                    return $0.element.minX < $1.element.minX
                }
                if $0.element.minY != $1.element.minY {
                    return $0.element.minY > $1.element.minY
                }
                if $0.element.text != $1.element.text {
                    return $0.element.text < $1.element.text
                }
                return $0.offset < $1.offset
            }
            for (lineIndex, indexedLine) in pageLines.enumerated() {
                builtReferences.append(
                    MenuImportEvidenceLineReference(
                        id: "p\(pageIndex + 1)-l\(lineIndex + 1)",
                        line: indexedLine.element
                    )
                )
            }
        }

        references = builtReferences
        linesByID = Dictionary(
            uniqueKeysWithValues: builtReferences.map { ($0.id, $0.line) }
        )
        firstLineByPage = builtReferences.reduce(into: [:]) { result, reference in
            if result[reference.line.pageIndex] == nil {
                result[reference.line.pageIndex] = reference.line
            }
        }
    }

    func line(for id: String) -> MenuImportOCRLine? {
        linesByID[id]
    }

    func firstLine(on pageIndex: Int) -> MenuImportOCRLine? {
        firstLineByPage[pageIndex]
    }

    func promptDump(pageIndex: Int, maximumCharacters: Int = 14_000) -> String {
        let lines = references
            .filter { $0.line.pageIndex == pageIndex }
            .map { reference in
                let box = reference.line
                return "\(reference.id) "
                    + "[x=\(Self.decimal(box.minX)) y=\(Self.decimal(box.minY)) "
                    + "w=\(Self.decimal(box.width)) h=\(Self.decimal(box.height)) "
                    + "confidence=\(Self.decimal(box.confidence))] "
                    + box.text
            }
            .joined(separator: "\n")
        return String(lines.prefix(maximumCharacters))
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

// MARK: - Versioned prompt

enum MenuImportExtractionPrompt {
    /// `1.0.4`, not `1.0.3`: an earlier `1.0.3` tightening caused a severe
    /// regression (entry F1 `0.059` against `0.474`) and was fully reverted, so
    /// that number stays burned to keep run archives unambiguous.
    ///
    /// `1.0.4` closes three gaps the first paid Gemini run exposed against the
    /// ten-page gate: the review-code vocabulary was never stated (the model
    /// invented its own codes, so `expectedReviewRecall` was `0.143`),
    /// `currency_code` was left unset on visible euro prices
    /// (`currencyAccuracy 0.775`), and trailing declaration code runs stayed
    /// inside entry names — the only two "missing" entries of the run were
    /// `Bunter Marktsalat WI` and `Veganes Kokoscurry [FI]`, which are not
    /// losses but unnormalized names.
    static let version = "menu-import-extraction/1.0.4"

    static let systemPrompt = """
    You extract a restaurant menu page into lossless JSON. Return one JSON object
    only, without Markdown. The object MUST use snake_case and this exact shape:
    {
      "contract_version": "1.0.0",
      "page_index": 0,
      "page_kind": "menu|cover|information|legend|mixed|unknown",
      "languages": ["de", "en"],
      "sections": [{
        "title": TEXT,
        "order": 0,
        "entries": [ENTRY],
        "subsections": [],
        "declarations": [],
        "review_reasons": []
      }],
      "declarations": [DECLARATION],
      "review_reasons": [REVIEW_REASON]
    }

    TEXT is:
    {
      "value": "visible primary text, unchanged",
      "language_tag": "de",
      "evidence_line_ids": ["p1-l1"],
      "alternatives": [{
        "value": "visible translation, unchanged",
        "language_tag": "en",
        "evidence_line_ids": ["p1-l2"]
      }]
    }

    ENTRY is:
    {
      "kind": "food|drink|bundle|unknown",
      "name": TEXT,
      "description": TEXT or null,
      "item_number": null,
      "order": 0,
      "offers": [OFFER],
      "quantities": [QUANTITY],
      "option_groups": [OPTION_GROUP],
      "bundle_components": [BUNDLE_COMPONENT],
      "declarations": [DECLARATION],
      "review_reasons": [REVIEW_REASON]
    }

    OFFER is:
    {
      "label": TEXT or null,
      "price_kind": "fixed|from|range|market|on_request|included|free|delta|unknown",
      "amount_cents": 1290 or null,
      "delta_cents": null,
      "minimum_amount_cents": null,
      "maximum_amount_cents": null,
      "currency_code": "EUR" or null,
      "raw_price": "12,90 €" or null,
      "basis": "per_item|per_person|unknown",
      "applies_to_quantity_order": null,
      "evidence_line_ids": ["p1-l3"]
    }

    QUANTITY is:
    {
      "raw_text": "250gr",
      "value": 250,
      "unit": "g",
      "kind": "weight|volume|diameter|portion|unknown",
      "evidence_line_ids": ["p1-l4"]
    }

    OPTION_GROUP is:
    {
      "title": TEXT,
      "order": 0,
      "selection_rule": {
        "minimum": 1 or null,
        "maximum": 1 or null,
        "free_selection_count": null,
        "mode": "single|multiple|unknown",
        "allows_repeats": false or null
      },
      "choices": [{
        "name": TEXT,
        "description": TEXT or null,
        "kind": "size|portion|extra|side|variant|bundle_choice|unknown",
        "order": 0,
        "offers": [OFFER],
        "quantity": QUANTITY or null,
        "declarations": [],
        "review_reasons": []
      }],
      "review_reasons": []
    }

    BUNDLE_COMPONENT is:
    {
      "title": TEXT,
      "description": TEXT or null,
      "kind": "course|choice_course|unknown",
      "order": 0,
      "quantity": null,
      "option_group": OPTION_GROUP or null,
      "offers": [],
      "declarations": [],
      "review_reasons": []
    }

    DECLARATION is:
    {
      "kind": "source_declaration|dietary_claim|notice|unknown",
      "raw_text": "visible source text, unchanged",
      "alternatives": [{
        "value": "visible translation, unchanged",
        "language_tag": "en",
        "evidence_line_ids": ["p1-l6"]
      }],
      "local_code": "a" or null,
      "canonical_id": null,
      "claim": "declared|vegan|vegetarian|unknown",
      "scope": "entry|choice|section|document|unknown",
      "evidence_line_ids": ["p1-l5"]
    }

    REVIEW_REASON is:
    {
      "code": "one of the codes listed below",
      "path": "human-readable local path",
      "message": "what a person must verify",
      "severity": "info|warning|error",
      "evidence_line_ids": ["p1-l7"]
    }

    Use exactly these review codes. They are what the operator's review screen
    knows how to present; an unlisted code is dropped:
    - missing_visible_price: the entry shows no price on this page.
    - source_declaration_meaning_unknown: a declaration code is used but no
      visible legend on this page explains it.
    - selection_rule_unknown: options are visible but the page does not state
      how many a guest must or may pick.
    - complex_bundle_choice: a bundle course offers a choice whose rule or
      pricing is not fully printed.
    - chef_composed_bundle: the menu is described as composed by the kitchen
      rather than listing its courses.
    - headline_price_unmapped_to_portion_choice: a price stands at the entry
      while the page also prints portion or size prices, so which one the
      headline price belongs to is not proven.
    - relationship_scope_ambiguous: it is not provable whether a price,
      declaration or option belongs to the entry, the section or the page.
    - translation_pairing_unproven: two languages are visible but their pairing
      is not certain.
    - evidence_missing: a visible value has no matching OCR line.

    Rules:
    - Keep every visible purchasable entry, including entries with no visible
      price. An unpriced entry has an empty offers array plus a
      missing_visible_price review reason. Never discard it.
    - Copy visible spelling, punctuation, spacing, capitalization, quantities,
      price strings, and source codes. Do not silently correct source typos.
    - Cite only OCR line IDs supplied by the user. Cite every visible value.
      Never invent a line ID. An empty evidence_line_ids array is permitted only
      when no supplied OCR line contains that value; add evidence_missing.
    - Do not guess text, prices, currencies, selection limits, declaration
      meanings, dietary claims, or relationships. Use unknown/null and add a
      review reason whenever the page does not prove them.
    - A fixed price uses amount_cents; a surcharge/discount uses delta_cents; a
      from price uses minimum_amount_cents; a range uses both minimum and
      maximum. Do not copy a neighboring price.
    - Keep absolute variant/portion prices as fixed. Keep explicit surcharges as
      delta. Included choices use included and no numeric amount.
    - Set applies_to_quantity_order to the zero-based quantity index whenever an
      offer belongs to a specific quantity. For a choice or component with its
      single quantity, use 0. Leave it null only when no quantity relationship
      is visible.
    - Keep translations as TEXT.alternatives on the same entity. Never emit a
      translation as a second item and never delete either language.
    - Keep a set or course menu as one bundle entry. Put fixed courses and
      exactly-one course choices in bundle_components. Never copy the bundle
      price onto a component.
    - A cover, logo, slogan, heading, color, font, or watermark is not a menu
      item. A cover page returns page_kind cover and empty sections.
      A page classified as menu or mixed must not return zero menu entries.
    - A declaration code has no canonical meaning unless a visible legend on
      this page proves it. Preserve raw codes with canonical_id null otherwise.
    - An entry name never ends in a declaration code run. Move every trailing
      code group into declarations, whether or not it is bracketed and whether it
      is one letter or several: "Bunter Marktsalat [V]", "Bunter Marktsalat V"
      and "Veganes Kokoscurry [F,I]" all have the name "Bunter Marktsalat" or
      "Veganes Kokoscurry" plus declarations. Keep the code run verbatim in
      declaration.raw_text. A quantity or size that is part of the dish name
      ("Pizza 30cm", "0,5 l") is not a code run and stays in the name.
    - Set currency_code on every offer whose price text shows a currency:
      "€" or "EUR" is "EUR". Leave it null only when the page prints a bare
      number with no currency anywhere.
    - Return all array fields, using [] when empty. Return the zero-based
      page_index supplied by the user and contract_version 1.0.0 exactly.
      Every order value is zero-based, unique among siblings, and follows the
      visible reading order.
    """

    static var fingerprint: String {
        let digest = SHA256.hash(data: Data(systemPrompt.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Extraction -> canonical draft

struct MenuImportDraftAssembler {
    func assemble(
        sourceDocument: MenuImportSourceDocument,
        pageExtractions: [MenuImportPageExtraction],
        ocrLines: [MenuImportOCRLine],
        processing: MenuImportProcessingMetadata
    ) -> MenuImportDraft {
        var context = AssemblyContext(
            sourceID: sourceDocument.id,
            evidenceIndex: MenuImportEvidenceLineIndex(lines: ocrLines)
        )
        var sections: [MenuImportSection] = []
        var declarations: [MenuImportDeclaration] = []

        let orderedPages = pageExtractions.sorted { $0.pageIndex < $1.pageIndex }
        context.collectLegendCodes(from: orderedPages)
        var seenPages: Set<Int> = []
        for page in orderedPages {
            let pagePath = "pages[\(page.pageIndex)]"
            if !seenPages.insert(page.pageIndex).inserted {
                context.addFinding(
                    code: "duplicate_page_extraction",
                    path: pagePath,
                    message: "The provider returned this page more than once.",
                    severity: .error,
                    pageIndex: page.pageIndex
                )
                continue
            }
            if page.contractVersion != MenuImportPageExtraction.currentContractVersion {
                context.addFinding(
                    code: "contract_version_mismatch",
                    path: "\(pagePath).contractVersion",
                    message: "The provider response used contract \(page.contractVersion) instead of \(MenuImportPageExtraction.currentContractVersion).",
                    severity: .error,
                    pageIndex: page.pageIndex
                )
            }

            context.appendReviewReasons(
                page.reviewReasons,
                pageIndex: page.pageIndex,
                basePath: pagePath
            )

            for declarationIndex in page.declarations.indices {
                declarations.append(
                    context.makeDeclaration(
                        page.declarations[declarationIndex],
                        id: "extraction-\(sourceDocument.id)-p\(page.pageIndex)-declaration-\(declarationIndex)",
                        pageIndex: page.pageIndex,
                        path: "\(pagePath).declarations[\(declarationIndex)]"
                    )
                )
            }

            let sectionIndices = context.orderedIndices(
                page.sections.map(\.order),
                path: "\(pagePath).sections",
                pageIndex: page.pageIndex
            )
            for sectionIndex in sectionIndices {
                sections.append(
                    context.makeSection(
                        page.sections[sectionIndex],
                        idPrefix: "extraction-\(sourceDocument.id)-p\(page.pageIndex)-section-\(sectionIndex)",
                        outputOrder: sections.count,
                        pageIndex: page.pageIndex,
                        path: "\(pagePath).sections[\(sectionIndex)]"
                    )
                )
            }
        }

        var enrichedSourceDocument = sourceDocument
        if var sourcePages = enrichedSourceDocument.pages {
            var extractionByPage: [Int: MenuImportPageExtraction] = [:]
            for extraction in orderedPages where extractionByPage[extraction.pageIndex] == nil {
                extractionByPage[extraction.pageIndex] = extraction
            }
            for sourcePageIndex in sourcePages.indices {
                guard let extraction = extractionByPage[sourcePages[sourcePageIndex].pageIndex]
                else { continue }
                let kind = extraction.pageKind.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                sourcePages[sourcePageIndex].pageKind = kind.isEmpty ? "unknown" : kind
                sourcePages[sourcePageIndex].languages = extraction.languages.filter {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            enrichedSourceDocument.pages = sourcePages
        }

        let returnedPages = Set(orderedPages.map(\.pageIndex))
        for missingPage in 0..<sourceDocument.pageCount where !returnedPages.contains(missingPage) {
            context.addFinding(
                code: "missing_page_extraction",
                path: "pages[\(missingPage)]",
                message: "No semantic extraction was returned for this source page.",
                severity: .error,
                pageIndex: missingPage
            )
        }

        return MenuImportDraft(
            id: "draft-\(sourceDocument.id)",
            sourceDocument: enrichedSourceDocument,
            sections: sections,
            declarations: declarations,
            reviewState: .needsReview,
            processing: processing,
            reviewFindings: context.findings
        )
    }
}

private struct AssemblyContext {
    let sourceID: String
    let evidenceIndex: MenuImportEvidenceLineIndex
    var findings: [MenuImportReviewFinding] = []

    /// Every declaration code the document's own legend defines, normalized.
    ///
    /// Collected across *all* pages before any entry is converted, because a
    /// card's legend usually sits on its own page — often after the entries
    /// that reference it. This is the only evidence that lets
    /// `normalizeTrailingDeclarationCodes` split a run of letters without
    /// guessing: `[FI]` is two codes on a card whose legend defines `F` and
    /// `I`, while `[XL]` on the same card is a size and must stay in the name.
    var legendCodes: Set<String> = []

    mutating func orderedIndices(
        _ orders: [Int],
        path: String,
        pageIndex: Int
    ) -> [Int] {
        if orders.contains(where: { $0 < 0 }) || Set(orders).count != orders.count {
            addFinding(
                code: "invalid_visible_order",
                path: path,
                message: "Visible order values must be unique and nonnegative; array order was used as the stable tie-breaker.",
                severity: .warning,
                pageIndex: pageIndex
            )
        }
        return orders.indices.sorted {
            if orders[$0] != orders[$1] {
                return orders[$0] < orders[$1]
            }
            return $0 < $1
        }
    }

    mutating func makeSection(
        _ source: MenuImportExtractedSection,
        idPrefix: String,
        outputOrder: Int,
        pageIndex: Int,
        path: String
    ) -> MenuImportSection {
        appendReviewReasons(source.reviewReasons, pageIndex: pageIndex, basePath: path)

        var entries: [MenuImportEntry] = []
        let entryIndices = orderedIndices(
            source.entries.map(\.order),
            path: "\(path).entries",
            pageIndex: pageIndex
        )
        for (outputOrder, entryIndex) in entryIndices.enumerated() {
            entries.append(
                makeEntry(
                    source.entries[entryIndex],
                    idPrefix: "\(idPrefix)-entry-\(entryIndex)",
                    outputOrder: outputOrder,
                    pageIndex: pageIndex,
                    path: "\(path).entries[\(entryIndex)]"
                )
            )
        }

        var subsections: [MenuImportSection] = []
        let subsectionIndices = orderedIndices(
            source.subsections.map(\.order),
            path: "\(path).subsections",
            pageIndex: pageIndex
        )
        for (outputOrder, subsectionIndex) in subsectionIndices.enumerated() {
            subsections.append(
                makeSection(
                    source.subsections[subsectionIndex],
                    idPrefix: "\(idPrefix)-subsection-\(subsectionIndex)",
                    outputOrder: outputOrder,
                    pageIndex: pageIndex,
                    path: "\(path).subsections[\(subsectionIndex)]"
                )
            )
        }

        var declarations: [MenuImportDeclaration] = []
        for declarationIndex in source.declarations.indices {
            declarations.append(
                makeDeclaration(
                    source.declarations[declarationIndex],
                    id: "\(idPrefix)-declaration-\(declarationIndex)",
                    pageIndex: pageIndex,
                    path: "\(path).declarations[\(declarationIndex)]"
                )
            )
        }

        return MenuImportSection(
            id: idPrefix,
            title: makeText(source.title, pageIndex: pageIndex, path: "\(path).title"),
            order: outputOrder,
            entries: entries,
            subsections: subsections,
            declarations: declarations,
            reviewState: .needsReview
        )
    }

    mutating func makeEntry(
        _ source: MenuImportExtractedEntry,
        idPrefix: String,
        outputOrder: Int,
        pageIndex: Int,
        path: String
    ) -> MenuImportEntry {
        appendReviewReasons(source.reviewReasons, pageIndex: pageIndex, basePath: path)
        let normalizedIdentity = normalizeTrailingDeclarationCodes(
            name: source.name,
            declarations: source.declarations,
            pageIndex: pageIndex,
            path: path
        )

        var quantities: [MenuImportQuantity] = []
        for quantityIndex in source.quantities.indices {
            quantities.append(
                makeQuantity(
                    source.quantities[quantityIndex],
                    id: "\(idPrefix)-quantity-\(quantityIndex)",
                    pageIndex: pageIndex,
                    path: "\(path).quantities[\(quantityIndex)]"
                )
            )
        }

        var offers: [MenuImportOffer] = []
        for offerIndex in source.offers.indices {
            offers.append(
                makeOffer(
                    source.offers[offerIndex],
                    id: "\(idPrefix)-offer-\(offerIndex)",
                    quantityIDs: quantities.map(\.id),
                    pageIndex: pageIndex,
                    path: "\(path).offers[\(offerIndex)]"
                )
            )
        }

        var optionGroups: [MenuImportOptionGroup] = []
        let groupIndices = orderedIndices(
            source.optionGroups.map(\.order),
            path: "\(path).optionGroups",
            pageIndex: pageIndex
        )
        for (outputOrder, groupIndex) in groupIndices.enumerated() {
            optionGroups.append(
                makeOptionGroup(
                    source.optionGroups[groupIndex],
                    idPrefix: "\(idPrefix)-group-\(groupIndex)",
                    outputOrder: outputOrder,
                    pageIndex: pageIndex,
                    path: "\(path).optionGroups[\(groupIndex)]"
                )
            )
        }

        var bundleComponents: [MenuImportBundleComponent] = []
        let componentIndices = orderedIndices(
            source.bundleComponents.map(\.order),
            path: "\(path).bundleComponents",
            pageIndex: pageIndex
        )
        for (outputOrder, componentIndex) in componentIndices.enumerated() {
            bundleComponents.append(
                makeBundleComponent(
                    source.bundleComponents[componentIndex],
                    idPrefix: "\(idPrefix)-component-\(componentIndex)",
                    outputOrder: outputOrder,
                    pageIndex: pageIndex,
                    path: "\(path).bundleComponents[\(componentIndex)]"
                )
            )
        }

        var declarations: [MenuImportDeclaration] = []
        for declarationIndex in normalizedIdentity.declarations.indices {
            declarations.append(
                makeDeclaration(
                    normalizedIdentity.declarations[declarationIndex],
                    id: "\(idPrefix)-declaration-\(declarationIndex)",
                    pageIndex: pageIndex,
                    path: "\(path).declarations[\(declarationIndex)]"
                )
            )
        }

        if offers.isEmpty {
            addFinding(
                code: "missing_visible_price",
                path: "\(path).offers",
                message: "No visible price was attached to this entry; it remains in the draft for review.",
                severity: .warning,
                pageIndex: pageIndex,
                evidence: makeEvidence(
                    lineIDs: normalizedIdentity.name.evidenceLineIds,
                    fallbackText: normalizedIdentity.name.value,
                    pageIndex: pageIndex,
                    path: "\(path).name"
                )
            )
        }

        return MenuImportEntry(
            id: idPrefix,
            kind: nonblank(source.kind),
            name: makeText(
                normalizedIdentity.name,
                pageIndex: pageIndex,
                path: "\(path).name"
            ),
            description: source.description.map {
                makeText($0, pageIndex: pageIndex, path: "\(path).description")
            },
            itemNumber: source.itemNumber,
            order: outputOrder,
            offers: offers,
            quantities: quantities,
            optionGroups: optionGroups,
            bundleComponents: bundleComponents,
            declarations: declarations,
            reviewState: .needsReview
        )
    }

    /// A compact trailing group such as `[A,G,2]` is source metadata, not part
    /// of the purchasable name. Providers do not always duplicate those codes
    /// into `declarations`, so normalize the unambiguous syntax here while
    /// retaining the exact raw group and source evidence losslessly.
    /// Gathers the document's own legend codes from every page's declarations.
    mutating func collectLegendCodes(from pages: [MenuImportPageExtraction]) {
        for page in pages {
            for declaration in page.declarations {
                guard let code = declaration.localCode else { continue }
                let token = normalizedToken(code)
                guard !token.isEmpty else { continue }
                legendCodes.insert(token)
            }
        }
    }

    /// Splits a trailing declaration-code group off an entry name.
    ///
    /// Three shapes are recognized, in descending order of evidence:
    ///
    /// 1. A bracketed group whose parts are each a single character
    ///    (`Salat [F,I]`). Accepted without a legend, because the separators
    ///    themselves show that these are codes and not a word.
    /// 2. A bracketed group written as one unseparated run (`Curry [FI]`).
    ///    Only split when the legend defines *every* letter — otherwise `[XL]`
    ///    would silently become the two codes `X` and `L`.
    /// 3. An unbracketed uppercase run (`Bunter Marktsalat WI`). The weakest
    ///    shape, so it carries the strictest guard: a legend must define every
    ///    letter, the run must be short, and a name must remain.
    ///
    /// Shapes 2 and 3 return `nil` when the document printed no legend. Leaving
    /// the run in the name is visibly wrong but recoverable in review;
    /// inventing declarations from a size or a vintage is neither.
    func splitTrailingCodeGroup(
        in trimmedName: String
    ) -> (visibleName: String, codes: [String], rawGroup: String)? {
        let isSingleAlphanumeric = { (code: String) in
            code.unicodeScalars.count == 1
                && code.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        }

        if trimmedName.last == "]", let openingBracket = trimmedName.lastIndex(of: "[") {
            let rawGroup = String(trimmedName[openingBracket...])
            let inner = String(
                trimmedName[
                    trimmedName.index(after: openingBracket)..<trimmedName.index(before: trimmedName.endIndex)
                ]
            )
            let visibleName = trimmedName[..<openingBracket]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !visibleName.isEmpty else { return nil }

            let parts = inner
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if !parts.isEmpty, parts.allSatisfy(isSingleAlphanumeric) {
                return (visibleName, parts, rawGroup)
            }

            if parts.count == 1, let letters = legendBackedLetters(in: parts[0]) {
                return (visibleName, letters, rawGroup)
            }
            return nil
        }

        guard let separator = trimmedName.lastIndex(of: " ") else { return nil }
        let run = String(trimmedName[trimmedName.index(after: separator)...])
        let visibleName = trimmedName[..<separator]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !visibleName.isEmpty,
              run == run.uppercased(),
              run.count <= 4,
              let letters = legendBackedLetters(in: run)
        else {
            return nil
        }
        return (visibleName, letters, run)
    }

    /// Returns the individual characters of `run` when the document's legend
    /// defines every one of them, and `nil` otherwise (including when no
    /// legend was found at all).
    private func legendBackedLetters(in run: String) -> [String]? {
        guard !legendCodes.isEmpty, run.count >= 2 else { return nil }
        guard run.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains) else {
            return nil
        }
        let letters = run.map(String.init)
        guard letters.allSatisfy({ legendCodes.contains(normalizedToken($0)) }) else {
            return nil
        }
        return letters
    }

    mutating func normalizeTrailingDeclarationCodes(
        name: MenuImportExtractedText,
        declarations: [MenuImportExtractedDeclaration],
        pageIndex: Int,
        path: String
    ) -> (
        name: MenuImportExtractedText,
        declarations: [MenuImportExtractedDeclaration]
    ) {
        let trimmedName = name.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let split = splitTrailingCodeGroup(in: trimmedName) else {
            return (name, declarations)
        }
        let (visibleName, codes, rawGroup) = split

        var normalizedName = name
        normalizedName.value = visibleName
        var normalizedDeclarations = declarations
        var existingCodes = Set(
            declarations.compactMap(\.localCode).map(normalizedToken)
        )
        for code in codes where !existingCodes.contains(normalizedToken(code)) {
            existingCodes.insert(normalizedToken(code))
            normalizedDeclarations.append(
                MenuImportExtractedDeclaration(
                    kind: "source_declaration",
                    rawText: rawGroup,
                    alternatives: [],
                    localCode: code,
                    canonicalId: nil,
                    claim: "unknown",
                    scope: "entry",
                    evidenceLineIds: name.evidenceLineIds
                )
            )
        }
        addFinding(
            code: "normalized_trailing_declaration_codes",
            path: "\(path).name",
            message: "A compact trailing declaration-code group was moved out of the item name and retained as source declarations.",
            severity: .info,
            pageIndex: pageIndex,
            evidence: makeEvidence(
                lineIDs: name.evidenceLineIds,
                fallbackText: name.value,
                pageIndex: pageIndex,
                path: "\(path).name"
            )
        )
        return (normalizedName, normalizedDeclarations)
    }

    mutating func makeOptionGroup(
        _ source: MenuImportExtractedOptionGroup,
        idPrefix: String,
        outputOrder: Int,
        pageIndex: Int,
        path: String
    ) -> MenuImportOptionGroup {
        appendReviewReasons(source.reviewReasons, pageIndex: pageIndex, basePath: path)

        var choices: [MenuImportChoice] = []
        let choiceIndices = orderedIndices(
            source.choices.map(\.order),
            path: "\(path).choices",
            pageIndex: pageIndex
        )
        for (outputOrder, choiceIndex) in choiceIndices.enumerated() {
            let choice = source.choices[choiceIndex]
            let choicePath = "\(path).choices[\(choiceIndex)]"
            appendReviewReasons(choice.reviewReasons, pageIndex: pageIndex, basePath: choicePath)

            let quantity = choice.quantity.map {
                makeQuantity(
                    $0,
                    id: "\(idPrefix)-choice-\(choiceIndex)-quantity",
                    pageIndex: pageIndex,
                    path: "\(choicePath).quantity"
                )
            }
            var offers: [MenuImportOffer] = []
            for offerIndex in choice.offers.indices {
                offers.append(
                    makeOffer(
                        choice.offers[offerIndex],
                        id: "\(idPrefix)-choice-\(choiceIndex)-offer-\(offerIndex)",
                        quantityIDs: quantity.map { [$0.id] } ?? [],
                        pageIndex: pageIndex,
                        path: "\(choicePath).offers[\(offerIndex)]"
                    )
                )
            }
            var declarations: [MenuImportDeclaration] = []
            for declarationIndex in choice.declarations.indices {
                declarations.append(
                    makeDeclaration(
                        choice.declarations[declarationIndex],
                        id: "\(idPrefix)-choice-\(choiceIndex)-declaration-\(declarationIndex)",
                        pageIndex: pageIndex,
                        path: "\(choicePath).declarations[\(declarationIndex)]"
                    )
                )
            }
            choices.append(
                MenuImportChoice(
                    id: "\(idPrefix)-choice-\(choiceIndex)",
                    name: makeText(
                        choice.name,
                        pageIndex: pageIndex,
                        path: "\(choicePath).name"
                    ),
                    description: choice.description.map {
                        makeText(
                            $0,
                            pageIndex: pageIndex,
                            path: "\(choicePath).description"
                        )
                    },
                    kind: nonblank(choice.kind),
                    order: outputOrder,
                    offers: offers,
                    quantity: quantity,
                    declarations: declarations,
                    reviewState: .needsReview
                )
            )
        }

        return MenuImportOptionGroup(
            id: idPrefix,
            title: makeText(source.title, pageIndex: pageIndex, path: "\(path).title"),
            order: outputOrder,
            selectionRule: makeSelectionRule(source.selectionRule, pageIndex: pageIndex, path: path),
            choices: choices,
            reviewState: .needsReview
        )
    }

    mutating func makeBundleComponent(
        _ source: MenuImportExtractedBundleComponent,
        idPrefix: String,
        outputOrder: Int,
        pageIndex: Int,
        path: String
    ) -> MenuImportBundleComponent {
        appendReviewReasons(source.reviewReasons, pageIndex: pageIndex, basePath: path)

        let quantity = source.quantity.map {
            makeQuantity(
                $0,
                id: "\(idPrefix)-quantity",
                pageIndex: pageIndex,
                path: "\(path).quantity"
            )
        }
        var offers: [MenuImportOffer] = []
        for offerIndex in source.offers.indices {
            offers.append(
                makeOffer(
                    source.offers[offerIndex],
                    id: "\(idPrefix)-offer-\(offerIndex)",
                    quantityIDs: quantity.map { [$0.id] } ?? [],
                    pageIndex: pageIndex,
                    path: "\(path).offers[\(offerIndex)]"
                )
            )
        }
        var declarations: [MenuImportDeclaration] = []
        for declarationIndex in source.declarations.indices {
            declarations.append(
                makeDeclaration(
                    source.declarations[declarationIndex],
                    id: "\(idPrefix)-declaration-\(declarationIndex)",
                    pageIndex: pageIndex,
                    path: "\(path).declarations[\(declarationIndex)]"
                )
            )
        }

        return MenuImportBundleComponent(
            id: idPrefix,
            title: makeText(source.title, pageIndex: pageIndex, path: "\(path).title"),
            description: source.description.map {
                makeText($0, pageIndex: pageIndex, path: "\(path).description")
            },
            kind: nonblank(source.kind),
            order: outputOrder,
            quantity: quantity,
            optionGroup: source.optionGroup.map {
                makeOptionGroup(
                    $0,
                    idPrefix: "\(idPrefix)-group",
                    outputOrder: 0,
                    pageIndex: pageIndex,
                    path: "\(path).optionGroup"
                )
            },
            offers: offers,
            declarations: declarations,
            reviewState: .needsReview
        )
    }

    mutating func makeText(
        _ source: MenuImportExtractedText,
        pageIndex: Int,
        path: String
    ) -> MenuImportText {
        var alternatives: [MenuImportLocalizedText] = []
        for alternativeIndex in source.alternatives.indices {
            let alternative = source.alternatives[alternativeIndex]
            alternatives.append(
                MenuImportLocalizedText(
                    value: alternative.value,
                    languageTag: alternative.languageTag,
                    evidence: makeEvidence(
                        lineIDs: alternative.evidenceLineIds,
                        fallbackText: alternative.value,
                        pageIndex: pageIndex,
                        path: "\(path).alternatives[\(alternativeIndex)]"
                    )
                )
            )
        }

        return MenuImportText(
            value: source.value,
            languageTag: source.languageTag,
            evidence: makeEvidence(
                lineIDs: source.evidenceLineIds,
                fallbackText: source.value,
                pageIndex: pageIndex,
                path: path
            ),
            alternatives: alternatives
        )
    }

    mutating func makeQuantity(
        _ source: MenuImportExtractedQuantity,
        id: String,
        pageIndex: Int,
        path: String
    ) -> MenuImportQuantity {
        var normalizedValue = source.value
        if let value = source.value, !value.isFinite || value < 0 {
            normalizedValue = nil
            addFinding(
                code: "invalid_quantity",
                path: "\(path).value",
                message: "The provider returned an invalid normalized quantity; the visible raw quantity was retained.",
                severity: .warning,
                pageIndex: pageIndex
            )
        }
        return MenuImportQuantity(
            id: id,
            rawText: source.rawText,
            value: normalizedValue,
            unit: nonblank(source.unit),
            kind: nonblank(source.kind),
            evidence: makeEvidence(
                lineIDs: source.evidenceLineIds,
                fallbackText: source.rawText,
                pageIndex: pageIndex,
                path: path
            )
        )
    }

    mutating func makeOffer(
        _ source: MenuImportExtractedOffer,
        id: String,
        quantityIDs: [String],
        pageIndex: Int,
        path: String
    ) -> MenuImportOffer {
        let mappedKind = priceKind(source.priceKind)
        var outputKind = mappedKind
        var amount = source.amountCents
        var delta = source.deltaCents
        var minimum = source.minimumAmountCents
        var maximum = source.maximumAmountCents

        let absoluteValues = [amount, minimum, maximum].compactMap { $0 }
        let fieldsAreValid: Bool
        switch mappedKind {
        case .fixed:
            fieldsAreValid = amount != nil && delta == nil && minimum == nil && maximum == nil
        case .from:
            fieldsAreValid = amount == nil && delta == nil && minimum != nil && maximum == nil
        case .range:
            fieldsAreValid = amount == nil && delta == nil && minimum != nil
                && maximum != nil && minimum! <= maximum!
        case .market, .onRequest, .included, .unknown:
            fieldsAreValid = amount == nil && delta == nil && minimum == nil && maximum == nil
        case .free:
            fieldsAreValid = amount == 0 && delta == nil && minimum == nil && maximum == nil
        case .delta:
            fieldsAreValid = amount == nil && delta != nil && minimum == nil && maximum == nil
        }

        if absoluteValues.contains(where: { $0 < 0 }) || !fieldsAreValid {
            outputKind = .unknown
            amount = nil
            delta = nil
            minimum = nil
            maximum = nil
            addFinding(
                code: "invalid_price_fields",
                path: path,
                message: "The provider's numeric price fields contradicted price_kind; the visible price was retained as unknown.",
                severity: .error,
                pageIndex: pageIndex
            )
        } else if mappedKind == .unknown
                    && normalizedToken(source.priceKind) != MenuImportPriceKind.unknown.rawValue {
            addFinding(
                code: "unknown_price_kind",
                path: "\(path).priceKind",
                message: "The provider returned an unsupported price kind '\(source.priceKind)'.",
                severity: .warning,
                pageIndex: pageIndex
            )
        }

        var appliesToQuantityID: String?
        if let quantityOrder = source.appliesToQuantityOrder {
            if quantityIDs.indices.contains(quantityOrder) {
                appliesToQuantityID = quantityIDs[quantityOrder]
            } else {
                addFinding(
                    code: "invalid_quantity_reference",
                    path: "\(path).appliesToQuantityOrder",
                    message: "The price referenced a quantity that does not exist on this entity.",
                    severity: .warning,
                    pageIndex: pageIndex
                )
            }
        }

        let trimmedRawPrice = source.rawPrice?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPrice = trimmedRawPrice?.isEmpty == false ? trimmedRawPrice : nil
        let evidenceFallback = rawPrice
            ?? source.label?.value.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        return MenuImportOffer(
            id: id,
            label: source.label.map {
                makeText($0, pageIndex: pageIndex, path: "\(path).label")
            },
            priceKind: outputKind,
            amountCents: amount,
            deltaCents: delta,
            minimumAmountCents: minimum,
            maximumAmountCents: maximum,
            currencyCode: source.currencyCode,
            rawPrice: rawPrice,
            basis: nonblank(source.basis),
            appliesToQuantityID: appliesToQuantityID,
            evidence: makeEvidence(
                lineIDs: source.evidenceLineIds,
                fallbackText: evidenceFallback,
                pageIndex: pageIndex,
                path: path
            )
        )
    }

    mutating func makeSelectionRule(
        _ source: MenuImportExtractedSelectionRule,
        pageIndex: Int,
        path: String
    ) -> MenuImportSelectionRule {
        let values = [source.minimum, source.maximum, source.freeSelectionCount]
            .compactMap { $0 }
        let isValid = !values.contains(where: { $0 < 0 })
            && (source.minimum == nil || source.maximum == nil || source.minimum! <= source.maximum!)
            && (source.freeSelectionCount == nil
                || source.maximum == nil
                || source.freeSelectionCount! <= source.maximum!)
        guard isValid else {
            addFinding(
                code: "invalid_selection_rule",
                path: "\(path).selectionRule",
                message: "The provider returned a contradictory selection rule; it was reset to unknown.",
                severity: .error,
                pageIndex: pageIndex
            )
            return MenuImportSelectionRule(mode: "unknown")
        }
        return MenuImportSelectionRule(
            minimum: source.minimum,
            maximum: source.maximum,
            freeSelectionCount: source.freeSelectionCount,
            mode: nonblank(source.mode),
            allowsRepeats: source.allowsRepeats
        )
    }

    mutating func makeDeclaration(
        _ source: MenuImportExtractedDeclaration,
        id: String,
        pageIndex: Int,
        path: String
    ) -> MenuImportDeclaration {
        var alternatives: [MenuImportLocalizedText] = []
        for (alternativeIndex, alternative) in
            (source.alternatives ?? []).enumerated()
        {
            alternatives.append(
                MenuImportLocalizedText(
                    value: alternative.value,
                    languageTag: alternative.languageTag,
                    evidence: makeEvidence(
                        lineIDs: alternative.evidenceLineIds,
                        fallbackText: alternative.value,
                        pageIndex: pageIndex,
                        path: "\(path).alternatives[\(alternativeIndex)]"
                    )
                )
            )
        }
        let fallbackRawText = [
            source.rawText,
            source.localCode,
            source.claim
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? "unlocated declaration"

        return MenuImportDeclaration(
            id: id,
            kind: nonblank(source.kind),
            rawText: fallbackRawText,
            alternatives: alternatives,
            localCode: source.localCode,
            canonicalID: source.canonicalId,
            claim: nonblank(source.claim),
            scope: nonblank(source.scope),
            evidence: makeEvidence(
                lineIDs: source.evidenceLineIds,
                fallbackText: fallbackRawText,
                pageIndex: pageIndex,
                path: path
            )
        )
    }

    mutating func appendReviewReasons(
        _ reasons: [MenuImportExtractedReviewReason],
        pageIndex: Int,
        basePath: String
    ) {
        for (reasonIndex, reason) in reasons.enumerated() {
            let reasonPath = reason.path.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedPath = reasonPath.isEmpty
                ? "\(basePath).reviewReasons[\(reasonIndex)]"
                : "\(basePath).\(reasonPath)"
            let evidence = reason.evidenceLineIds.isEmpty
                ? nil
                : makeEvidence(
                    lineIDs: reason.evidenceLineIds,
                    fallbackText: reason.message,
                    pageIndex: pageIndex,
                    path: resolvedPath
                )
            addFinding(
                code: nonblank(reason.code),
                path: resolvedPath,
                message: reason.message.isEmpty ? "Provider requested review." : reason.message,
                severity: findingSeverity(reason.severity),
                pageIndex: pageIndex,
                evidence: evidence
            )
        }
    }

    mutating func makeEvidence(
        lineIDs: [String],
        fallbackText: String,
        pageIndex: Int,
        path: String
    ) -> MenuImportEvidence {
        let uniqueIDs = lineIDs.reduce(into: [String]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        let resolved = uniqueIDs.compactMap { id -> MenuImportOCRLine? in
            guard let line = evidenceIndex.line(for: id) else {
                addFinding(
                    code: "unknown_evidence_line",
                    path: path,
                    message: "The provider cited OCR line '\(id)', which was not supplied.",
                    severity: .warning,
                    pageIndex: pageIndex
                )
                return nil
            }
            guard line.pageIndex == pageIndex else {
                addFinding(
                    code: "cross_page_evidence",
                    path: path,
                    message: "The provider cited line '\(id)' from a different page.",
                    severity: .warning,
                    pageIndex: pageIndex
                )
                return nil
            }
            return line
        }

        if let first = resolved.first {
            let minX = resolved.map(\.minX).min() ?? first.minX
            let minY = resolved.map(\.minY).min() ?? first.minY
            let maxX = resolved.map { $0.minX + $0.width }.max() ?? (first.minX + first.width)
            let maxY = resolved.map { $0.minY + $0.height }.max() ?? (first.minY + first.height)
            return MenuImportEvidence(
                rawText: resolved.map(\.text).joined(separator: "\n"),
                pageIndex: pageIndex,
                boundingBox: MenuImportNormalizedBoundingBox(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                ),
                method: .model,
                methodDetail: "semantic-extraction over OCR lines \(uniqueIDs.joined(separator: ","))",
                confidence: resolved.map(\.confidence).min() ?? first.confidence,
                reviewState: .needsReview,
                isLocated: true
            )
        }

        addFinding(
            code: "evidence_missing",
            path: path,
            message: "No supplied OCR line locates this extracted value.",
            severity: .warning,
            pageIndex: pageIndex
        )
        if let relatedLine = evidenceIndex.firstLine(on: pageIndex) {
            return MenuImportEvidence(
                rawText: nonblankEvidenceText(fallbackText),
                pageIndex: pageIndex,
                boundingBox: MenuImportNormalizedBoundingBox(
                    x: relatedLine.minX,
                    y: relatedLine.minY,
                    width: relatedLine.width,
                    height: relatedLine.height
                ),
                method: .model,
                methodDetail: "semantic-extraction without cited OCR line",
                confidence: 0,
                reviewState: .needsReview,
                isLocated: false
            )
        }
        return MenuImportEvidence(
            rawText: nonblankEvidenceText(fallbackText),
            pageIndex: max(pageIndex, 0),
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0,
                y: 0,
                width: 0.000_001,
                height: 0.000_001
            ),
            method: .model,
            methodDetail: "semantic-extraction without OCR evidence",
            confidence: 0,
            reviewState: .needsReview,
            isLocated: false
        )
    }

    mutating func addFinding(
        code: String,
        path: String,
        message: String,
        severity: MenuImportReviewFindingSeverity,
        pageIndex: Int?,
        evidence: MenuImportEvidence? = nil
    ) {
        findings.append(
            MenuImportReviewFinding(
                id: "finding-\(sourceID)-\(findings.count)",
                code: nonblank(code),
                path: nonblank(path),
                message: message.isEmpty ? "Review required." : message,
                severity: severity,
                pageIndex: pageIndex,
                evidence: evidence
            )
        )
    }

    private func priceKind(_ rawValue: String) -> MenuImportPriceKind {
        switch normalizedToken(rawValue) {
        case "fixed": return .fixed
        case "from": return .from
        case "range": return .range
        case "market": return .market
        case "onrequest": return .onRequest
        case "included": return .included
        case "free": return .free
        case "delta": return .delta
        default: return .unknown
        }
    }

    private func findingSeverity(_ rawValue: String) -> MenuImportReviewFindingSeverity {
        switch normalizedToken(rawValue) {
        case "error": return .error
        case "info": return .info
        default: return .warning
        }
    }

    private func nonblank(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    private func nonblankEvidenceText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unlocated value" : trimmed
    }

    private func normalizedToken(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
    }
}
