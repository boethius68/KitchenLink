import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer Idempotenz, Aufzeichnungsreihenfolge und Validierung im
/// append-only Bestandsledger.
struct InventoryLedgerTests {

    @Test
    func recordRejectsUnknownIngredient() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let movement = try StockMovement.receipt(
            ingredientID: "missing-ingredient",
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(1, .count)
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(movement)
        }
    }

    @Test
    func recordRejectsUnknownLocation() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let movement = try StockMovement.receipt(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: "ghost-location",
            quantity: try quantity(1, .mass(.gram))
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(movement)
        }
    }

    @Test
    func recordRejectsUnitMismatchWithIngredient() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let movement = try StockMovement.receipt(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(1, .volume(.liter))
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(movement)
        }
    }

    @Test
    func recordRejectsTransferWithoutGroup() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let movement = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .transferOut,
            quantity: try quantity(1, .mass(.gram))
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(movement)
        }
    }

    @Test
    func sameIdempotencyKeySameContentIsIdempotent() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let first = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(200, .mass(.gram)),
            reference: "order-1",
            idempotencyKey: "consumption:order-1:flour"
        )
        let second = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(200, .mass(.gram)),
            reference: "order-1",
            idempotencyKey: "consumption:order-1:flour"
        )
        let stored = try ledger.record(first)
        let replayed = try ledger.record(second)
        #expect(stored.id == replayed.id)
        #expect(ledger.movements.count == 1)
    }

    @Test
    func sameIdempotencyKeyDifferentContentThrowsConflict() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let first = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(200, .mass(.gram)),
            reference: "order-1",
            idempotencyKey: "consumption:order-1:flour"
        )
        let second = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(300, .mass(.gram)),
            reference: "order-1",
            idempotencyKey: "consumption:order-1:flour"
        )
        _ = try ledger.record(first)
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(second)
        }
    }

    @Test
    func differentIdempotencyKeysForSameContentBothRecord() throws {
        let catalog = try minimalCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let first = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(200, .mass(.gram)),
            idempotencyKey: "consumption:order-1:flour"
        )
        let second = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(200, .mass(.gram)),
            idempotencyKey: "consumption:order-2:flour"
        )
        _ = try ledger.record(first)
        _ = try ledger.record(second)
        #expect(ledger.movements.count == 2)
    }

    @Test
    func orderLineIdempotencyKeyIsStable() {
        let key = InventoryRecipeResolver.idempotencyKey(
            reference: "order-123", lineID: "line-1", ingredientID: "ingredient-flour"
        )
        #expect(key == "consumption:order-123:line-1:ingredient-flour")
    }
}

/// Kompakter Katalog fuer Ledger-Tests: nur Mehl an der Kueche.
private func minimalCatalog() throws -> InventoryCatalog {
    try InventoryCatalog(
        ingredients: [
            try Ingredient(
                id: InventorySandboxFixture.ingredientFlour,
                name: "Mehl",
                baseUnit: .mass(.gram),
                minimumStock: try quantity(500, .mass(.gram)),
                targetStock: try quantity(2_000, .mass(.gram))
            )
        ],
        salesItems: [],
        recipes: [],
        locations: [
            StockLocation(id: InventorySandboxFixture.locationKitchen, name: "Kueche", kind: .kitchen),
            StockLocation(id: InventorySandboxFixture.locationBar, name: "Bar", kind: .bar)
        ],
        suppliers: [],
        purchasePrices: []
    )
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
