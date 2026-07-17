import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer die ausgeglichenen Transfers zwischen Lagerorten.
struct InventoryTransferTests {

    @Test
    func transferMovesStockBetweenLocations() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        // Fixture transferiert 1 kg Mehl von Kueche -> Bar
        let kitchenFlour = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        let barFlour = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationBar
        )
        // 5 kg receipt - 3 x 250 g (Pizza) - 2 x 180 g (Spaghetti) - 1 kg (TransferOut) = 2.890 kg
        #expect(kitchenFlour.baseAmount == Decimal(string: "2890.000")!)
        #expect(barFlour.baseAmount == Decimal(string: "1000.000")!)
    }

    @Test
    func transferRequiresMatchingQuantityAndIngredient() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let group = "transfer-mismatch-1"
        let out = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .transferOut,
            quantity: try quantity(1, .mass(.kilogram)),
            transferGroupID: group
        )
        let wrongIngredient = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientMozzarella,
            locationID: InventorySandboxFixture.locationBar,
            kind: .transferIn,
            quantity: try quantity(1, .mass(.kilogram)),
            transferGroupID: group
        )
        _ = try ledger.record(out)
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(wrongIngredient)
        }
    }

    @Test
    func transferRejectsIdenticalSourceAndTarget() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let group = "transfer-same-location"
        let first = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .transferOut,
            quantity: try quantity(500, .mass(.gram)),
            transferGroupID: group
        )
        let second = StockMovement(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            kind: .transferIn,
            quantity: try quantity(500, .mass(.gram)),
            transferGroupID: group
        )
        _ = try ledger.record(first)
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.record(second)
        }
    }

    @Test
    func transferGroupReversalReturnsStock() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let group = "transfer-flour-2024-001"
        let out = ledger.movements.first(where: {
            $0.kind == .transferOut && $0.transferGroupID == group
        })!
        let inMovement = ledger.movements.first(where: {
            $0.kind == .transferIn && $0.transferGroupID == group
        })!
        let before = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        _ = try ledger.reverse(out, reason: "Storno")
        _ = try ledger.reverse(inMovement, reason: "Storno")
        let after = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        #expect(after.baseAmount == before.baseAmount + Decimal(string: "1000.000")!)
    }

    @Test
    func reversedTransferGroupRejectsSecondReversal() throws {
        let (_, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let group = "transfer-flour-2024-001"
        let out = ledger.movements.first(where: {
            $0.kind == .transferOut && $0.transferGroupID == group
        })!
        _ = try ledger.reverse(out, reason: "Storno")
        #expect(throws: InventoryLedgerError.self) {
            _ = try ledger.reverse(out, reason: "Doppelter Storno")
        }
    }
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
