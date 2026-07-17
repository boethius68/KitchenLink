import Foundation
import Testing
@testable import kitchenlink

/// Tests fuer dimensionssichere Mengen und deterministische Rundung.
struct InventoryQuantityTests {

    @Test
    func gramsConvertToKilogramsLosslessly() throws {
        let grams = try InventoryQuantity(amount: 2_500, unit: .mass(.gram))
        let kilograms = try grams.amount(in: .mass(.kilogram))
        #expect(kilograms == Decimal(string: "2.500")!)
    }

    @Test
    func millilitersConvertToLiters() throws {
        let ml = try InventoryQuantity(amount: 750, unit: .volume(.milliliter))
        let liters = try ml.amount(in: .volume(.liter))
        #expect(liters == Decimal(string: "0.750")!)
    }

    @Test
    func countUnitOnlyMatchesCount() throws {
        let eggs = try InventoryQuantity(amount: 12, unit: .count)
        #expect(eggs.amount == 12)
        #expect(eggs.unit == .count)
    }

    @Test
    func additionAcrossCompatibleUnitsKeepsBase() throws {
        let a = try InventoryQuantity(amount: 250, unit: .mass(.gram))
        let b = try InventoryQuantity(amount: 0.75, unit: .mass(.kilogram))
        let sum = try a + b
        #expect(sum.baseAmount == Decimal(string: "1000.000")!)
    }

    @Test
    func additionAcrossIncompatibleUnitsThrows() throws {
        let mass = try InventoryQuantity(amount: 100, unit: .mass(.gram))
        let volume = try InventoryQuantity(amount: 100, unit: .volume(.milliliter))
        #expect(throws: InventoryQuantityError.self) {
            _ = try mass + volume
        }
    }

    @Test
    func subtractionCanProduceNegativeValues() throws {
        let a = try InventoryQuantity(amount: 100, unit: .count)
        let b = try InventoryQuantity(amount: 30, unit: .count)
        let result = try a - b
        #expect(result.baseAmount == 70)
    }

    @Test
    func negativeAmountIsRejected() {
        #expect(throws: InventoryQuantityError.self) {
            _ = try InventoryQuantity(amount: -1, unit: .count)
        }
    }

    @Test
    func countRoundsToWholeUnits() throws {
        let precise = try InventoryQuantity(amount: 5.4, unit: .count)
        #expect(precise.baseAmount == 5)
    }

    @Test
    func massRoundsToMilligramPrecision() throws {
        let grams = try InventoryQuantity(amount: Decimal(string: "1.23456")!, unit: .mass(.gram))
        #expect(grams.baseAmount == Decimal(string: "1.235")!)
    }

    @Test
    func volumeRoundsToMilliliterPrecision() throws {
        let ml = try InventoryQuantity(amount: Decimal(string: "33.3333")!, unit: .volume(.milliliter))
        #expect(ml.baseAmount == Decimal(string: "33.333")!)
    }

    @Test
    func scaleByIntegerScalesBaseAmount() throws {
        let a = try InventoryQuantity(amount: 250, unit: .mass(.gram))
        let scaled = try a * 4
        #expect(scaled.baseAmount == Decimal(string: "1000.000")!)
    }

    @Test
    func isBelowReturnsTrueOnlyForCompatibleLowerValues() throws {
        let a = try InventoryQuantity(amount: 1, unit: .mass(.kilogram))
        let b = try InventoryQuantity(amount: 1.5, unit: .mass(.kilogram))
        #expect(a.isBelow(b))
        #expect(!b.isBelow(a))
    }
}
