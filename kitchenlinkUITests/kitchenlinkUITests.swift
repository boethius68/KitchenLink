//
//  kitchenlinkUITests.swift
//  kitchenlinkUITests
//
//  Created by Philipp Horn on 3/14/25.
//

import XCTest

final class kitchenlinkUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testBusinessAppLaunchesIntoScanFirstFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2"]
        app.launch()

        XCTAssertTrue(app.staticTexts["business.welcomeTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["business.scanMenu"].exists)

        XCTAssertFalse(app.buttons["business.devTools"].exists)
        XCTAssertFalse(app.buttons["business.openLegacySandbox"].exists)
        XCTAssertFalse(app.buttons["business.useLegacyDesign"].exists)

        scrollTo(app.buttons["business.choosePhotos"], in: app)
        app.buttons["business.choosePhotos"].tap()

        XCTAssertTrue(app.scrollViews["menuImport.entry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["menuImport.openScanner"].exists)
        XCTAssertTrue(app.buttons["menuImport.choosePhotos"].exists)
        XCTAssertTrue(app.buttons["menuImport.demoFixture"].exists)
    }

    @MainActor
    func testTodayAndKitchenAreReachableFromV2Home() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2"]
        app.launch()

        let todayLink = app.buttons["business.openToday"]
        XCTAssertTrue(todayLink.waitForExistence(timeout: 5))
        scrollTo(todayLink, in: app)
        todayLink.tap()

        XCTAssertTrue(app.buttons["today.primaryAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.simulateDemo"].exists)
        XCTAssertTrue(app.otherElements["today.connection"].exists)

        app.navigationBars.buttons.firstMatch.tap()

        let kitchenLink = app.buttons["business.openKitchen"]
        XCTAssertTrue(kitchenLink.waitForExistence(timeout: 5))
        scrollTo(kitchenLink, in: app)
        kitchenLink.tap()

        XCTAssertTrue(app.otherElements["kitchen.connection"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLocalServiceNavigationRespondsBeforeHubStartup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2"]
        app.launch()

        let localServiceLink = app.buttons["business.openLocalOperations"]
        XCTAssertTrue(localServiceLink.waitForExistence(timeout: 5))
        scrollTo(localServiceLink, in: app)
        localServiceLink.tap()

        XCTAssertTrue(app.navigationBars["Service"].waitForExistence(timeout: 1))
        XCTAssertTrue(
            app.staticTexts["LOKALER FALLBACK AUF DIESEM IPHONE"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testRetiredLegacyLaunchArgumentStillShowsCurrentProduct() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-legacy"]
        app.launch()

        XCTAssertTrue(app.staticTexts["business.welcomeTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["business.scanMenu"].exists)
        XCTAssertFalse(app.buttons["business.useV2Design"].exists)
        XCTAssertFalse(app.buttons["business.useLegacyDesign"].exists)
        XCTAssertFalse(app.buttons["business.openLegacySandbox"].exists)
    }

    @MainActor
    func testImportOffersThreeDocumentedTestMenus() throws {
        let app = XCUIApplication()
        app.launch()

        let choosePhotos = app.buttons["business.choosePhotos"]
        XCTAssertTrue(choosePhotos.waitForExistence(timeout: 5))
        scrollTo(choosePhotos, in: app)
        choosePhotos.tap()

        let demoFixture = app.buttons["menuImport.demoFixture"]
        XCTAssertTrue(demoFixture.waitForExistence(timeout: 3))
        scrollTo(demoFixture, in: app)
        demoFixture.tap()

        XCTAssertTrue(app.navigationBars["Testkarte wählen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["menuImport.demoFixture.kitchenlink-pruefkueche"].exists)
        XCTAssertTrue(app.buttons["menuImport.demoFixture.lichtburg-berlin"].exists)
        XCTAssertTrue(app.buttons["menuImport.demoFixture.alexxanders-chemnitz"].exists)
    }

    @MainActor
    func testGuestPreviewUsesCountersAndCompactQuantityControl() throws {
        let app = XCUIApplication()
        app.launch()

        let manualEditor = app.buttons["business.editMenuManually"]
        XCTAssertTrue(manualEditor.waitForExistence(timeout: 5))
        scrollTo(manualEditor, in: app)
        manualEditor.tap()

        let preview = app.buttons["menuEditor.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        scrollTo(preview, in: app)
        preview.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Getränke:'")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Speisen:'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Gesamt:'")).firstMatch.exists)

        let addButton = app.buttons["Hinzufügen"].firstMatch
        XCTAssertTrue(addButton.exists)
        XCTAssertFalse(app.buttons["Auswählen"].exists)
        XCTAssertGreaterThanOrEqual(addButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(addButton.frame.height, 44)
        addButton.tap()
        XCTAssertTrue(app.buttons["menuPreview.selection"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var remainingSwipes = 4
        while !element.isHittable && remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
