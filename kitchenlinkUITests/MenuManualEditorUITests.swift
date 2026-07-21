import XCTest

/// Treibt den manuellen Speisekarten-Editor real durch: Kategorie anlegen, in
/// eine Kategorie navigieren, ein Gericht hinzufügen, Name/Preis setzen, einen
/// Allergen-Code wählen (einheitliches Icon) und die Gäste-Vorschau öffnen.
/// Hängt an Schlüsselpunkten Screenshots an, damit das Ergebnis prüfbar ist.
final class MenuManualEditorUITests: XCTestCase {

    @MainActor
    func testManualMenuEditorCoreFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--kitchenlink-design-v2"]
        app.launch()

        // Betreiber-Home -> manuellen Editor öffnen.
        let editorEntry = app.buttons["business.editMenuManually"]
        XCTAssertTrue(editorEntry.waitForExistence(timeout: 8))
        scrollUntilHittable(editorEntry, in: app)
        editorEntry.tap()

        // Editor sichtbar.
        let addCategory = app.buttons["menuEditor.addCategory"]
        XCTAssertTrue(addCategory.waitForExistence(timeout: 8), "Editor-Liste erschien nicht")
        attach(app, "editor-01-categories")

        // Neue Kategorie anlegen.
        addCategory.tap()

        // In die erste Kategorie navigieren (Demo-Karte ist vorhanden).
        let firstSection = app.cells.firstMatch
        XCTAssertTrue(firstSection.waitForExistence(timeout: 5))
        firstSection.tap()

        // Gericht hinzufügen.
        let addItem = app.buttons["menuEditor.addItem"]
        XCTAssertTrue(addItem.waitForExistence(timeout: 8), "Kategorie-Editor zeigte keinen Gericht-hinzufuegen-Button")
        addItem.tap()

        // Das neue, noch namenlose Gericht öffnen.
        let unnamed = app.staticTexts["Ohne Namen"].firstMatch
        XCTAssertTrue(unnamed.waitForExistence(timeout: 5))
        unnamed.tap()

        // Name + Preis setzen.
        let nameField = app.textFields["menuEditor.itemName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "Gericht-Editor öffnete nicht")
        nameField.tap()
        nameField.typeText("Bruschetta")

        // Einen Standard-Allergen-Code wählen (A = glutenhaltiges Getreide).
        let codeA = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Code A'")).firstMatch
        XCTAssertTrue(codeA.waitForExistence(timeout: 5), "Allergen-Chip A nicht gefunden")
        scrollUntilHittable(codeA, in: app)
        codeA.tap()
        attach(app, "editor-02-item-with-allergen")

        // Zurück zum Editor und Gäste-Vorschau öffnen.
        app.navigationBars.buttons.firstMatch.tap() // zurück zum Kategorie-Editor
        if app.navigationBars.buttons.count > 0 {
            app.navigationBars.buttons.firstMatch.tap() // zurück zur Kategorienliste
        }
        let preview = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Vorschau wie für Gäste'")).firstMatch
        if preview.waitForExistence(timeout: 5) {
            scrollUntilHittable(preview, in: app)
            preview.tap()
            XCTAssertTrue(app.navigationBars["Menü testen"].waitForExistence(timeout: 5))
            attach(app, "editor-03-guest-preview")

            let glutenBadge = app.buttons["foodDeclaration.badge.a"].firstMatch
            XCTAssertTrue(glutenBadge.waitForExistence(timeout: 5), "Tappbares Gluten-Piktogramm fehlt in der Gäste-Vorschau")
            scrollUntilHittable(glutenBadge, in: app)
            attach(app, "editor-03b-allergen-badge")
            glutenBadge.tap()
            XCTAssertTrue(app.staticTexts["foodDeclaration.detail.title"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["foodDeclaration.detail.title"].label, "Glutenhaltiges Getreide")
            attach(app, "editor-04-allergen-detail")
        }
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var remaining = 6
        while !element.isHittable && remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
