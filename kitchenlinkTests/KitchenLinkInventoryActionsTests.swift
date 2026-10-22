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

        let initialAmount = initialFlour.physical.amount

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

        XCTAssertEqual(updatedFlour.physical.amount, initialAmount + 5)
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

        let initialAmount = initialTomatoes.physical.amount

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

        XCTAssertEqual(updatedTomatoes.physical.amount, initialAmount - 1)
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
        XCTAssertEqual(updatedFlour.physical.amount, 10)
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
}
