import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer den Schutz gegen doppelte Umkehrung von Bewegungen.
struct InventoryReversalTests {

    @Test
    func reversalCancelsOriginalConsumption() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let consumption = ledger.movements.first(where: { $0.kind == .consumption })!
        let before = try projection.physicalQuantity(
            ingredientID: consumption.ingredientID,
            locationID: consumption.locationID
        )
        _ = try ledger.reverse(consumption, reason: "Test-Storno")
        let after = try projection.physicalQuantity(
            ingredientID: consumption.ingredientID,
            locationID: consumption.locationID
        )
        #expect(after.baseAmount == before.baseAmount + consumption.quantity.baseAmount)
    }

    @Test
    func doubleReversalIsRejected() throws {
        let (_, ledger) = try freshLedger()
        let consumption = ledger.movements.first(where: { $0.kind == .consumption })!
        _ = try ledger.reverse(consumption, reason: "Storno 1")
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.reverse(consumption, reason: "Storno 2")
        }
    }

    @Test
    func reversalOfReversalIsRejected() throws {
        let (_, ledger) = try freshLedger()
        let consumption = ledger.movements.first(where: { $0.kind == .consumption })!
        let firstReversal = try ledger.reverse(consumption, reason: "Storno")
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.reverse(firstReversal, reason: "Storno des Stornos")
        }
    }

    @Test
    func reversalOfUnknownMovementFails() throws {
        let (_, ledger) = try freshLedger()
        let ghost = StockMovement(
            id: "ghost-id",
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .consumption,
            quantity: try quantity(100, .mass(.gram)),
            reversalOfID: "ghost-original"
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(ghost)
        }
    }

    @Test
    func reversalWithoutOriginalReferenceFails() throws {
        let (_, ledger) = try freshLedger()
        let malformed = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .reversal,
            quantity: try quantity(100, .mass(.gram))
        )
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(malformed)
        }
    }
}

private func freshLedger() throws -> (InventoryCatalog, InventoryLedger) {
    let catalog = try InventoryCatalog(
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
            StockLocation(id: InventorySandboxFixture.locationKitchen, name: "Kueche", kind: .kitchen)
        ],
        suppliers: [],
        purchasePrices: []
    )
    let ledger = InventoryLedger(catalog: catalog)
    _ = try ledger.record(StockMovement.receipt(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(2, .mass(.kilogram))
    ))
    _ = try ledger.record(StockMovement.consumption(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(300, .mass(.gram))
    ))
    return (catalog, ledger)
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
