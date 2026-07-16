import Foundation
import Testing
@testable import kitchenlink

struct MenuImportReviewSessionTests {
    @Test
    func unpricedCandidateBlocksConversionUntilPriceIsCorrected() throws {
        let candidate = entry(
            id: "candidate",
            name: "Gemischter Eisbecher",
            offers: [],
            confidence: 0.58,
            reviewState: .needsReview
        )
        var session = MenuImportReviewSession(draft: draft(entries: [candidate]))

        #expect(session.unresolvedCount == 1)
        #expect(!session.canCreateSandboxMenu)
        #expect(throws: MenuImportSandboxConversionError.self) {
            try session.makeSandboxApplication()
        }

        let editResult = session.updateEntry(
            id: candidate.id,
            name: "Gemischter Eisbecher",
            description: "Drei Kugeln Eis mit Sahne",
            priceText: "7,90 €",
            kind: .food
        )
        let application = try session.makeSandboxApplication()
        let reviewedEntry = try #require(session.entry(id: candidate.id))
        let reviewedOffer = try #require(reviewedEntry.offers.first)
        let editSucceeded: Bool
        if case .success = editResult {
            editSucceeded = true
        } else {
            editSucceeded = false
        }

        #expect(editSucceeded)
        #expect(session.unresolvedCount == 0)
        #expect(application.sections.first?.items.first?.priceCents == 790)
        #expect(application.reviewedDraft.reviewState == .accepted)
        #expect(reviewedEntry.name.evidence.rawText == "Gemischter Eisbecher")
        #expect(reviewedEntry.name.evidence.confidence == 0.58)
        #expect(reviewedOffer.evidence.method == .human)
    }

    @Test
    func rejectedCandidateIsExcludedWithoutChangingAcceptedItem() throws {
        let accepted = entry(
            id: "accepted",
            name: "Pasta Limone",
            offers: [offer(cents: 1_290)],
            reviewState: .accepted
        )
        let candidate = entry(
            id: "candidate",
            name: "Tagesdessert",
            offers: [],
            reviewState: .needsReview
        )
        var session = MenuImportReviewSession(draft: draft(entries: [accepted, candidate]))

        let didReject = session.rejectEntry(id: candidate.id)
        #expect(didReject)
        let application = try session.makeSandboxApplication()

        #expect(application.sections.first?.items.map(\.id) == [accepted.id])
        #expect(application.sections.first?.items.first?.priceCents == 1_290)
        #expect(session.rejectedEntryCount == 1)

        let didRestore = session.restoreEntry(id: candidate.id)
        #expect(didRestore)
        #expect(!session.canCreateSandboxMenu)
    }

    @Test
    func acceptingUncertainEntryPreservesOriginalEvidence() throws {
        let uncertain = entry(
            id: "uncertain",
            name: "Hauslimonade",
            offers: [offer(cents: 590, confidence: 0.61, reviewState: .needsReview)],
            confidence: 0.61,
            reviewState: .needsReview
        )
        var session = MenuImportReviewSession(draft: draft(entries: [uncertain]))

        #expect(session.reviewReasons(for: uncertain).contains(.sourceMarkedForReview))
        let didAccept = session.acceptEntry(id: uncertain.id)
        #expect(didAccept)
        let application = try session.makeSandboxApplication()
        let reviewed = try #require(session.entry(id: uncertain.id))

        #expect(application.sections.first?.items.first?.priceCents == 590)
        #expect(reviewed.reviewState == .accepted)
        #expect(reviewed.name.evidence.rawText == "Hauslimonade")
        #expect(reviewed.name.evidence.confidence == 0.61)
    }

    @Test
    func movingEntryChangesDeterministicSandboxOrder() throws {
        let first = entry(id: "first", name: "Erster", offers: [offer(cents: 500)], order: 0, reviewState: .accepted)
        let second = entry(id: "second", name: "Zweiter", offers: [offer(cents: 600)], order: 1, reviewState: .accepted)
        var session = MenuImportReviewSession(draft: draft(entries: [first, second]))

        let didMove = session.moveEntry(id: second.id, direction: .up)
        #expect(didMove)
        let application = try session.makeSandboxApplication()

        #expect(application.sections.first?.items.map(\.id) == [second.id, first.id])
        #expect(session.entry(id: second.id)?.order == 0)
        #expect(session.entry(id: first.id)?.order == 1)
    }

    @Test
    func deltaChoiceRemainsAnExtraDuringSandboxConversion() throws {
        let extraChoice = MenuImportChoice(
            id: "extra-cheese",
            name: text("Extra Käse"),
            kind: MenuItemOptionKind.extra.rawValue,
            order: 0,
            offers: [
                MenuImportOffer(
                    id: "extra-offer",
                    priceKind: .delta,
                    deltaCents: 200,
                    currencyCode: "EUR",
                    rawPrice: "+2,00",
                    evidence: evidence("+2,00")
                )
            ],
            reviewState: .accepted
        )
        let group = MenuImportOptionGroup(
            id: "extras",
            title: text("Extras"),
            order: 0,
            selectionRule: MenuImportSelectionRule(mode: "optional"),
            choices: [extraChoice],
            reviewState: .accepted
        )
        var burger = entry(
            id: "burger",
            name: "Burger",
            offers: [offer(cents: 1_500)],
            reviewState: .accepted
        )
        burger.optionGroups = [group]
        let session = MenuImportReviewSession(draft: draft(entries: [burger]))
        let application = try session.makeSandboxApplication()
        let variant = try #require(application.sections.first?.items.first?.variants.first)

        #expect(variant.kind == .extra)
        #expect(variant.priceCents == 200)
    }

    @Test(arguments: [
        ("12,50", 1_250),
        ("12.5", 1_250),
        ("€ 12,-", 1_200),
        ("1.200", 120_000),
        ("0", 0)
    ])
    func priceParserAcceptsGermanReviewInput(input: String, expectedCents: Int) {
        #expect(MenuImportReviewPriceFormatter.cents(from: input) == expectedCents)
    }

    @Test(arguments: ["", "Marktpreis", "-3,00"])
    func priceParserRejectsAmbiguousOrNegativeInput(input: String) {
        #expect(MenuImportReviewPriceFormatter.cents(from: input) == nil)
    }

    private func draft(entries: [MenuImportEntry]) -> MenuImportDraft {
        MenuImportDraft(
            id: "review-draft",
            sourceDocument: MenuImportSourceDocument(
                id: "review-source",
                sourceType: .demoFixture,
                pageCount: 1,
                fingerprint: "sha256:review-test",
                displayName: "Review Test"
            ),
            sections: [
                MenuImportSection(
                    id: "review-section",
                    title: text("Speisen"),
                    order: 0,
                    entries: entries,
                    reviewState: .accepted
                )
            ],
            reviewState: .needsReview
        )
    }

    private func entry(
        id: String,
        name: String,
        offers: [MenuImportOffer],
        order: Int = 0,
        confidence: Double = 0.95,
        reviewState: MenuImportReviewState
    ) -> MenuImportEntry {
        MenuImportEntry(
            id: id,
            kind: MenuItemKind.food.rawValue,
            name: MenuImportText(
                value: name,
                languageTag: "de",
                evidence: evidence(name, confidence: confidence, reviewState: reviewState)
            ),
            order: order,
            offers: offers,
            reviewState: reviewState
        )
    }

    private func offer(
        cents: Int,
        confidence: Double = 0.95,
        reviewState: MenuImportReviewState = .unreviewed
    ) -> MenuImportOffer {
        MenuImportOffer(
            id: "offer-\(cents)-\(confidence)",
            priceKind: .fixed,
            amountCents: cents,
            currencyCode: "EUR",
            rawPrice: MenuImportReviewPriceFormatter.string(cents: cents),
            basis: "per_item",
            evidence: evidence(
                MenuImportReviewPriceFormatter.string(cents: cents),
                confidence: confidence,
                reviewState: reviewState
            )
        )
    }

    private func text(_ value: String) -> MenuImportText {
        MenuImportText(value: value, languageTag: "de", evidence: evidence(value))
    }

    private func evidence(
        _ rawText: String,
        confidence: Double = 0.95,
        reviewState: MenuImportReviewState = .unreviewed
    ) -> MenuImportEvidence {
        MenuImportEvidence(
            rawText: rawText,
            pageIndex: 0,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0.1,
                y: 0.7,
                width: 0.6,
                height: 0.05
            ),
            method: .enhancedOCR,
            confidence: confidence,
            reviewState: reviewState
        )
    }
}
