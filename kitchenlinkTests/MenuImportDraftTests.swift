import Foundation
import Testing
@testable import kitchenlink

struct MenuImportDraftTests {
    @Test
    func unsupportedContractVersionIsRejected() {
        let value = MenuImportDraft(
            schemaVersion: "9.9.9",
            id: "draft-future-version",
            sourceDocument: MenuImportSourceDocument(
                id: "source-future-version",
                sourceType: .demoFixture,
                pageCount: 1,
                fingerprint: "sha256:future"
            )
        )

        let result = value.validate()

        #expect(!result.isValid)
        #expect(result.errors.contains { $0.code == .unsupportedSchemaVersion })
    }

    @Test
    func entryWithoutPriceRemainsValidWithWarning() {
        let entry = MenuImportEntry(
            id: "entry-price-missing",
            name: text("Tagessuppe", id: "entry-name"),
            order: 0
        )
        let result = draft(entry: entry).validate()

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(
            result.warnings.contains {
                $0.code == .missingPrice && $0.path.hasSuffix(".offers")
            }
        )
    }

    @Test
    func priceKindsKeepAbsoluteAndDeltaFieldsSeparate() {
        let validOffers = [
            offer(id: "fixed", kind: .fixed, amount: 1_290, raw: "12,90 EUR"),
            offer(id: "delta", kind: .delta, delta: 250, raw: "+2,50 EUR"),
            offer(id: "free", kind: .free, amount: 0, raw: "gratis"),
            offer(id: "included", kind: .included, raw: "inklusive")
        ]

        for value in validOffers {
            #expect(draft(offer: value).validate().isValid)
        }

        let invalidOffers = [
            offer(
                id: "fixed-with-delta",
                kind: .fixed,
                amount: 1_290,
                delta: 100,
                raw: "12,90 EUR"
            ),
            offer(
                id: "delta-with-absolute",
                kind: .delta,
                amount: 100,
                delta: 100,
                raw: "+1,00 EUR"
            ),
            offer(id: "free-without-zero", kind: .free, raw: "gratis"),
            offer(id: "included-with-zero", kind: .included, amount: 0, raw: "inklusive")
        ]

        for value in invalidOffers {
            let result = draft(offer: value).validate()
            #expect(!result.isValid)
            #expect(result.errors.contains { $0.code == .invalidPrice })
        }
    }

    @Test
    func evidenceMustStayInsideItsSourcePage() {
        let invalidEvidence = MenuImportEvidence(
            rawText: "Ausserhalb",
            pageIndex: 1,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0.8,
                y: 0.2,
                width: 0.3,
                height: 0.1
            ),
            method: .ocr,
            confidence: 0.9
        )
        let entry = MenuImportEntry(
            id: "entry-invalid-evidence",
            name: MenuImportText(value: "Ausserhalb", evidence: invalidEvidence),
            order: 0
        )
        let result = draft(entry: entry, pageCount: 1).validate()

