import Foundation
import Testing
@testable import kitchenlink

struct MenuImportDraftAdapterTests {
    @Test
    func adapterPreservesRawPriceAndBoundingBox() throws {
        let section = menuSection(
            items: [
                MenuItemData(
                    id: "legacy-pasta",
                    name: "Pasta Limone",
                    description: "Automatisch importiert",
                    priceCents: 1_290,
                    kind: .food
                )
            ]
        )
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [section],
            ocrLines: [
                line("Pasta", x: 0.08, y: 0.82),
                line("Pasta Limone", x: 0.10, y: 0.70),
                line("12,90", x: 0.82, y: 0.70)
            ],
            unpricedCandidates: []
        )

        let validation = draft.validate()
        let entry = try #require(draft.sections.first?.entries.first)
        let offer = try #require(entry.offers.first)

        #expect(validation.isValid)
        #expect(offer.amountCents == 1_290)
        #expect(offer.rawPrice == "12,90")
        #expect(offer.evidence.rawText == "12,90")
        #expect(offer.evidence.pageIndex == 0)
        #expect(offer.evidence.boundingBox.x == 0.82)
    }

    @Test
    func adapterKeepsUnpricedCandidateAsReviewableEntry() throws {
        let section = menuSection(
            items: [
                MenuItemData(
                    id: "legacy-priced",
                    name: "Coup Daenemark",
                    description: "Automatisch importiert",
                    priceCents: 790,
                    kind: .food
                )
            ]
        )
        let candidateLine = line("Gemischter Eisbecher", x: 0.10, y: 0.60)
        let candidate = MenuImportUnpricedCandidate(
            sectionID: section.id,
            sectionTitle: section.title,
            title: "Gemischter Eisbecher",
            kind: MenuItemKind.food.rawValue,
            description: "Drei Kugeln Eis mit Sahne",
            allergenCodes: nil,
            titleLine: candidateLine,
            descriptionLines: [line("Drei Kugeln Eis mit Sahne", x: 0.10, y: 0.55)]
        )

        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [section],
            ocrLines: [
                line("Dessert", x: 0.08, y: 0.82),
                line("Coup Daenemark", x: 0.10, y: 0.70),
                line("7,90", x: 0.82, y: 0.70),
                candidateLine,
                line("Drei Kugeln Eis mit Sahne", x: 0.10, y: 0.55)
            ],
            unpricedCandidates: [candidate]
        )

        let entry = try #require(
            draft.sections.flatMap(\.entries).first { $0.name.value == "Gemischter Eisbecher" }
        )
        let validation = draft.validate()

        #expect(entry.offers.isEmpty)
        #expect(entry.reviewState == .needsReview)
        #expect(entry.name.evidence.boundingBox.x == 0.10)
        #expect(validation.isValid)
        #expect(validation.warnings.contains {
            $0.code == .missingPrice && $0.path.contains("entries[1]")
        })
    }

    @Test
    func extraPriceRemainsADeltaInsteadOfASecondBasePrice() throws {
        let item = MenuItemData(
            id: "legacy-burger",
            name: "Burger",
            description: "Automatisch importiert",
            priceCents: 1_500,
            kind: .food,
            variants: [
                MenuItemVariant(
                    id: "legacy-extra",
                    name: "Extra Kaese",
                    priceCents: 200,
                    kind: .extra
                )
            ]
        )
        let draft = adapter.makeDraft(
            sourceDocument: source(),
            legacySections: [menuSection(items: [item])],
            ocrLines: [
                line("Burger 15,00", x: 0.10, y: 0.70),
                line("Extra Kaese +2,00", x: 0.10, y: 0.64)
            ],
            unpricedCandidates: []
        )

        let entry = try #require(draft.sections.first?.entries.first)
        let group = try #require(entry.optionGroups.first)
        let offer = try #require(group.choices.first?.offers.first)

        #expect(group.choices.first?.kind == MenuItemOptionKind.extra.rawValue)
        #expect(offer.priceKind == .delta)
        #expect(offer.deltaCents == 200)
        #expect(offer.amountCents == nil)
        #expect(offer.rawPrice == "2,00")
        #expect(draft.validate().isValid)
    }

    private let adapter = MenuImportDraftAdapter()

    private func source() -> MenuImportSourceDocument {
        MenuImportSourceDocument(
            id: "source-adapter-test",
            sourceType: .demoFixture,
            pageCount: 1,
            fingerprint: "sha256:adapter-test"
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
