import Foundation

/// Erklaerbare Fehlbestandswarnung und Bestellvorschlag pro Zutat und
/// Lagerort. Werte werden aus der aktuellen Projektion gelesen, niemals
/// intern geclampt.
struct InventoryReplenishmentAdvisor {
    let catalog: InventoryCatalog
    let projection: InventoryProjection

    init(catalog: InventoryCatalog, projection: InventoryProjection) {
        self.catalog = catalog
        self.projection = projection
    }

    /// Prueft den Bestand und liefert eine Warnung inkl. Begruendung, wenn
    /// der physische oder verfuegbare Bestand den Mindestbestand
    /// unterschreitet. Bei negativen Werten wird dies als kritisch
    /// markiert, ohne den Wert still abzuschneiden.
    func evaluate(ingredientID: String, locationID: String) throws -> ReplenishmentEvaluation {
        let ingredient = try catalog.ingredient(id: ingredientID)
        let physical = try projection.physicalQuantity(
            ingredientID: ingredientID, locationID: locationID
        )
        let reserved = try projection.reservedQuantity(
            ingredientID: ingredientID, locationID: locationID
        )
        let available = try projection.availableQuantity(
            ingredientID: ingredientID, locationID: locationID
        )
        return ReplenishmentEvaluation(
            ingredient: ingredient,
            locationID: locationID,
            physical: physical,
            reserved: reserved,
            available: available
        )
    }

    /// Liefert fuer alle Zutaten am Lagerort die jeweilige Bewertung.
    func evaluateAll(at locationID: String) throws -> [ReplenishmentEvaluation] {
        var evaluations: [ReplenishmentEvaluation] = []
        for ingredient in catalog.ingredients.values {
            evaluations.append(try evaluate(ingredientID: ingredient.id, locationID: locationID))
        }
        return evaluations
    }

    /// Liefert den Bestellvorschlag, um den Zielbestand zu erreichen.
    func suggestion(for evaluation: ReplenishmentEvaluation) -> ReplenishmentSuggestion? {
        let ingredient = evaluation.ingredient
        let target = ingredient.targetStock
        if evaluation.physical >= target {
            return nil
        }
        let difference = (try? target - evaluation.physical) ?? .zero(ingredient.baseUnit)
        return ReplenishmentSuggestion(
            ingredientID: ingredient.id,
            locationID: evaluation.locationID,
            currentPhysical: evaluation.physical,
            target: target,
            shortfall: difference
        )
    }
}

/// Ergebnis der Pruefung einer Zutat an einem Lagerort.
struct ReplenishmentEvaluation: Equatable, Sendable {
    enum Severity: String, Equatable, Sendable, Codable {
        case ok
        case warning
        case critical
    }

    let ingredient: Ingredient
    let locationID: String
    let physical: InventoryQuantity
    let reserved: InventoryQuantity
    let available: InventoryQuantity

    /// Warnt, sobald der physische oder verfuegbare Bestand unter dem
    /// Mindestbestand liegt. Bei negativen Werten wird die Warnung als
    /// `critical` eingestuft.
    var severity: Severity {
        if physical.baseAmount < 0 || available.baseAmount < 0 {
            return .critical
        }
        if physical.isBelow(ingredient.minimumStock) || available.isBelow(ingredient.minimumStock) {
            return .warning
        }
        return .ok
    }

    /// Menschenlesbare Begruendung der Warnung, inklusive aller
    /// massgeblichen Werte, damit Operator:innen den Vorschlag bewerten
    /// koennen.
    var explanation: String {
        switch severity {
        case .ok:
            return "Bestand \(physical.displayString()) liegt ueber dem Mindestbestand von \(ingredient.minimumStock.displayString())."
        case .warning:
            return "Bestand \(physical.displayString()) (verfuegbar \(available.displayString())) liegt unter dem Mindestbestand von \(ingredient.minimumStock.displayString()). Zielbestand \(ingredient.targetStock.displayString())."
        case .critical:
            return "Kritischer Fehlbestand: physisch \(physical.displayString()), verfuegbar \(available.displayString()) – entweder fehlt ein Wareneingang oder es wurde zu viel verbraucht."
        }
    }
}

/// Konkreter Bestellvorschlag, um den Zielbestand wieder zu erreichen.
struct ReplenishmentSuggestion: Equatable, Sendable, Identifiable {
    var id: String { "\(ingredientID)@\(locationID)" }
    let ingredientID: String
    let locationID: String
    let currentPhysical: InventoryQuantity
    let target: InventoryQuantity
    let shortfall: InventoryQuantity
}
