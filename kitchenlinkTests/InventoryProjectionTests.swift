import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer die Projektion von physischem, reserviertem und
/// verfuegbarem Bestand.
struct InventoryProjectionTests {

    @Test
    func physicalEqualsSumOfMovements() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let physical = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        // 5 kg receipt - 3 x 250 g consumption = 4.250 kg
        #expect(physical.baseAmount == Decimal(string: "4250.000")!)
    }

    @Test
    func reservedIsReservationsMinusReleases() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let reserved = try projection.reservedQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        #expect(reserved.baseAmount == Decimal(string: "500.000")!)
    }

    @Test
    func availableEqualsPhysicalMinusReserved() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let available = try projection.availableQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        // 4250 g physical - 500 g reserved = 3750 g available
        #expect(available.baseAmount == Decimal(string: "3750.000")!)
    }

    @Test
    func projectionStaysPerLocation() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let kitchen = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientRedWine,
            locationID: InventorySandboxFixture.locationKitchen
        )
        let bar = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientRedWine,
            locationID: InventorySandboxFixture.locationBar
        )
        #expect(kitchen.baseAmount == 0)
        #expect(bar.baseAmount == Decimal(string: "6000.000")!)
    }

    @Test
    func reversalRestoresPhysicalStock() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let consumptionID = ledger.movements.first(where: {
            $0.kind == .consumption && $0.ingredientID == InventorySandboxFixture.ingredientFlour
        })!.id
        let before = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        _ = try ledger.reverse(ledger.movement(id: consumptionID)!, reason: "Testkorrektur")
        let after = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        #expect(after.baseAmount == before.baseAmount + Decimal(string: "250.000")!)
    }

    @Test
    func negativePhysicalIsNotClamped() throws {
        let (catalog, ledger) = try freshLedger()
        // 5 kg zusaetzlicher Verbrauch ohne Rezept: physical wird negativ
        let big = try StockMovement.consumption(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen,
            quantity: try quantity(7, .mass(.kilogram))
        )
        _ = try ledger.record(big)
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let available = try projection.availableQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        // 5000 g receipt - 750 g consumption - 7000 g zusaetzlich = -2750 g physical,
        // minus 500 g reserved = -3250 g available, nicht geclampt
        #expect(available.baseAmount == Decimal(string: "-3250.000")!)
    }

    @Test
    func snapshotCoversAllIngredientLocationPairs() throws {
        let (catalog, ledger) = try freshLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let snapshot = try projection.snapshot()
        let expectedPairs = catalog.ingredients.count * catalog.locations.count
        #expect(snapshot.count == expectedPairs)
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
                targetStock: try quantity(5_000, .mass(.gram))
            ),
            try Ingredient(
                id: InventorySandboxFixture.ingredientRedWine,
                name: "Rotwein",
                baseUnit: .volume(.milliliter),
                minimumStock: try quantity(1_000, .volume(.milliliter)),
                targetStock: try quantity(3_000, .volume(.milliliter))
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
    let ledger = InventoryLedger(catalog: catalog)
    _ = try ledger.record(StockMovement.receipt(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(5, .mass(.kilogram))
    ))
    _ = try ledger.record(StockMovement.receipt(
        ingredientID: InventorySandboxFixture.ingredientRedWine,
        locationID: InventorySandboxFixture.locationBar,
        quantity: try quantity(6, .volume(.liter))
    ))
    _ = try ledger.record(StockMovement.consumption(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(250, .mass(.gram))
    ))
    _ = try ledger.record(StockMovement.consumption(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(250, .mass(.gram))
    ))
    _ = try ledger.record(StockMovement.consumption(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(250, .mass(.gram))
    ))
    _ = try ledger.record(StockMovement.reservation(
        ingredientID: InventorySandboxFixture.ingredientFlour,
        locationID: InventorySandboxFixture.locationKitchen,
        quantity: try quantity(500, .mass(.gram))
    ))
    return (catalog, ledger)
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
