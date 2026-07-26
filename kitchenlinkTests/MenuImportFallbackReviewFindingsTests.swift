import Foundation
import Testing
@testable import kitchenlink

/// The ten-page quality gate measured the offline rule pipeline at
/// `expectedReviewRecall 0.000` while needing 8.5 corrections per page: it
/// produced wrong cards that looked finished, because it emitted no review
/// findings at all. The mandatory review is the only safety net before
/// publishing, so the fallback has to declare what it does not know.
///
/// These tests pin the findings the rules can honestly derive — and pin that the
/// semantic findings they cannot detect are NOT fabricated.
struct MenuImportFallbackReviewFindingsTests {

    private let adapter = MenuImportDraftAdapter()

    // MARK: - What the rules can honestly report

    @Test
    func anEntryWithoutAPriceIsReportedAsMissingVisiblePrice() throws {
        let candidateLine = line("Gemischter Eisbecher", x: 0.10, y: 0.60)
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [pricedItem()])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70),
                candidateLine
            ],
            unpricedCandidates: [
                MenuImportUnpricedCandidate(
                    sectionID: "legacy-section-dessert",
                    sectionTitle: "Dessert",
                    title: "Gemischter Eisbecher",
                    kind: MenuItemKind.food.rawValue,
                    description: nil,
                    allergenCodes: nil,
                    titleLine: candidateLine,
                    descriptionLines: []
                )
            ]
        )

        let findings = try #require(draft.reviewFindings)
        let priceFindings = findings.filter { $0.code == "missing_visible_price" }

        #expect(priceFindings.count == 1)
        #expect(priceFindings.first?.severity == .error)
        #expect(priceFindings.first?.message.contains("Gemischter Eisbecher") == true)
        // The finding must point at a page so the review can show the crop.
        #expect(priceFindings.first?.pageIndex == 0)
    }

    @Test
    func aPricedEntryProducesNoPriceFinding() throws {
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [pricedItem()])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)

        #expect(!findings.contains { $0.code == "missing_visible_price" })
    }

    @Test
    func aDeclarationCodeWithoutALegendIsFlaggedAsUnknownMeaning() throws {
        // The card prints `[X]` but no legend, so the rules read characters
        // without meaning. Guessing an allergen here would be the dangerous
        // failure; flagging it is the safe one.
        var item = pricedItem()
        item.allergenCodes = "x"
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [item])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark [X]", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)
        let declarationFindings = findings.filter {
            $0.code == "source_declaration_meaning_unknown"
        }

        #expect(declarationFindings.count == 1)
        #expect(declarationFindings.first?.severity == .error)
    }

    @Test
    func aDeclarationCoveredByTheCardsLegendIsNotFlagged() throws {
        var item = pricedItem()
        item.allergenCodes = "a"
        var section = menuSection(items: [item])
        section.allergenLegend = ["a": "Glutenhaltiges Getreide"]

        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [section],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark [A]", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)

        #expect(!findings.contains { $0.code == "source_declaration_meaning_unknown" })
    }

    @Test
    func optionsAlwaysCarryAnUnknownSelectionRule() throws {
        // The rules split a visible option list but never learn how many of them
        // a guest may pick, so the rule stays a human decision.
        var item = pricedItem()
        item.variants = [
            MenuItemVariant(id: "v-klein", name: "klein", priceCents: 1_490, kind: .portion),
            MenuItemVariant(id: "v-gross", name: "groß", priceCents: 2_090, kind: .portion)
        ]

        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [item])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70),
                line("klein 14,90 groß 20,90", x: 0.10, y: 0.64)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)
        let selectionFindings = findings.filter { $0.code == "selection_rule_unknown" }

        #expect(selectionFindings.count == 1)
    }

    @Test
    func everyRuleOnlyDraftDeclaresItsSemanticGapExactlyOnce() throws {
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [pricedItem(), pricedItem(id: "second")])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)
        let gap = findings.filter { $0.code == "rule_parser_semantics_unverified" }

        #expect(gap.count == 1)
        #expect(gap.first?.severity == .error)
        // Document-level, so it is not tied to one page.
        #expect(gap.first?.pageIndex == nil)
        #expect(gap.first?.message.contains("ohne KI") == true)
    }

    // MARK: - What must NOT be fabricated

    @Test
    func semanticFindingsTheRulesCannotDetectAreNotInvented() throws {
        // These are the gate's remaining expected codes. The rule parser has no
        // way to detect them, and a fabricated finding would be worse than an
        // honest gap: it would train the operator to ignore findings.
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [pricedItem()])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let findings = try #require(draft.reviewFindings)
        let codes = Set(findings.map(\.code))

        for fabricated in [
            "complex_bundle_choice",
            "chef_composed_bundle",
            "headline_price_unmapped_to_portion_choice",
            "relationship_scope_ambiguous"
        ] {
            #expect(!codes.contains(fabricated))
        }
    }

    @Test
    func derivedFindingsKeepTheDraftValid() throws {
        var item = pricedItem()
        item.allergenCodes = "x"
        item.variants = [
            MenuItemVariant(id: "v-klein", name: "klein", priceCents: 1_490, kind: .portion)
        ]

        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [item])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark [X]", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        #expect(draft.validate().isValid)
    }

    @Test
    func explicitlyPassedFindingsSurviveAlongsideTheDerivedOnes() throws {
        let provided = MenuImportReviewFinding(
            id: "provider-finding",
            code: "complex_bundle_choice",
            path: "sections[0]",
            message: "Vom Anbieter gemeldet.",
            severity: .warning
        )

        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [pricedItem()])],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: [],
            reviewFindings: [provided]
        )

        let findings = try #require(draft.reviewFindings)

        #expect(findings.contains { $0.id == "provider-finding" })
        #expect(findings.contains { $0.code == "rule_parser_semantics_unverified" })
    }

    // MARK: - Fixtures

    private func source() -> MenuImportSourceDocument {
        MenuImportSourceDocument(
            id: "source-fallback-findings",
            sourceType: .demoFixture,
            pageCount: 1,
            fingerprint: "sha256:fallback-findings"
        )
    }

    private func pricedItem(id: String = "legacy-priced") -> MenuItemData {
        MenuItemData(
            id: id,
            name: "Coup Daenemark",
            description: "Automatisch importiert",
            priceCents: 790,
            kind: .food
        )
    }

    private func menuSection(items: [MenuItemData]) -> MenuSectionData {
        MenuSectionData(
            id: "legacy-section-dessert",
            title: "Dessert",
            subtitle: "Importiert",
            kind: .food,
            items: items,
            importConfidence: 0.9
        )
    }

    private func line(_ text: String, x: Double, y: Double) -> MenuImportOCRLine {
        MenuImportOCRLine(
            text: text,
            pageIndex: 0,
            minX: x,
            minY: y,
            midY: y + 0.015,
            width: min(0.85 - x, 0.42),
            height: 0.03,
            method: .enhancedOCR,
            confidence: 0.94
        )
    }
}
