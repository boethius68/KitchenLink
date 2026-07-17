import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer die deterministische Sandbox-Fixture.
struct InventorySandboxFixtureTests {

    @Test
    func fixtureHasTwelveIngredientsFourRecipesTwoLocations() throws {
        let catalog = try InventorySandboxFixture.makeCatalog()
        #expect(catalog.ingredients.count == 12)
        #expect(catalog.recipes.count == 4)
        #expect(catalog.locations.count == 2)
        #expect(catalog.salesItems.count == 5)
    }

    @Test
    func fixtureLedgerExposesAllMovementKinds() throws {
        let (_, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let kinds = Set(ledger.movements.map(\.kind))
        #expect(kinds.contains(.receipt))
        #expect(kinds.contains(.consumption))
        #expect(kinds.contains(.waste))
        #expect(kinds.contains(.transferOut))
        #expect(kinds.contains(.transferIn))
    }

    @Test
    func fixtureProjectionsMatchExpectedStockLevels() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let kitchenFlour = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationKitchen
        )
        let barFlour = try projection.physicalQuantity(
            ingredientID: InventorySandboxFixture.ingredientFlour,
            locationID: InventorySandboxFixture.locationBar
        )
        // 5 kg receipt - 3 * 0.250 (Pizza) - 2 * 0.180 (Spaghetti) - 1.0 (TransferOut) = 2.890 kg
        #expect(kitchenFlour.baseAmount == Decimal(string: "2890.000")!)
        #expect(barFlour.baseAmount == Decimal(string: "1000.000")!)
    }

    @Test
    func catalogRejectsDuplicateComponentInRecipe() throws {
        let flour = try Ingredient(
            id: InventorySandboxFixture.ingredientFlour,
            name: "Mehl",
            baseUnit: .mass(.gram),
            minimumStock: try quantity(500, .mass(.gram)),
            targetStock: try quantity(2_000, .mass(.gram))
        )
        let recipe = Recipe(
            id: "recipe-bad",
            name: "Doppelmehl",
            components: [
                try RecipeComponent(ingredientID: flour.id, quantity: try quantity(100, .mass(.gram))),
                try RecipeComponent(ingredientID: flour.id, quantity: try quantity(50, .mass(.gram)))
            ]
        )
        #expect(throws: InventoryModelError.self) {
            _ = try InventoryCatalog(
                ingredients: [flour],
                salesItems: [],
                recipes: [recipe],
                locations: [StockLocation(id: "loc", name: "L", kind: .kitchen)],
                suppliers: [],
                purchasePrices: []
            )
        }
    }

    @Test
    func catalogRejectsMinimumAboveTarget() throws {
        #expect(throws: InventoryModelError.self) {
            _ = try Ingredient(
                id: InventorySandboxFixture.ingredientFlour,
                name: "Mehl",
                baseUnit: .mass(.gram),
                minimumStock: try quantity(10, .mass(.kilogram)),
                targetStock: try quantity(1, .mass(.kilogram))
            )
        }
    }

    @Test
    func purchasePriceRejectsInvalidCurrency() throws {
        #expect(throws: InventoryModelError.self) {
            _ = try PurchasePrice(
                supplierID: "supplier",
                ingredientID: "ingredient",
                pricePerBaseUnit: 1,
                currency: "EURO"
            )
        }
    }
}

private func quantity(_ value: Int, _ unit: MeasurementUnit) throws -> InventoryQuantity {
    try InventoryQuantity(amount: Decimal(value), unit: unit)
}
