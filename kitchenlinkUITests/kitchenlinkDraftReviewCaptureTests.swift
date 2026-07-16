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

        let nextOpenButton = app.buttons["draftReview.nextOpen"]
        XCTAssertTrue(nextOpenButton.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["draftReview.convert"].exists)
        attachScreenshot(of: app, named: "draft-review-open-items")

        // The explicit batch action accepts only convertible fixed-price
        // candidates. The two unpriced fixture candidates must stay open.
        let acceptAllPricedButton = app.buttons["draftReview.acceptAllPriced"]
        XCTAssertTrue(acceptAllPricedButton.waitForExistence(timeout: 5))
        acceptAllPricedButton.tap()

        let twoOpen = NSPredicate(format: "label CONTAINS '2 zu klären'")
        expectation(for: twoOpen, evaluatedWith: app.staticTexts["draftReview.summary"])
        waitForExpectations(timeout: 5)

        // Correct one unpriced candidate.
        nextOpenButton.tap()
        let acceptButton = app.buttons["draftReview.detail.accept"]
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 5))
        XCTAssertFalse(acceptButton.isEnabled)
        attachScreenshot(of: app, named: "draft-review-detail")

        let priceField = app.textFields["draftReview.detail.price"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        scrollUntilHittable(priceField, in: app)
        priceField.tap()
        priceField.typeText("9,90")

        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: acceptButton
        )
        waitForExpectations(timeout: 5)
        scrollUntilHittable(acceptButton, in: app)
        acceptButton.tap()
        XCTAssertTrue(acceptButton.waitForNonExistence(timeout: 5))

        // Discard the remaining unpriced structural candidate.
        XCTAssertTrue(nextOpenButton.waitForExistence(timeout: 5))
        nextOpenButton.tap()
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 5))
        XCTAssertFalse(acceptButton.isEnabled)
        let rejectButton = app.buttons["draftReview.detail.reject"]
        scrollUntilHittable(rejectButton, in: app)
        rejectButton.tap()
        XCTAssertTrue(acceptButton.waitForNonExistence(timeout: 5))

        let convertButton = app.buttons["draftReview.convert"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: 5))
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
        let scrollView = app.scrollViews.firstMatch
        while !element.isHittable && remainingSwipes > 0 {
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
            remainingSwipes -= 1
        }
        XCTAssertTrue(element.isHittable, "Expected element to become hittable after scrolling.")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
