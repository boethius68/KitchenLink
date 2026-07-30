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

    /// KL-TABLE-001: Der Tischbereich ist erreichbar, gruppiert nach Bereich,
    /// und der QR-Code eines Tisches steht mit seiner Gast-URL bereit.
    @MainActor
    func testTablesAreReachableAndShowTheirGuestQRCode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2", "--kitchenlink-demo-tables"]
        app.launch()

        let tablesLink = app.buttons["business.openTables"]
        XCTAssertTrue(tablesLink.waitForExistence(timeout: 5))
        scrollTo(tablesLink, in: app)
        tablesLink.tap()

        XCTAssertTrue(app.navigationBars["Tische"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["GASTRAUM"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tables.add"].exists)

        let firstTable = app.buttons["tables.row.1"]
        XCTAssertTrue(firstTable.waitForExistence(timeout: 5))
        firstTable.tap()

        let qrCode = app.descendants(matching: .any)
            .matching(identifier: "tableDetail.qrCode")
            .firstMatch
        XCTAssertTrue(qrCode.waitForExistence(timeout: 5))
        let guestURL = app.staticTexts["tableDetail.guestURL"]
        XCTAssertTrue(guestURL.waitForExistence(timeout: 5))
        // Die Gast-URL muss den Tischparameter tragen — sonst zeigt der
        // gedruckte Code auf die tischlose Karte.
        XCTAssertTrue((guestURL.label).contains("?tisch="))
        XCTAssertTrue(app.buttons["tableDetail.rotate"].exists)
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
        app.launchArguments = [
            "--kitchenlink-design-v2",
            "--kitchenlink-ui-test-default-menu"
        ]
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

        let addButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'menuPreview.add.'")
        ).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        scrollTo(addButton, in: app)
        XCTAssertTrue(addButton.isHittable)
        XCTAssertFalse(app.buttons["Auswählen"].exists)
        XCTAssertGreaterThanOrEqual(addButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(addButton.frame.height, 44)
        let itemID = String(addButton.identifier.dropFirst("menuPreview.add.".count))
        addButton.tap()
        let selectionButton = app.buttons["menuPreview.selection"]
        XCTAssertTrue(selectionButton.waitForExistence(timeout: 2))

        let increaseButton = app.buttons["menuPreview.quantity.\(itemID).increase"]
        XCTAssertTrue(increaseButton.waitForExistence(timeout: 2))
        scrollTo(increaseButton, in: app)
        XCTAssertTrue(increaseButton.isHittable)
        increaseButton.tap()

        let quantityValue = app.staticTexts["menuPreview.quantity.\(itemID).value"]
        XCTAssertTrue(quantityValue.waitForExistence(timeout: 2))
        let quantityIsTwo = expectation(
            for: NSPredicate(format: "label == '2'"),
            evaluatedWith: quantityValue
        )
        wait(for: [quantityIsTwo], timeout: 2)

        let decreaseButton = app.buttons["menuPreview.quantity.\(itemID).decrease"]
        XCTAssertTrue(decreaseButton.waitForExistence(timeout: 2))
        scrollTo(decreaseButton, in: app)
        XCTAssertTrue(decreaseButton.isHittable)
        XCTAssertGreaterThanOrEqual(decreaseButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(decreaseButton.frame.height, 44)

        // Trifft bewusst den linken Rand statt das Minus-Glyph. So schützt der
        // Test die tatsächliche 44-Punkt-Touchfläche und nicht nur den Rahmen.
        decreaseButton.coordinate(
            withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)
        ).tap()
        let quantityIsOne = expectation(
            for: NSPredicate(format: "label == '1'"),
            evaluatedWith: quantityValue
        )
        wait(for: [quantityIsOne], timeout: 2)
        XCTAssertTrue(selectionButton.exists)

        decreaseButton.coordinate(
            withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)
        ).tap()
        let selectionRemoved = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: selectionButton
        )
        wait(for: [selectionRemoved], timeout: 2)
    }

    @MainActor
    func testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--kitchenlink-design-v2",
            "--kitchenlink-ui-test-default-menu"
        ]
        app.launch()

        let manualEditor = app.buttons["business.editMenuManually"]
        XCTAssertTrue(manualEditor.waitForExistence(timeout: 5))
        scrollTo(manualEditor, in: app)
        manualEditor.tap()

        let preview = app.buttons["menuEditor.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        scrollTo(preview, in: app)
        preview.tap()

        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Gesamt:'"))
                .firstMatch.waitForExistence(timeout: 3)
        )

        let burgerName = app.staticTexts["menuPreview.itemName.f-burger"]
        var remainingSwipes = 10
        while !burgerName.exists && remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
        XCTAssertTrue(burgerName.exists)

        // Gesetzliche Vorgabe: Kennzeichnungen werden nie gekürzt. Die Symbole
        // stehen im Fluss der Beschreibung und bilden ein einziges Tap-Ziel;
        // dessen Accessibility-Label trägt Beschreibung und alle Klartexte, und
        // der Tap öffnet die vollständige Liste.
        let declarationRow = app.buttons["foodDeclaration.row.f-burger"]
        XCTAssertTrue(declarationRow.waitForExistence(timeout: 2))
        scrollTo(declarationRow, in: app)
        XCTAssertTrue(declarationRow.isHittable)
        XCTAssertTrue(declarationRow.label.contains("Rind, Cheddar, Haus-Sauce"))
        XCTAssertTrue(declarationRow.label.contains("Glutenhaltiges Getreide"))
        XCTAssertTrue(declarationRow.label.contains("mit Phosphat"))
        declarationRow.tap()

        XCTAssertTrue(app.navigationBars["Kennzeichnungen"].waitForExistence(timeout: 3))
        let expectedCodes = [
            "a", "c", "g", "i", "j", "k", "l",
            "farbstoff", "konserviert", "geschmacksverstaerker", "phosphat"
        ]
        for code in expectedCodes {
            let entry = app.buttons["foodDeclaration.list.\(code)"].firstMatch
            var listSwipes = 4
            while !entry.isHittable && listSwipes > 0 {
                app.swipeUp()
                listSwipes -= 1
            }
            XCTAssertTrue(entry.exists, "Kennzeichnung \(code) fehlt in der Klartextliste")
        }

        // Ein Eintrag öffnet weiterhin die ausführliche Erklärung.
        let sesame = app.buttons["foodDeclaration.list.k"].firstMatch
        XCTAssertTrue(sesame.isHittable)
        sesame.tap()
        XCTAssertTrue(app.staticTexts["foodDeclaration.detail.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["foodDeclaration.detail.title"].label, "Sesamsamen")
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
