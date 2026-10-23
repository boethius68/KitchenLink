import XCTest
@testable import kitchenlink

@MainActor
final class KitchenLinkInventoryActionsTests: XCTestCase {

    func testRecordReceiptMovement() throws {
        let model = InventoryOperatorModel()
        InventoryOperatorDemoSeeder.seed(into: model)

        guard let initialFlour = model.groups
            .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
            .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientFlour }) else {
            XCTFail("Flour not found in kitchen group")
            return
        }

        let initialAmount = try initialFlour.physical.amount(in: .mass(.kilogram))

        // Buche 5 kg Wareneingang Mehl
        try model.recordMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .receipt,
            amount: 5,
            note: "Lieferschein #4421"
        )

        let updatedFlour = try XCTUnwrap(
            model.groups
                .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
                .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientFlour })
        )

        XCTAssertEqual(try updatedFlour.physical.amount(in: .mass(.kilogram)), initialAmount + 5)
    }

    func testRecordWasteMovement() throws {
        let model = InventoryOperatorModel()
        InventoryOperatorDemoSeeder.seed(into: model)

        guard let initialTomatoes = model.groups
            .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
            .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientTomato }) else {
            XCTFail("Tomatoes not found in kitchen group")
            return
        }

        let initialAmount = try initialTomatoes.physical.amount(in: .mass(.kilogram))

        // Buche 1 kg Verderb
        try model.recordMovement(
            ingredientID: InventorySandboxFixture.ingredientTomato,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .waste,
            amount: 1,
            note: "Schimmelbefall"
        )

        let updatedTomatoes = try XCTUnwrap(
            model.groups
                .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
                .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientTomato })
        )

        XCTAssertEqual(try updatedTomatoes.physical.amount(in: .mass(.kilogram)), initialAmount - 1)
    }

    func testInventoryAuditCorrection() throws {
        let model = InventoryOperatorModel()
        InventoryOperatorDemoSeeder.seed(into: model)

        // Inventur-Zählung: Mehl wird mit genau 10 kg gezählt
        try model.recordAudit(
            locationID: InventorySandboxFixture.locationKitchen,
            counts: [
                InventorySandboxFixture.ingredientFlour: 10
            ],
            note: "Monatsabschluss-Inventur"
        )

        let updatedFlour = try XCTUnwrap(
            model.groups
                .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
                .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientFlour })
        )

        // Nach der Inventur entspricht der physische Bestand exakt der Zählung
        XCTAssertEqual(try updatedFlour.physical.amount(in: .mass(.kilogram)), 10)
    }

    func testReplenishmentSuggestions() throws {
        let model = InventoryOperatorModel()
        InventoryOperatorDemoSeeder.seed(into: model)

        let suggestions = try model.replenishmentSuggestions(for: InventorySandboxFixture.locationKitchen)
        // Das Demo-Szenario hat Zutaten unter Mindestbestand / Zielbestand
        XCTAssertFalse(suggestions.isEmpty)

        for suggestion in suggestions {
            XCTAssertEqual(suggestion.locationID, InventorySandboxFixture.locationKitchen)
            XCTAssertGreaterThan(suggestion.shortfall.baseAmount, 0)
        }
    }

    func testConsumeOrderRecipeResolution() throws {
        let model = InventoryOperatorModel()
        InventoryOperatorDemoSeeder.seed(into: model)

        guard let initialMozzarella = model.groups
            .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
            .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientMozzarella }) else {
            XCTFail("Mozzarella not found in kitchen group")
            return
        }

        let initialAmount = try initialMozzarella.physical.amount(in: .mass(.kilogram))

        // Bestelle 2x Pizza Margherita
        let orderLine = InventoryOrderLine(
            id: "line-pizza-1",
            salesItemID: InventorySandboxFixture.salesItemPizza,
            quantity: 2,
            reference: "order-test-101"
        )

        let resolution = try model.consumeOrder(
            lines: [orderLine],
            at: InventorySandboxFixture.locationKitchen
        )

        XCTAssertEqual(resolution.consumptions.count, 5) // Mehl, Mozzarella, Tomaten, Basilikum, Olivenöl
        XCTAssertTrue(resolution.unresolved.isEmpty)

        let updatedMozzarella = try XCTUnwrap(
            model.groups
                .first(where: { $0.id == InventorySandboxFixture.locationKitchen })?
                .rows.first(where: { $0.ingredientID == InventorySandboxFixture.ingredientMozzarella })
        )

        // Jede Pizza verbraucht 0.150 kg Mozzarella, bei 2 Pizzen = 0.300 kg
        XCTAssertEqual(try updatedMozzarella.physical.amount(in: .mass(.kilogram)), initialAmount - 0.3)
    }
}
