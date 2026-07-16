import XCTest

/// On-demand visual-check harness for the V2 reference areas. Skipped unless
/// requested through `TEST_RUNNER_KITCHENLINK_CAPTURE_V2_SCREENSHOTS=1` so the
/// regular suite stays fast. `TEST_RUNNER_KITCHENLINK_APPEARANCE=dark` forces
/// the dark appearance through the sandbox launch argument.
final class kitchenlinkV2ScreenshotTests: XCTestCase {

    @MainActor
    func testCaptureTodayAndKitchenWithDemoService() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(
            environment["KITCHENLINK_CAPTURE_V2_SCREENSHOTS"] == "1",
            "Set TEST_RUNNER_KITCHENLINK_CAPTURE_V2_SCREENSHOTS=1 to capture screenshots."
        )

        let appearance = environment["KITCHENLINK_APPEARANCE"] ?? "light"
        let app = XCUIApplication()
        app.launchArguments = [
            "--kitchenlink-design-v2",
            "--kitchenlink-demo-service",
            appearance == "dark"
                ? "--kitchenlink-appearance-dark"
                : "--kitchenlink-appearance-light"
        ]
        app.launch()

        let todayLink = app.buttons["business.openToday"]
        XCTAssertTrue(todayLink.waitForExistence(timeout: 5))
        scrollUntilHittable(todayLink, in: app)
        todayLink.tap()

        XCTAssertTrue(app.buttons["today.primaryAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6 offen"].waitForExistence(timeout: 15))
        attachScreenshot(of: app, named: "today-\(appearance)")

        app.navigationBars.buttons.firstMatch.tap()

        let kitchenLink = app.buttons["business.openKitchen"]
        XCTAssertTrue(kitchenLink.waitForExistence(timeout: 5))
        scrollUntilHittable(kitchenLink, in: app)
        kitchenLink.tap()

        XCTAssertTrue(app.otherElements["kitchen.connection"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["6 offen"].waitForExistence(timeout: 10)
                || app.staticTexts.matching(
                    NSPredicate(format: "label ENDSWITH '6 offen'")
                ).firstMatch.waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "kitchen-\(appearance)")
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var remainingSwipes = 4
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