        #expect(!result.isValid)
        #expect(result.errors.contains { $0.code == .invalidPageIndex })
        #expect(result.errors.contains { $0.code == .invalidBoundingBox })
    }

    @Test
    func optionSelectionMinimumCannotExceedMaximum() {
        let optionGroup = MenuImportOptionGroup(
            id: "group-sides",
            title: text("Beilagen", id: "group-title"),
            order: 0,
            selectionRule: MenuImportSelectionRule(
                minimum: 2,
                maximum: 1,
                mode: "multiple"
            )
        )
        let entry = MenuImportEntry(
            id: "entry-with-options",
            name: text("Schnitzel", id: "entry-options-name"),
            order: 0,
            optionGroups: [optionGroup]
        )
        let result = draft(entry: entry).validate()

        #expect(!result.isValid)
        #expect(result.errors.contains { $0.code == .invalidSelectionRange })
    }

    @Test
    func duplicateIDsAreRejectedAcrossTheDraft() {
        let entry = MenuImportEntry(
            id: "shared-id",
            name: text("Pasta", id: "duplicate-name"),
            order: 0
        )
        let section = MenuImportSection(
            id: "shared-id",
            title: text("Hauptgerichte", id: "duplicate-section-title"),
            order: 0,
            entries: [entry]
        )
        let result = draft(section: section).validate()

        #expect(!result.isValid)
        #expect(result.errors.contains { $0.code == .duplicateID })
    }

    @Test
    func draftSurvivesJSONRoundTrip() throws {
        let quantity = MenuImportQuantity(
            id: "quantity-wine",
            rawText: "0,2 l",
            value: 0.2,
            unit: "l",
            kind: "volume",
            evidence: evidence("0,2 l", id: "quantity-evidence", pageIndex: 1)
        )
        let declaration = MenuImportDeclaration(
            id: "declaration-sulfites",
            kind: "allergen",
            rawText: "enthält Sulfite",
            localCode: "12",
            canonicalID: "sulphur-dioxide-and-sulphites",
            claim: "contains",
            scope: "entry",
            evidence: evidence("12 enthält Sulfite", id: "declaration-evidence", pageIndex: 1)
        )
        let choice = MenuImportChoice(
            id: "choice-large",
            name: text("Gross", id: "choice-name", pageIndex: 1),
            kind: "size",
            order: 0,
            offers: [
                offer(
                    id: "choice-price",
                    kind: .delta,
                    delta: 200,
                    raw: "+2,00 EUR",
                    pageIndex: 1
                )
            ],
            quantity: quantity,
            declarations: [declaration]
        )
        let optionGroup = MenuImportOptionGroup(
            id: "group-size",
            title: text("Groesse", id: "group-size-title", pageIndex: 1),
            order: 0,
            selectionRule: MenuImportSelectionRule(
                minimum: 1,
                maximum: 1,
                freeSelectionCount: 0,
                mode: "single",
                allowsRepeats: false
            ),
            choices: [choice]
        )
        let bundleComponent = MenuImportBundleComponent(
            id: "bundle-course",
            title: text("Getraenk", id: "bundle-title", pageIndex: 1),
            kind: "course",
            order: 0,
            optionGroup: optionGroup
        )
        let entry = MenuImportEntry(
            id: "entry-menu",
            kind: "bundle",
            name: text("Abendmenue", id: "entry-roundtrip-name", pageIndex: 1),
            description: text(
                "Drei Gaenge",
                id: "entry-roundtrip-description",
                pageIndex: 1
            ),
            order: 0,
            offers: [
                offer(
                    id: "menu-price",
                    kind: .from,
                    minimum: 4_900,
                    raw: "ab 49,00 EUR",
                    basis: "per_person",
                    pageIndex: 1
                )
            ],
            quantities: [quantityWithDistinctID(quantity)],
            bundleComponents: [bundleComponent],
            reviewState: .needsReview
        )
        let section = MenuImportSection(
            id: "section-menu",
            title: text("Menues", id: "section-roundtrip-title", pageIndex: 1),
            order: 0,
            entries: [entry],
            reviewState: .edited
        )
        let original = MenuImportDraft(
            id: "draft-roundtrip",
            sourceDocument: MenuImportSourceDocument(
                id: "source-roundtrip",
                sourceType: .photoLibrary,
                pageCount: 2,
                fingerprint: "sha256:roundtrip",
                displayName: "menu.jpg"
            ),
            sections: [section],
            declarations: [],
            reviewState: .needsReview
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MenuImportDraft.self, from: data)

        #expect(decoded == original)
        #expect(decoded.validate().isValid)
    }

    private func draft(
        offer: MenuImportOffer,
        pageCount: Int = 1
    ) -> MenuImportDraft {
        draft(
            entry: MenuImportEntry(
                id: "entry-\(offer.id)",
                name: text("Testartikel", id: "entry-name-\(offer.id)"),
                order: 0,
                offers: [offer]
            ),
            pageCount: pageCount
        )
    }

    private func draft(
        entry: MenuImportEntry,
        pageCount: Int = 1
    ) -> MenuImportDraft {
        draft(
            section: MenuImportSection(
                id: "section-\(entry.id)",
                title: text("Testsektion", id: "section-title-\(entry.id)"),
                order: 0,
                entries: [entry]
            ),
            pageCount: pageCount
        )
    }

    private func draft(
        section: MenuImportSection,
        pageCount: Int = 1
    ) -> MenuImportDraft {
        MenuImportDraft(
            id: "draft-test",
            sourceDocument: MenuImportSourceDocument(
                id: "source-test",
                sourceType: .demoFixture,
                pageCount: pageCount,
                fingerprint: "sha256:test"
            ),
            sections: [section]
        )
    }

    private func offer(
        id: String,
        kind: MenuImportPriceKind,
        amount: Int? = nil,
        delta: Int? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        raw: String,
        basis: String = "per_item",
        pageIndex: Int = 0
    ) -> MenuImportOffer {
        MenuImportOffer(
            id: id,
            priceKind: kind,
            amountCents: amount,
            deltaCents: delta,
            minimumAmountCents: minimum,
            maximumAmountCents: maximum,
            currencyCode: "EUR",
            rawPrice: raw,
            basis: basis,
            evidence: evidence(raw, id: "offer-evidence-\(id)", pageIndex: pageIndex)
        )
    }

    private func text(
        _ value: String,
        id: String,
        pageIndex: Int = 0
    ) -> MenuImportText {
        MenuImportText(
            value: value,
            languageTag: "de",
            evidence: evidence(value, id: id, pageIndex: pageIndex)
        )
    }

    private func evidence(
        _ rawText: String,
        id _: String,
        pageIndex: Int = 0
    ) -> MenuImportEvidence {
        MenuImportEvidence(
            rawText: rawText,
            pageIndex: pageIndex,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0.1,
                y: 0.1,
                width: 0.4,
                height: 0.1
            ),
            method: .ocr,
            confidence: 0.92
        )
    }

    private func quantityWithDistinctID(
        _ quantity: MenuImportQuantity
    ) -> MenuImportQuantity {
        var copy = quantity
        copy.id = "entry-quantity-wine"
        return copy
    }
}
