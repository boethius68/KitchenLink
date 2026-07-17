import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer die Aufloesung von Bestellpositionen in Verbrauchsbewegungen.
struct InventoryRecipeTests {

    @Test
    func recipeScalesLinearlyWithOrderQuantity() throws {
        let (catalog, _) = try InventorySandboxFixture.makePopulatedLedger()
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let line = InventoryOrderLine(
            id: "line-pizza",
            salesItemID: InventorySandboxFixture.salesItemPizza,
            quantity: 2,
            reference: "order-x"
        )
        let resolution = try resolver.resolve(
            lines: [line],
            at: InventorySandboxFixture.locationKitchen
        )
        // Pizza Margherita: 0.250 kg flour, 0.150 kg mozzarella, 0.120 kg tomaten,
        // 5 g basil, 0.015 l oil => doppelt = 0.500 kg / 0.300 kg / 0.240 kg / 10 g / 0.030 l
        let flour = try resolution.consumptions
            .first(where: { $0.ingredientID == InventorySandboxFixture.ingredientFlour })!
        let mozzarella = try resolution.consumptions
            .first(where: { $0.ingredientID == InventorySandboxFixture.ingredientMozzarella })!
        let oil = try resolution.consumptions
            .first(where: { $0.ingredientID == InventorySandboxFixture.ingredientOliveOil })!
        #expect(flour.quantity.baseAmount == Decimal(string: "500.000")!)
        #expect(mozzarella.quantity.baseAmount == Decimal(string: "300.000")!)
        #expect(oil.quantity.baseAmount == Decimal(string: "30.000")!)
    }

    @Test
    func multiLineOrderResolvesAllRecipes() throws {
        let (catalog, _) = try InventorySandboxFixture.makePopulatedLedger()
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let lines = [
            InventoryOrderLine(
                id: "line-pizza",
                salesItemID: InventorySandboxFixture.salesItemPizza,
                quantity: 1,
                reference: "order-mix"
            ),
            InventoryOrderLine(
                id: "line-tiramisu",
                salesItemID: InventorySandboxFixture.salesItemTiramisu,
                quantity: 2,
                reference: "order-mix"
            )
        ]
        let resolution = try resolver.resolve(
            lines: lines, at: InventorySandboxFixture.locationKitchen
        )
        // Pizza Margherita: 5 Zutaten; Tiramisu x2: 4 Zutaten x2
        #expect(resolution.consumptions.count == 5 + 4)
        let tiramisuFlour = resolution.consumptions.filter {
            $0.ingredientID == InventorySandboxFixture.ingredientMascarpone
        }
        #expect(tiramisuFlour.count == 1)
        #expect(tiramisuFlour.first?.quantity.baseAmount == Decimal(string: "160.000")!)
    }

    @Test
    func salesItemWithoutRecipeIsSkipped() throws {
        let (catalog, _) = try InventorySandboxFixture.makePopulatedLedger()
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let lines = [
            InventoryOrderLine(
                id: "line-wine",
                salesItemID: InventorySandboxFixture.salesItemRedWine,
                quantity: 2,
                reference: "order-wine"
            )
        ]
        let resolution = try resolver.resolve(
            lines: lines, at: InventorySandboxFixture.locationKitchen
        )
        #expect(resolution.consumptions.isEmpty)
        #expect(resolution.skippedLines.count == 1)
        #expect(resolution.unresolved.contains(where: {
            if case .salesItemWithoutRecipe = $0.reason { return true }
            return false
        }))
    }

    @Test
    func zeroOrNegativeQuantityIsReported() throws {
        let (catalog, _) = try InventorySandboxFixture.makePopulatedLedger()
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let lines = [
            InventoryOrderLine(
                id: "line-zero",
                salesItemID: InventorySandboxFixture.salesItemPizza,
                quantity: 0,
                reference: "order-bad"
            )
        ]
        let resolution = try resolver.resolve(
            lines: lines, at: InventorySandboxFixture.locationKitchen
        )
        #expect(resolution.consumptions.isEmpty)
        #expect(resolution.unresolved.contains(where: {
            if case .negativeOrZeroQuantity = $0.reason { return true }
            return false
        }))
    }

    @Test
    func idempotencyKeyFormatForOrderLineIsStable() {
        let key = InventoryRecipeResolver.idempotencyKey(
            reference: "order-42",
            lineID: "line-1",
            ingredientID: InventorySandboxFixture.ingredientFlour
        )
        #expect(key == "consumption:order-42:line-1:ingredient-mehl")
    }

    @Test
    func applyingSameOrderTwiceIsIdempotentInLedger() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let line = InventoryOrderLine(
            id: "line-pizza-idem",
            salesItemID: InventorySandboxFixture.salesItemPizza,
            quantity: 1,
            reference: "order-idem"
        )
        let firstCount = ledger.movements.count
        let firstResolution = try resolver.resolve(
            lines: [line], at: InventorySandboxFixture.locationKitchen
        )
        for movement in firstResolution.consumptions {
            _ = try ledger.record(movement)
        }
        let afterFirst = ledger.movements.count
        // Re-apply the same order with the same keys
        let secondResolution = try resolver.resolve(
            lines: [line], at: InventorySandboxFixture.locationKitchen
        )
        for movement in secondResolution.consumptions {
            _ = try ledger.record(movement)
        }
        #expect(ledger.movements.count == afterFirst)
        #expect(afterFirst > firstCount)
    }
}
