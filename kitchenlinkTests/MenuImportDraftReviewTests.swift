import Foundation
import Testing
@testable import kitchenlink

struct MenuImportDraftReviewTests {

    // MARK: - Cropper

    @Test
    func cropRectFlipsVisionCoordinatesIntoImageSpace() {
        let box = MenuImportNormalizedBoundingBox(x: 0.1, y: 0.1, width: 0.5, height: 0.2)
        let rect = MenuImportEvidenceCropper.cropRect(
            for: box,
            imageSize: CGSize(width: 1_000, height: 2_000),
            paddingFraction: 0
        )

        // Vision y measures from the bottom: y=0.1/h=0.2 ends 0.3 from the
        // bottom, so the top-left origin sits at (1 - 0.1 - 0.2) = 0.7.
        #expect(rect.origin.x == 100)
        #expect(rect.origin.y == 1_400)
        #expect(rect.width == 500)
        #expect(rect.height == 400)
    }

    @Test
    func cropRectStaysInsideTheImage() {
        let box = MenuImportNormalizedBoundingBox(x: 0.9, y: 0.0, width: 0.1, height: 0.05)
        let rect = MenuImportEvidenceCropper.cropRect(
            for: box,
            imageSize: CGSize(width: 1_000, height: 1_000),
            paddingFraction: 0.05
        )

        #expect(rect.maxX <= 1_000)
        #expect(rect.maxY <= 1_000)
        #expect(rect.minX >= 0)
        #expect(rect.minY >= 0)
    }

    // MARK: - Unlocated evidence (audit P2)

    @Test
    func priceWithoutMatchedLineIsMarkedUnlocated() throws {
        let adapter = MenuImportDraftAdapter()
        let nameLine = line("Pasta Limone", x: 0.1, y: 0.7)
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [
                section(items: [item(id: "p1", name: "Pasta Limone", priceCents: 1_290)])
            ],
            ocrLines: [nameLine],
            unpricedCandidates: []
        )

        let offer = try #require(draft.sections.first?.entries.first?.offers.first)
        let name = try #require(draft.sections.first?.entries.first?.name)

