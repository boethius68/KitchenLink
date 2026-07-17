import Foundation

/// Aufloesung von Verkaufsartikeln in konkrete Bestandsbewegungen. Die
/// Resolver-Klasse erzeugt append-only `StockMovement`-Eintraege mit
/// deterministischen Idempotenzschluesseln, damit dieselbe Bestellung mehrfach
/// angewendet werden kann, ohne doppelt abzubuchen.
struct InventoryOrderLine: Equatable, Sendable, Codable {
    /// Eindeutige Kennung der Position innerhalb der Bestellung.
    let id: String
    /// Verkaufsartikel-ID (siehe `InventoryCatalog.salesItems`).
    let salesItemID: String
    /// Bestellte Menge (Anzahl Gerichte/Artikel).
    let quantity: Int
    /// Optionaler Verweis auf die Bestellung, z. B. `order-123`.
    let reference: String?
}

struct InventoryOrderResolution: Equatable, Sendable {
    let consumptions: [StockMovement]
    let skippedLines: [InventoryOrderLine]
    let unresolved: [InventoryResolutionIssue]
}

struct InventoryResolutionIssue: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case salesItemWithoutRecipe(line: InventoryOrderLine)
        case negativeOrZeroQuantity(line: InventoryOrderLine)
        case unknownSalesItem(lineID: String, salesItemID: String)
        case unknownIngredient(recipe: String, ingredient: String)
    }

    let reason: Reason
}

/// Aufloesung von Bestellpositionen in Bestandsbewegungen. Verwendet nur
/// den `InventoryCatalog` und produziert Bewegungen, die ueber den Ledger
/// gebucht werden.
struct InventoryRecipeResolver {
    let catalog: InventoryCatalog

    init(catalog: InventoryCatalog) {
        self.catalog = catalog
    }

    /// Loest die Bestellpositionen am angegebenen Lagerort in
    /// Verbrauchsbewegungen auf. Mengen werden mit der Rezeptmenge skaliert
    /// und in die Basiseinheit der Zutat konvertiert. Positionen ohne
    /// Rezept fuehren zu einer Meldung, aber nicht zu einem Fehler.
    func resolve(
        lines: [InventoryOrderLine],
        at locationID: String,
        timestamp: Date = .now
    ) throws -> InventoryOrderResolution {
        _ = try catalog.location(id: locationID)
        var consumptions: [StockMovement] = []
        var skipped: [InventoryOrderLine] = []
        var issues: [InventoryResolutionIssue] = []

        for line in lines {
            if line.quantity <= 0 {
                issues.append(
                    InventoryResolutionIssue(reason: .negativeOrZeroQuantity(line: line))
                )
                continue
            }
            let salesItem: SalesItem
            do {
                salesItem = try catalog.salesItem(id: line.salesItemID)
            } catch {
                issues.append(
                    InventoryResolutionIssue(
                        reason: .unknownSalesItem(lineID: line.id, salesItemID: line.salesItemID)
                    )
                )
                continue
            }
            guard let recipeID = salesItem.recipeID else {
                skipped.append(line)
                issues.append(
                    InventoryResolutionIssue(reason: .salesItemWithoutRecipe(line: line))
                )
                continue
            }
            let recipe = try catalog.recipe(id: recipeID)
            for component in recipe.components {
                let ingredient = try catalog.ingredient(id: component.ingredientID)
                guard component.quantity.unit.isCompatible(with: ingredient.baseUnit) else {
                    throw InventoryModelError.incompatibleStockUnit(
                        ingredient: ingredient.id, dimension: ingredient.baseUnit.dimensionTitle
                    )
                }
                let scaled = try component.quantity * line.quantity
                let key = Self.idempotencyKey(
                    reference: line.reference,
                    lineID: line.id,
                    ingredientID: ingredient.id
                )
                let movement = StockMovement.consumption(
                    ingredientID: ingredient.id,
                    locationID: locationID,
                    quantity: scaled,
                    reference: line.reference,
                    idempotencyKey: key,
                    note: "Rezept \(recipe.name) × \(line.quantity)",
                    timestamp: timestamp
                )
                consumptions.append(movement)
            }
        }

        return InventoryOrderResolution(
            consumptions: consumptions,
            skippedLines: skipped,
            unresolved: issues
        )
    }

    /// Erzeugt die Idempotenzschluessel fuer Reservierungen, Freigaben und
    /// Verbraeuche zu einer Bestellposition. Wird sowohl vom Resolver als
    /// auch von externem Code verwendet, der Vorbestellungen abbildet.
    static func idempotencyKey(
        reference: String?,
        lineID: String,
        ingredientID: String
    ) -> String {
        let ref = reference ?? "ad-hoc"
        return "consumption:\(ref):\(lineID):\(ingredientID)"
    }

    static func reservationKey(
        reference: String?,
        lineID: String,
        ingredientID: String
    ) -> String {
        let ref = reference ?? "ad-hoc"
        return "reservation:\(ref):\(lineID):\(ingredientID)"
    }

    static func releaseKey(
        reference: String?,
        lineID: String,
        ingredientID: String
    ) -> String {
        let ref = reference ?? "ad-hoc"
        return "release:\(ref):\(lineID):\(ingredientID)"
    }
}
