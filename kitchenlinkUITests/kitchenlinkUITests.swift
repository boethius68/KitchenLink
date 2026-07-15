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
        XCTAssertTrue(app.buttons["business.openLegacySandbox"].exists)
        XCTAssertTrue(app.buttons["business.useLegacyDesign"].exists)

        app.buttons["business.choosePhotos"].tap()

        XCTAssertTrue(app.scrollViews["menuImport.entry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["menuImport.openScanner"].exists)
        XCTAssertTrue(app.buttons["menuImport.choosePhotos"].exists)
    }

    @MainActor
    func testLegacyDesignCanReturnToV2Preview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-legacy"]
        app.launch()

        XCTAssertTrue(app.buttons["business.useV2Design"].waitForExistence(timeout: 5))
        app.buttons["business.useV2Design"].tap()

        XCTAssertTrue(app.buttons["business.useLegacyDesign"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["business.openLegacySandbox"].exists)
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
