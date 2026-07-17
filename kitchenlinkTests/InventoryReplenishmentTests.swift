import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer die erklaerbare Fehlbestandswarnung und den Bestellvorschlag.
struct InventoryReplenishmentTests {

    @Test
    func belowMinimumTriggersWarningWithExplanation() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)
        // Basilikum hat Mindest 50 g, Verderb entfernt 200 g bei 150 g receipt -> -50 g
        let evaluation = try advisor.evaluate(
            ingredientID: InventorySandboxFixture.ingredientBasil,
            locationID: InventorySandboxFixture.locationKitchen
        )
        #expect(evaluation.severity == .critical)
        #expect(evaluation.explanation.contains("Kritischer Fehlbestand"))
    }

    @Test
    func replenishmentSuggestionReachesTarget() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)
        let evaluation = try advisor.evaluate(
            ingredientID: InventorySandboxFixture.ingredientBasil,
            locationID: InventorySandboxFixture.locationKitchen
        )
        let suggestion = advisor.suggestion(for: evaluation)
        let ingredient = try catalog.ingredient(id: InventorySandboxFixture.ingredientBasil)
        let expectedShortfall = try ingredient.targetStock - evaluation.physical
        #expect(suggestion != nil)
        #expect(suggestion?.target == ingredient.targetStock)
        #expect(suggestion?.shortfall == expectedShortfall)
        #expect(suggestion?.shortfall.baseAmount == expectedShortfall.baseAmount)
    }

    @Test
    func suggestionIsNilWhenAboveTarget() throws {
        let (catalog, ledger) = try freshAboveTargetLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)
        let evaluation = try advisor.evaluate(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        #expect(evaluation.severity == .ok)
        #expect(advisor.suggestion(for: evaluation) == nil)
    }

    @Test
    func evaluationAcrossLocationReportsPerLocation() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)
        let kitchen = try advisor.evaluate(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        let bar = try advisor.evaluate(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationBar
        )
        #expect(kitchen.physical > bar.physical)
        #expect(bar.physical.baseAmount == Decimal(string: "1000.000")!)
    }
}

private func freshAboveTargetLedger() throws -> (InventoryCatalog, InventoryLedger) {
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
        quantity: try quantity(3, .mass(.kilogram))
    ))
    return (catalog, ledger)
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
