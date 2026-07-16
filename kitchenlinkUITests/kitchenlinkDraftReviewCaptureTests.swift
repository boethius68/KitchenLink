import XCTest

/// On-demand end-to-end check of the evidence-based draft review: real
/// fixture import, resolving unpriced candidates (one corrected, the rest
/// discarded) and the explicit conversion into the sandbox menu. Skipped
/// unless `TEST_RUNNER_KITCHENLINK_CAPTURE_DRAFT_REVIEW=1` because the OCR
/// pass over a full fixture takes minutes.
final class kitchenlinkDraftReviewCaptureTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFixtureImportDraftReviewAndConversion() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KITCHENLINK_CAPTURE_DRAFT_REVIEW"] == "1",
            "Set TEST_RUNNER_KITCHENLINK_CAPTURE_DRAFT_REVIEW=1 to run the slow OCR flow."
        )

        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2"]
        app.launch()

        // Import the Alexxanders fixture: it produces unpriced candidates.
        XCTAssertTrue(app.buttons["business.choosePhotos"].waitForExistence(timeout: 5))
        app.buttons["business.choosePhotos"].tap()
        XCTAssertTrue(app.buttons["menuImport.demoFixture"].waitForExistence(timeout: 5))
        app.buttons["menuImport.demoFixture"].tap()

        let fixtureChoice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Alexxanders'")
        ).firstMatch
        XCTAssertTrue(fixtureChoice.waitForExistence(timeout: 5))
        fixtureChoice.tap()

        // The legacy review sheet auto-presents once the import finishes.
        let legacySheetButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Menü ersetzen' OR label CONTAINS 'Sandbox-Menü verwenden'")
        ).firstMatch
        XCTAssertTrue(legacySheetButton.waitForExistence(timeout: 300))
        app.swipeDown(velocity: .fast)

        let reviewDraftButton = app.buttons["menuImport.reviewDraft"]
        XCTAssertTrue(reviewDraftButton.waitForExistence(timeout: 10))
        scrollUntilHittable(reviewDraftButton, in: app)
        reviewDraftButton.tap()

        let convertButton = app.buttons["draftReview.convert"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: 10))
        XCTAssertFalse(
            convertButton.isEnabled,
            "Conversion must stay locked while candidates are unresolved."
        )
        attachScreenshot(of: app, named: "draft-review-open-items")

        // Resolve every open candidate: keep already-priced ones, give the
        // first unpriced one a price, discard the remaining unpriced ones.
        var didPriceACandidate = false
        var didCaptureDetail = false
        var remainingResolutions = 40

        while remainingResolutions > 0 {
            let openEntry = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'draftReview.entry.' AND value == 'offen'")
            ).firstMatch
            guard openEntry.waitForExistence(timeout: 3) else { break }

            scrollUntilHittable(openEntry, in: app)
            openEntry.tap()

            let acceptButton = app.buttons["draftReview.detail.accept"]
            XCTAssertTrue(acceptButton.waitForExistence(timeout: 5))
            if !didCaptureDetail {
                didCaptureDetail = true
                attachScreenshot(of: app, named: "draft-review-detail")
            }

            let priceField = app.textFields["draftReview.detail.price"]
            XCTAssertTrue(priceField.waitForExistence(timeout: 5))
            let currentPrice = (priceField.value as? String) ?? ""
            let hasPrice = !currentPrice.isEmpty && currentPrice != "z. B. 12,90"

            if hasPrice {
                scrollUntilHittable(acceptButton, in: app)
                acceptButton.tap()
            } else if !didPriceACandidate {
                scrollUntilHittable(priceField, in: app)
                priceField.tap()
                priceField.typeText("9,90")
                didPriceACandidate = true
                scrollUntilHittable(acceptButton, in: app)
                acceptButton.tap()
            } else {
                let rejectButton = app.buttons["draftReview.detail.reject"]
                scrollUntilHittable(rejectButton, in: app)
                rejectButton.tap()
            }

            XCTAssertTrue(
                acceptButton.waitForNonExistence(timeout: 5),
                "Detail sheet should close after resolving an entry."
            )
            remainingResolutions -= 1
        }

        XCTAssertTrue(didPriceACandidate, "Expected at least one unpriced open candidate.")
        XCTAssertTrue(convertButton.isEnabled, "All candidates resolved; conversion must unlock.")
        attachScreenshot(of: app, named: "draft-review-resolved")

        convertButton.tap()

        // The reviewed menu is applied; the result card switches state.
        XCTAssertTrue(app.buttons["menuImport.testMenu"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "draft-review-applied")
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var remainingSwipes = 6
        while !element.isHittable && remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
