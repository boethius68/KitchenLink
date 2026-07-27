import XCTest
@testable import kitchenlink

final class MenuImportExtractionContractTests: XCTestCase {
    func testSnakeCaseProviderPayloadDecodesStrictContract() throws {
        let json = """
        {
          "contract_version": "1.0.0",
          "page_index": 0,
          "page_kind": "menu",
          "languages": ["de"],
          "sections": [],
          "declarations": [{
            "kind": "source_declaration",
            "raw_text": "A Gluten",
            "alternatives": [{
              "value": "A gluten",
              "language_tag": "en",
              "evidence_line_ids": ["p1-l2"]
            }],
            "local_code": "A",
            "canonical_id": null,
            "claim": "declared",
            "scope": "document",
            "evidence_line_ids": ["p1-l1"]
          }],
          "review_reasons": [{
            "code": "legend_visible",
            "path": "declarations",
            "message": "Legend retained.",
            "severity": "info",
            "evidence_line_ids": ["p1-l1"]
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let extraction = try decoder.decode(
            MenuImportPageExtraction.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(extraction.contractVersion, "1.0.0")
        XCTAssertEqual(extraction.declarations.first?.evidenceLineIds, ["p1-l1"])
        XCTAssertEqual(
            extraction.declarations.first?.alternatives?.first?.value,
            "A gluten"
        )
        XCTAssertEqual(
            extraction.declarations.first?.alternatives?.first?.evidenceLineIds,
            ["p1-l2"]
        )
        XCTAssertNil(extraction.declarations.first?.canonicalId)
        XCTAssertEqual(extraction.reviewReasons.first?.evidenceLineIds, ["p1-l1"])
    }

    func testAssemblerRetainsTranslatedNoticeWithExactEvidence() throws {
        let lines = [
            line("Bitte wählen Sie eine Beilage", page: 0, x: 0.1, y: 0.9),
            line("Please choose a side dish", page: 0, x: 0.1, y: 0.8)
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "information",
            languages: ["de", "en"],
            sections: [],
            declarations: [
                MenuImportExtractedDeclaration(
                    kind: "notice",
                    rawText: "Bitte wählen Sie eine Beilage",
                    alternatives: [
                        MenuImportExtractedLocalizedText(
                            value: "Please choose a side dish",
                            languageTag: "en",
                            evidenceLineIds: ["p1-l2"]
                        )
                    ],
                    localCode: nil,
                    canonicalId: nil,
                    claim: "unknown",
                    scope: "document",
                    evidenceLineIds: ["p1-l1"]
                )
            ],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let notice = try XCTUnwrap(draft.declarations.first)
        let translation = try XCTUnwrap(notice.alternatives?.first)

        XCTAssertEqual(notice.kind, "notice")
        XCTAssertEqual(notice.evidence.rawText, "Bitte wählen Sie eine Beilage")
        XCTAssertEqual(translation.value, "Please choose a side dish")
        XCTAssertEqual(translation.evidence.rawText, "Please choose a side dish")
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    func testPrePhaseOneDraftStillDecodesBeforeMigration() throws {
        let json = """
        {
          "schemaVersion": "0.2.0",
          "id": "legacy-draft",
          "sourceDocument": {
            "id": "legacy-source",
            "sourceType": "other",
            "pageCount": 1,
            "fingerprint": "legacy:fingerprint"
          },
          "sections": [],
          "declarations": [],
          "reviewState": "unreviewed"
        }
        """

        let draft = try JSONDecoder().decode(
            MenuImportDraft.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(draft.processing)
        XCTAssertNil(draft.reviewFindings)
        XCTAssertNil(draft.sourceDocument.pages)
        XCTAssertEqual(draft.schemaVersion, "0.2.0")
    }

    func testProcessingMetadataMustCoverEverySourcePage() {
        let twoPageSource = MenuImportSourceDocument(
            id: "two-page-source",
            sourceType: .other,
            pageCount: 2,
            fingerprint: "sha256:document"
        )
        let draft = MenuImportDraft(
            sourceDocument: twoPageSource,
            processing: MenuImportProcessingMetadata(
                pipelineVersion: "test",
                provider: "test",
                pageOutcomes: [
                    MenuImportPageOutcome(
                        pageIndex: 0,
                        status: .processed,
                        attempts: 1
                    )
                ]
            )
        )

        XCTAssertTrue(
            draft.validate().errors.contains { $0.code == .incompletePageOutcomes }
        )
    }

    func testMenuPageWithoutEntriesIsNotAValidEmptyResult() {
        let menuPage = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [],
            declarations: [],
            reviewReasons: []
        )
        let coverPage = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "cover",
            languages: [],
            sections: [],
            declarations: [],
            reviewReasons: []
        )

        XCTAssertEqual(menuPage.recursiveEntryCount, 0)
        XCTAssertFalse(menuPage.permitsEmptyMenuResult)
        XCTAssertTrue(coverPage.permitsEmptyMenuResult)
    }

    func testEvidenceLineIDsAreStablePerPageInVisualReadingOrder() {
        let lines = [
            line("right", page: 0, x: 0.7, y: 0.8),
            line("lower", page: 0, x: 0.1, y: 0.6),
            line("left", page: 0, x: 0.1, y: 0.8),
            line("page two", page: 1, x: 0.1, y: 0.9)
        ]

        let references = MenuImportEvidenceLineIndex(lines: lines).references

        XCTAssertEqual(references.map(\.id), ["p1-l1", "p1-l2", "p1-l3", "p2-l1"])
        XCTAssertEqual(references.map(\.line.text), ["left", "right", "lower", "page two"])
    }

    func testAssemblerRetainsUnpricedEntryAndTranslationWithExactEvidence() throws {
        let lines = [
            line("Dessert", page: 0, x: 0.1, y: 0.9),
            line("Gemischter Eisbecher", page: 0, x: 0.1, y: 0.8),
            line("Mixed ice cream", page: 0, x: 0.1, y: 0.7)
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de", "en"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Dessert", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: MenuImportExtractedText(
                                value: "Gemischter Eisbecher",
                                languageTag: "de",
                                evidenceLineIds: ["p1-l2"],
                                alternatives: [
                                    MenuImportExtractedLocalizedText(
                                        value: "Mixed ice cream",
                                        languageTag: "en",
                                        evidenceLineIds: ["p1-l3"]
                                    )
                                ]
                            ),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: [
                                MenuImportExtractedReviewReason(
                                    code: "missing_visible_price",
                                    path: "offers",
                                    message: "No price is visible.",
                                    severity: "warning",
                                    evidenceLineIds: ["p1-l2"]
                                )
                            ]
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )

        let entry = try XCTUnwrap(draft.sections.first?.entries.first)
        XCTAssertEqual(entry.name.value, "Gemischter Eisbecher")
        XCTAssertEqual(entry.offers, [])
        XCTAssertEqual(entry.name.alternatives?.first?.value, "Mixed ice cream")
        XCTAssertEqual(entry.name.evidence.rawText, "Gemischter Eisbecher")
        XCTAssertTrue(entry.name.evidence.isLocated)
        XCTAssertEqual(entry.name.evidence.confidence, 0.82)
        XCTAssertTrue(
            draft.reviewFindings?.contains { $0.code == "missing_visible_price" } == true
        )
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    func testAssemblerMovesCompactTrailingCodesOutOfEntryNameLosslessly() throws {
        let lines = [
            line("Pizza", page: 0, x: 0.1, y: 0.9),
            line("Pizza Prüfstand [A, G,2,6]", page: 0, x: 0.1, y: 0.8),
            line("Pizza Familie [XL]", page: 0, x: 0.1, y: 0.7)
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Pizza", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text(
                                "Pizza Prüfstand [A, G,2,6]",
                                language: "de",
                                evidence: ["p1-l2"]
                            ),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        ),
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text(
                                "Pizza Familie [XL]",
                                language: "de",
                                evidence: ["p1-l3"]
                            ),
                            description: nil,
                            itemNumber: nil,
                            order: 1,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let entries = try XCTUnwrap(draft.sections.first?.entries)

        XCTAssertEqual(entries[0].name.value, "Pizza Prüfstand")
        XCTAssertEqual(
            entries[0].declarations.compactMap(\.localCode),
            ["A", "G", "2", "6"]
        )
        XCTAssertTrue(
            entries[0].declarations.allSatisfy {
                $0.rawText == "[A, G,2,6]"
                    && $0.evidence.rawText == "Pizza Prüfstand [A, G,2,6]"
            }
        )
        XCTAssertEqual(entries[1].name.value, "Pizza Familie [XL]")
        XCTAssertEqual(entries[1].declarations, [])
        XCTAssertTrue(
            draft.reviewFindings?.contains {
                $0.code == "normalized_trailing_declaration_codes"
            } == true
        )
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    func testAssemblerMarksUnknownEvidenceUnlocatedWithoutInventedConfidence() throws {
        let lines = [line("Vorspeisen", page: 0, x: 0.1, y: 0.9)]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Vorspeisen", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text(
                                "Nicht lokalisierter Artikel",
                                language: "de",
                                evidence: ["p1-l999"]
                            ),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [
                                MenuImportExtractedOffer(
                                    label: nil,
                                    priceKind: "range",
                                    amountCents: nil,
                                    deltaCents: nil,
                                    minimumAmountCents: 900,
                                    maximumAmountCents: 1200,
                                    currencyCode: "EUR",
                                    rawPrice: "9–12 €",
                                    basis: "per_item",
                                    appliesToQuantityOrder: nil,
                                    evidenceLineIds: []
                                )
                            ],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let entry = try XCTUnwrap(draft.sections.first?.entries.first)
        let offer = try XCTUnwrap(entry.offers.first)

        XCTAssertFalse(entry.name.evidence.isLocated)
        XCTAssertEqual(entry.name.evidence.confidence, 0)
        XCTAssertEqual(offer.priceKind, .range)
        XCTAssertEqual(offer.minimumAmountCents, 900)
        XCTAssertEqual(offer.maximumAmountCents, 1200)
        XCTAssertFalse(offer.evidence.isLocated)
        XCTAssertTrue(draft.reviewFindings?.contains { $0.code == "unknown_evidence_line" } == true)
        XCTAssertTrue(draft.reviewFindings?.contains { $0.code == "evidence_missing" } == true)
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    func testIncludedOfferWithoutPrintedPriceDoesNotInventRawText() throws {
        let lines = [
            line("Menü Lichtburg", page: 0, x: 0.1, y: 0.9),
            line("Antipasti", page: 0, x: 0.1, y: 0.8)
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Menü", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text("Antipasti", language: "de", evidence: ["p1-l2"]),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [
                                MenuImportExtractedOffer(
                                    label: nil,
                                    priceKind: "included",
                                    amountCents: nil,
                                    deltaCents: nil,
                                    minimumAmountCents: nil,
                                    maximumAmountCents: nil,
                                    currencyCode: "EUR",
                                    rawPrice: nil,
                                    basis: "per_item",
                                    appliesToQuantityOrder: nil,
                                    evidenceLineIds: ["p1-l2"]
                                )
                            ],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let offer = try XCTUnwrap(draft.sections.first?.entries.first?.offers.first)

        XCTAssertEqual(offer.priceKind, .included)
        XCTAssertNil(offer.rawPrice)
        XCTAssertEqual(offer.evidence.rawText, "Antipasti")
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    func testAssemblerUsesVisibleOrderAndRetainsPageSemantics() {
        let lines = [
            line("Zweite Kategorie", page: 0, x: 0.1, y: 0.7),
            line("Erste Kategorie", page: 0, x: 0.1, y: 0.9)
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "mixed",
            languages: ["de", "en"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Zweite Kategorie", language: "de", evidence: ["p1-l2"]),
                    order: 1,
                    entries: [],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                ),
                MenuImportExtractedSection(
                    title: text("Erste Kategorie", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )

        XCTAssertEqual(
            draft.sections.map(\.title.value),
            ["Erste Kategorie", "Zweite Kategorie"]
        )
        XCTAssertEqual(draft.sections.map(\.order), [0, 1])
        XCTAssertEqual(draft.sourceDocument.pages?.first?.pageKind, "mixed")
        XCTAssertEqual(draft.sourceDocument.pages?.first?.languages, ["de", "en"])
    }

    private func source() -> MenuImportSourceDocument {
        MenuImportSourceDocument(
            id: "contract-test-source",
            sourceType: .demoFixture,
            pageCount: 1,
            fingerprint: "sha256:document",
            pages: [
                MenuImportSourcePage(
                    pageIndex: 0,
                    fingerprint: "sha256:page",
                    pixelWidth: 1000,
                    pixelHeight: 1400
                )
            ]
        )
    }

    private func processing(pages: Int = 1) -> MenuImportProcessingMetadata {
        MenuImportProcessingMetadata(
            pipelineVersion: "test",
            provider: "test-provider",
            promptVersion: MenuImportExtractionPrompt.version,
            promptFingerprint: MenuImportExtractionPrompt.fingerprint,
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageOutcomes: (0 ..< pages).map { pageIndex in
                MenuImportPageOutcome(
                    pageIndex: pageIndex,
                    status: .processed,
                    attempts: 1
                )
            }
        )
    }

    /// The two "missing" entries of the first paid Gemini run were not losses
    /// but unnormalized names: `Veganes Kokoscurry [FI]` (an unseparated
    /// bracket run) and `Bunter Marktsalat WI` (no bracket at all). Both are
    /// split only because the page's own legend defines `F`, `I` and `W`.
    ///
    /// The same fixture proves the guard: `Pizza Familie [XL]` keeps its size
    /// in the name even though a legend is present, because `X` is not one of
    /// its codes. Splitting it would invent two declarations from a size.
    func testLegendBackedTrailingCodesSplitWhileUnbackedRunsStayInTheName() throws {
        let lines = [
            line("Karte", page: 0, x: 0.1, y: 0.9),
            line("Veganes Kokoscurry [FI] 15,90 €", page: 0, x: 0.1, y: 0.8),
            line("Bunter Marktsalat WI 8,90 €", page: 0, x: 0.1, y: 0.7),
            line("Pizza Familie [XL] 22,00 €", page: 0, x: 0.1, y: 0.6),
            line("F = Fisch, I = Sellerie, W = Weichtiere", page: 0, x: 0.1, y: 0.1)
        ]
        let legend = ["F": "Fisch", "I": "Sellerie", "W": "Weichtiere"].map { code, meaning in
            MenuImportExtractedDeclaration(
                kind: "source_declaration",
                rawText: "\(code) = \(meaning)",
                alternatives: [],
                localCode: code,
                canonicalId: nil,
                claim: "unknown",
                scope: "document",
                evidenceLineIds: ["p1-l5"]
            )
        }
        let names = [
            "Veganes Kokoscurry [FI]",
            "Bunter Marktsalat WI",
            "Pizza Familie [XL]"
        ]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Karte", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: names.enumerated().map { index, name in
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text(name, language: "de", evidence: ["p1-l\(index + 2)"]),
                            description: nil,
                            itemNumber: nil,
                            order: index,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    },
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: legend,
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let entries = try XCTUnwrap(draft.sections.first?.entries)

        XCTAssertEqual(entries[0].name.value, "Veganes Kokoscurry")
        XCTAssertEqual(entries[0].declarations.compactMap(\.localCode), ["F", "I"])

        XCTAssertEqual(entries[1].name.value, "Bunter Marktsalat")
        XCTAssertEqual(entries[1].declarations.compactMap(\.localCode), ["W", "I"])

        // Unbacked by the legend, so the size stays where it was printed.
        XCTAssertEqual(entries[2].name.value, "Pizza Familie [XL]")
        XCTAssertEqual(entries[2].declarations, [])

        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    /// Without a legend the assembler has no evidence at all, so neither new
    /// shape may fire — an unseparated run stays in the name rather than
    /// becoming guessed declarations.
    func testTrailingRunsAreNotSplitWhenTheDocumentPrintedNoLegend() throws {
        let lines = [
            line("Karte", page: 0, x: 0.1, y: 0.9),
            line("Veganes Kokoscurry [FI]", page: 0, x: 0.1, y: 0.8),
            line("Bunter Marktsalat WI", page: 0, x: 0.1, y: 0.7)
        ]
        let names = ["Veganes Kokoscurry [FI]", "Bunter Marktsalat WI"]
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Karte", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: names.enumerated().map { index, name in
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text(name, language: "de", evidence: ["p1-l\(index + 2)"]),
                            description: nil,
                            itemNumber: nil,
                            order: index,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    },
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )
        let entries = try XCTUnwrap(draft.sections.first?.entries)

        XCTAssertEqual(entries[0].name.value, "Veganes Kokoscurry [FI]")
        XCTAssertEqual(entries[1].name.value, "Bunter Marktsalat WI")
        XCTAssertTrue(entries.allSatisfy { $0.declarations.isEmpty })
    }

    /// A legend on a *later* page must still govern earlier entries — the
    /// common real layout, and the reason legend codes are collected across
    /// the whole document before any entry is converted.
    func testLegendOnALaterPageStillNormalizesEarlierEntries() throws {
        let lines = [
            line("Karte", page: 0, x: 0.1, y: 0.9),
            line("Bunter Marktsalat WI", page: 0, x: 0.1, y: 0.8),
            line("W = Weichtiere, I = Sellerie", page: 1, x: 0.1, y: 0.9)
        ]
        let menuPage = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Karte", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text("Bunter Marktsalat WI", language: "de", evidence: ["p1-l2"]),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: [],
            reviewReasons: []
        )
        let legendPage = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 1,
            pageKind: "legend",
            languages: ["de"],
            sections: [],
            declarations: ["W": "Weichtiere", "I": "Sellerie"].map { code, meaning in
                MenuImportExtractedDeclaration(
                    kind: "source_declaration",
                    rawText: "\(code) = \(meaning)",
                    alternatives: [],
                    localCode: code,
                    canonicalId: nil,
                    claim: "unknown",
                    scope: "document",
                    evidenceLineIds: ["p2-l1"]
                )
            },
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [menuPage, legendPage],
            ocrLines: lines,
            processing: processing(pages: 2)
        )
        let entries = try XCTUnwrap(draft.sections.first?.entries)

        XCTAssertEqual(entries[0].name.value, "Bunter Marktsalat")
        XCTAssertEqual(entries[0].declarations.compactMap(\.localCode), ["W", "I"])
    }

    /// Measured on a real card that prints no legend at all: the provider
    /// returned eleven "legend" entries built from dish names cut after their
    /// first character (`a` = `"a ntipasti-Vorspeisen"`). Nothing illegal was
    /// claimed, so the forbidden-claim check stayed silent, but the operator
    /// would have seen a fabricated allergen legend.
    func testFabricatedLegendBuiltFromEntryNamesIsRejected() throws {
        let lines = [
            line("Antipasti-Vorspeisen", page: 0, x: 0.1, y: 0.9),
            line("Carpaccio Di Manzo", page: 0, x: 0.1, y: 0.8),
            line("A Glutenhaltiges Getreide", page: 0, x: 0.1, y: 0.1)
        ]
        let declarations = [
            // Fabricated: the dish name re-split after its first character.
            ("a", "a ntipasti-Vorspeisen"),
            ("c", "c arpaccio Di Manzo"),
            // Genuine legend line on the same page — must survive.
            ("g", "A Glutenhaltiges Getreide")
        ].map { code, raw in
            MenuImportExtractedDeclaration(
                kind: "source_declaration",
                rawText: raw,
                alternatives: [],
                localCode: code,
                canonicalId: nil,
                claim: "unknown",
                scope: "document",
                evidenceLineIds: ["p1-l3"]
            )
        }
        let extraction = MenuImportPageExtraction(
            contractVersion: MenuImportPageExtraction.currentContractVersion,
            pageIndex: 0,
            pageKind: "menu",
            languages: ["de"],
            sections: [
                MenuImportExtractedSection(
                    title: text("Antipasti-Vorspeisen", language: "de", evidence: ["p1-l1"]),
                    order: 0,
                    entries: [
                        MenuImportExtractedEntry(
                            kind: "food",
                            name: text("Carpaccio Di Manzo", language: "de", evidence: ["p1-l2"]),
                            description: nil,
                            itemNumber: nil,
                            order: 0,
                            offers: [],
                            quantities: [],
                            optionGroups: [],
                            bundleComponents: [],
                            declarations: [],
                            reviewReasons: []
                        )
                    ],
                    subsections: [],
                    declarations: [],
                    reviewReasons: []
                )
            ],
            declarations: declarations,
            reviewReasons: []
        )

        let draft = MenuImportDraftAssembler().assemble(
            sourceDocument: source(),
            pageExtractions: [extraction],
            ocrLines: lines,
            processing: processing()
        )

        XCTAssertEqual(draft.declarations.compactMap(\.localCode), ["g"])
        XCTAssertEqual(
            draft.reviewFindings?.filter {
                $0.code == "rejected_name_derived_legend_entry"
            }.count,
            2,
            "Beide Fälschungen müssen sichtbar verworfen werden, nicht still."
        )
        XCTAssertTrue(draft.validate().errors.isEmpty)
    }

    private func text(
        _ value: String,
        language: String?,
        evidence: [String]
    ) -> MenuImportExtractedText {
        MenuImportExtractedText(
            value: value,
            languageTag: language,
            evidenceLineIds: evidence,
            alternatives: []
        )
    }

    private func line(
        _ text: String,
        page: Int,
        x: Double,
        y: Double
    ) -> MenuImportOCRLine {
        MenuImportOCRLine(
            text: text,
            pageIndex: page,
            minX: x,
            minY: y,
            midY: y + 0.02,
            width: 0.2,
            height: 0.04,
            confidence: 0.82
        )
    }
}