        #expect(name.evidence.isLocated)
        #expect(!offer.evidence.isLocated)
        #expect(draft.validate().isValid)
    }

    @Test
    func matchedPriceLineStaysLocated() throws {
        let adapter = MenuImportDraftAdapter()
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [
                section(items: [item(id: "p1", name: "Pasta Limone", priceCents: 1_290)])
            ],
            ocrLines: [
                line("Pasta Limone", x: 0.1, y: 0.7),
                line("12,90", x: 0.8, y: 0.7)
            ],
            unpricedCandidates: []
        )

        let offer = try #require(draft.sections.first?.entries.first?.offers.first)
        #expect(offer.evidence.isLocated)
        #expect(offer.evidence.rawText == "12,90")
    }

    // MARK: - Converter

    @Test
    func converterDropsRejectedAndUnpricedEntries() {
        var draft = reviewableDraft()
        draft.sections[0].entries[0].reviewState = .rejected

        let sections = MenuImportDraftConverter.convert(draft)
        let names = sections.flatMap(\.items).map(\.name)

        // Entry 0 is rejected, entry 2 has no price: only entry 1 converts.
        #expect(names == ["Rindergulasch"])
    }

    @Test @MainActor
    func reviewAndConverterKeepEntriesFromNestedSubsections() throws {
        let nestedEntry = MenuImportEntry(
            id: "nested-entry",
            name: text("Sorbet", id: "nested-name"),
            order: 0,
            offers: [offer(id: "nested-offer", cents: 790)],
            reviewState: .needsReview
        )
        let nestedSection = MenuImportSection(
            id: "nested-section",
            title: text("Eis", id: "nested-section-title"),
            order: 0,
            entries: [nestedEntry],
            reviewState: .needsReview
        )
        let parentSection = MenuImportSection(
            id: "parent-section",
            title: text("Dessert", id: "parent-section-title"),
            order: 0,
            subsections: [nestedSection],
            reviewState: .needsReview
        )
        let draft = MenuImportDraft(
            sourceDocument: source(),
            sections: [parentSection],
            reviewState: .needsReview
        )
        let model = MenuImportDraftReviewModel(draft: draft)

        #expect(model.sections.map(\.title.value) == ["Dessert", "Eis"])
        #expect(model.entry(withID: "nested-entry")?.name.value == "Sorbet")
        #expect(model.sectionID(ofEntry: "nested-entry") == "nested-section")
        #expect(model.unresolvedEntryIDs == ["nested-entry"])

        model.acceptEntry("nested-entry")
        let converted = try #require(model.convertToSandboxSections())

        #expect(converted.map(\.title) == ["Eis"])
        #expect(converted.flatMap(\.items).map(\.name) == ["Sorbet"])
    }

    @Test @MainActor
    func nestedEntryCanMoveToParentWithoutBeingLost() throws {
        let nestedEntry = MenuImportEntry(
            id: "nested-entry",
            name: text("Sorbet", id: "nested-name"),
            order: 0,
            offers: [offer(id: "nested-offer", cents: 790)],
            reviewState: .needsReview
        )
        let draft = MenuImportDraft(
            sourceDocument: source(),
            sections: [
                MenuImportSection(
                    id: "parent-section",
                    title: text("Dessert", id: "parent-title"),
                    order: 0,
                    subsections: [
                        MenuImportSection(
                            id: "nested-section",
                            title: text("Eis", id: "nested-title"),
                            order: 0,
                            entries: [nestedEntry],
                            reviewState: .needsReview
                        )
                    ],
                    reviewState: .needsReview
                )
            ],
            reviewState: .needsReview
        )
        let model = MenuImportDraftReviewModel(draft: draft)

        model.moveEntry("nested-entry", toSectionID: "parent-section")

        #expect(model.sectionID(ofEntry: "nested-entry") == "parent-section")
        #expect(model.entry(withID: "nested-entry")?.order == 0)
    }

    @Test
    func converterMapsVariantsDeclarationsAndLegend() throws {
        let draft = reviewableDraft()
        let sections = MenuImportDraftConverter.convert(draft)

        let schnitzel = try #require(sections.flatMap(\.items).first {
            $0.name == "Wiener Schnitzel"
        })
        #expect(schnitzel.priceCents == 2_280)
        #expect(schnitzel.allergenCodes == "a,c")
        #expect(schnitzel.variants.count == 1)
        #expect(schnitzel.variants.first?.priceCents == 200)
        #expect(schnitzel.variants.first?.kind == .extra)
        #expect(schnitzel.variants.first?.selectionMode == "quantity")
        #expect(schnitzel.variants.first?.freeSelectionCount == 1)
        #expect(schnitzel.variants.first?.allowsRepeats == true)
        #expect(schnitzel.priceBasis == "per_item")

        let legend = try #require(sections.first?.allergenLegend)
        #expect(legend["a"] == "Gluten")
    }

    @Test
    func guestPricingHonorsFreeAndRepeatedSelections() {
        let sauce = MenuItemVariant(
            id: "sauce",
            name: "Sauce",
            priceCents: 100,
            kind: .extra,
            priceKind: .delta,
            groupID: "sauces",
            minimumSelections: 0,
            maximumSelections: 3,
            selectionMode: "quantity",
            freeSelectionCount: 1,
            allowsRepeats: true
        )
        let item = MenuItemData(
            id: "burger",
            name: "Burger",
            description: "",
            priceCents: 1_000,
            kind: .food,
            variants: [sauce]
        )

        #expect(MenuImportConfigurationPricing.unitPrice(item: item, selectedOptions: [sauce]) == 1_000)
        #expect(MenuImportConfigurationPricing.unitPrice(item: item, selectedOptions: [sauce, sauce]) == 1_100)
    }

    @Test
    func converterKeepsPerPersonPriceBasis() throws {
        var draft = reviewableDraft()
        draft.sections[0].entries[0].offers[0].basis = "per_person"

        let item = try #require(
            MenuImportDraftConverter.convert(draft).flatMap(\.items).first {
                $0.name == "Wiener Schnitzel"
            }
        )
        #expect(item.priceBasis == "per_person")
    }

    // MARK: - Review model

    @Test @MainActor
    func unpricedEntryBlocksConversionUntilResolved() {
        let model = MenuImportDraftReviewModel(draft: reviewableDraft())

        #expect(!model.canConvert)
        #expect(model.unresolvedEntryIDs == ["entry-unpriced"])

        model.setEntryPrice("entry-unpriced", cents: 790)

        #expect(model.unresolvedEntryIDs.isEmpty)
        #expect(model.canConvert)

        let sections = model.convertToSandboxSections()
        let priced = sections?.flatMap(\.items).first { $0.id.contains("entry-unpriced") }
        #expect(priced?.priceCents == 790)
        #expect(model.draft.validate().isValid)
    }

    @Test @MainActor
    func rejectingTheUnpricedEntryAlsoUnlocksConversion() {
        let model = MenuImportDraftReviewModel(draft: reviewableDraft())

        model.rejectEntry("entry-unpriced")

        #expect(model.canConvert)
        let names = model.convertToSandboxSections()?.flatMap(\.items).map(\.name)
        #expect(names == ["Wiener Schnitzel", "Rindergulasch"])
    }

    @Test @MainActor
    func unpricedEntryCannotBeAcceptedWithoutAUsablePrice() throws {
        let model = MenuImportDraftReviewModel(draft: reviewableDraft())

        model.acceptEntry("entry-unpriced")

        let entry = try #require(model.entry(withID: "entry-unpriced"))
        #expect(entry.reviewState == .needsReview)
        #expect(model.unresolvedEntryIDs == ["entry-unpriced"])
        #expect(!model.canConvert)
    }

    @Test @MainActor
    func batchAcceptanceKeepsUnpricedEntriesOpen() throws {
        var draft = reviewableDraft()
        draft.sections[0].entries[0].reviewState = .needsReview
        draft.sections[0].entries[1].reviewState = .needsReview
        let model = MenuImportDraftReviewModel(draft: draft)

        #expect(model.unresolvedConvertibleEntryIDs == [
            "entry-schnitzel",
            "entry-gulasch",
        ])

        model.acceptAllConvertibleEntries()

        #expect(try #require(model.entry(withID: "entry-schnitzel")).reviewState == .accepted)
        #expect(try #require(model.entry(withID: "entry-gulasch")).reviewState == .accepted)
        #expect(try #require(model.entry(withID: "entry-unpriced")).reviewState == .needsReview)
        #expect(model.unresolvedEntryIDs == ["entry-unpriced"])
        #expect(!model.canConvert)
    }

    @Test @MainActor
    func humanEnteredPriceCarriesUnlocatedHumanEvidence() throws {
        let model = MenuImportDraftReviewModel(draft: reviewableDraft())

        model.setEntryPrice("entry-unpriced", cents: 790)

        let entry = try #require(model.entry(withID: "entry-unpriced"))
        let offer = try #require(entry.offers.first)
        #expect(offer.priceKind == .fixed)
        #expect(offer.evidence.method == .human)
        #expect(!offer.evidence.isLocated)
        #expect(entry.reviewState == .edited)
    }

    @Test @MainActor
    func humanCorrectedPricePreservesPerPersonBasis() throws {
        var draft = reviewableDraft()
        draft.sections[0].entries[2].offers = [
            MenuImportOffer(
                id: "menu-price",
                priceKind: .fixed,
                amountCents: 3_990,
                currencyCode: "EUR",
                rawPrice: "39,90",
                basis: "per_person",
                evidence: evidence(id: "menu-price-evidence")
            ),
        ]
        let model = MenuImportDraftReviewModel(draft: draft)

        model.setEntryPrice("entry-unpriced", cents: 4_190)

        let corrected = try #require(model.entry(withID: "entry-unpriced")?.offers.first)
        #expect(corrected.amountCents == 4_190)
        #expect(corrected.basis == "per_person")
    }

    @Test @MainActor
    func movingAnEntryKeepsTheDraftValid() throws {
        var draft = reviewableDraft()
        draft.sections.append(
            MenuImportSection(
                id: "section-target",
                title: text("Desserts", id: "target-title"),
                order: 1
            )
        )
        let model = MenuImportDraftReviewModel(draft: draft)

        model.moveEntry("entry-unpriced", toSectionID: "section-target")

        #expect(model.sectionID(ofEntry: "entry-unpriced") == "section-target")
        #expect(model.draft.validate().isValid)

        let sourceOrders = model.draft.sections[0].entries.map(\.order)
        #expect(sourceOrders == Array(0..<sourceOrders.count))
    }

    @Test
    func priceTextParsesGermanAndPlainFormats() {
        #expect(MenuImportPriceText.cents(from: "12,90") == 1_290)
        #expect(MenuImportPriceText.cents(from: "12.90") == 1_290)
        #expect(MenuImportPriceText.cents(from: "7") == 700)
        #expect(MenuImportPriceText.cents(from: "€ 7,50") == 750)
        #expect(MenuImportPriceText.cents(from: "") == nil)
        #expect(MenuImportPriceText.cents(from: "abc") == nil)
        #expect(MenuImportPriceText.cents(from: "-3,00") == nil)
    }

    // MARK: - Fixtures

    /// One section, three entries: priced with variant+allergens, priced
    /// plain, and an unpriced `needsReview` candidate.
    private func reviewableDraft() -> MenuImportDraft {
        let schnitzel = MenuImportEntry(
            id: "entry-schnitzel",
            kind: MenuItemKind.food.rawValue,
            name: text("Wiener Schnitzel", id: "t-schnitzel"),
            order: 0,
            offers: [offer(id: "offer-schnitzel", cents: 2_280)],
            optionGroups: [
                MenuImportOptionGroup(
                    id: "group-extras",
                    title: text("Extras", id: "t-extras"),
                    order: 0,
                    selectionRule: MenuImportSelectionRule(
                        minimum: 0,
                        maximum: 3,
                        freeSelectionCount: 1,
                        mode: "quantity",
                        allowsRepeats: true
                    ),
                    choices: [
                        MenuImportChoice(
                            id: "choice-cheese",
                            name: text("Extra Käse", id: "t-cheese"),
                            kind: MenuItemOptionKind.extra.rawValue,
                            order: 0,
                            offers: [
                                MenuImportOffer(
                                    id: "offer-cheese",
                                    priceKind: .delta,
                                    deltaCents: 200,
                                    currencyCode: "EUR",
                                    rawPrice: "+2,00",
                                    basis: "per_item",
                                    evidence: evidence(id: "e-cheese")
                                )
                            ]
                        )
                    ]
                )
            ],
            declarations: [
                MenuImportDeclaration(
                    id: "decl-a",
                    kind: "source_declaration",
                    rawText: "a Gluten",
                    localCode: "a",
                    claim: "declared",
                    scope: "entry",
                    evidence: evidence(id: "e-decl-a")
                ),
                MenuImportDeclaration(
                    id: "decl-c",
                    kind: "source_declaration",
                    rawText: "c Eier",
                    localCode: "c",
                    claim: "declared",
                    scope: "entry",
                    evidence: evidence(id: "e-decl-c")
                )
            ]
        )
        let gulasch = MenuImportEntry(
            id: "entry-gulasch",
            kind: MenuItemKind.food.rawValue,
            name: text("Rindergulasch", id: "t-gulasch"),
            order: 1,
            offers: [offer(id: "offer-gulasch", cents: 1_890)]
        )
        let unpriced = MenuImportEntry(
            id: "entry-unpriced",
            kind: MenuItemKind.food.rawValue,
            name: text("Gemischter Eisbecher", id: "t-eis"),
            order: 2,
            offers: [],
            reviewState: .needsReview
        )

        return MenuImportDraft(
            sourceDocument: source(),
            sections: [
                MenuImportSection(
                    id: "section-main",
                    title: text("Hauptgerichte", id: "t-main"),
                    order: 0,
                    entries: [schnitzel, gulasch, unpriced]
                )
            ],
            declarations: [
                MenuImportDeclaration(
                    id: "doc-decl-a",
                    kind: "source_declaration",
                    rawText: "a Gluten",
                    localCode: "a",
                    claim: "unknown",
                    scope: "document",
                    evidence: evidence(id: "e-doc-a")
                )
            ],
            reviewState: .needsReview
        )
    }

    private func source() -> MenuImportSourceDocument {
        MenuImportSourceDocument(
            id: "source-review-test",
            sourceType: .demoFixture,
            pageCount: 1,
            fingerprint: "sha256:review-test"
        )
    }

    private func section(items: [MenuItemData]) -> MenuSectionData {
        MenuSectionData(
            id: "legacy-section",
            title: "Hauptgerichte",
            subtitle: "Importiert",
            kind: .food,
            items: items,
            importConfidence: 0.9
        )
    }

    private func item(id: String, name: String, priceCents: Int) -> MenuItemData {
        MenuItemData(
            id: id,
            name: name,
            description: "Automatisch importiert",
            priceCents: priceCents,
            kind: .food
        )
    }

    private func line(_ textValue: String, x: Double, y: Double) -> MenuImportOCRLine {
        MenuImportOCRLine(
            text: textValue,
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

    private func text(_ value: String, id: String) -> MenuImportText {
        MenuImportText(value: value, evidence: evidence(id: "e-\(id)"))
    }

    private func offer(id: String, cents: Int) -> MenuImportOffer {
        MenuImportOffer(
            id: id,
            priceKind: .fixed,
            amountCents: cents,
            currencyCode: "EUR",
            rawPrice: MenuImportPriceText.euro(cents: cents),
            basis: "per_item",
            evidence: evidence(id: "e-\(id)")
        )
    }

    private func evidence(id: String) -> MenuImportEvidence {
        MenuImportEvidence(
            rawText: "raw \(id)",
            pageIndex: 0,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0.1,
                y: 0.1,
                width: 0.3,
                height: 0.05
            ),
            method: .ocr,
            confidence: 0.9
        )
    }
}
