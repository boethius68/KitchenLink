import Foundation

/// Zustandsträger der Bestandsansicht. Kapselt Katalog und Ledger und
/// veröffentlicht die frisch projizierten Zeilen als `@Published`.
///
/// `InventoryLedger` ist absichtlich weder `Sendable` noch
/// `ObservableObject` (KL-INVENTORY-001): die UI-Schicht darf die Domain-
/// Sichtbarkeit nicht ändern. Stattdessen wrappt dieses `@MainActor`-Model
/// die mutable Ledger-Referenz und republished nach jeder Änderung. Read-only
/// Nutzung heute: neue Bewegungen oder Stammdatenänderungen sind einem
/// späteren Buchen-Ticket vorbehalten; heute lädt ausschließlich der
/// Demo-Seeder den Anfangsbestand.
@MainActor
final class InventoryOperatorModel: ObservableObject {
    /// Sätze, die die Ansicht rendert. Leer bis der Seeder etwas lädt oder
    /// ein späteres Buchen-Ticket Bewegungen anlegt.
    @Published private(set) var groups: [KitchenLinkV2InventoryLocationGroup] = []
    @Published private(set) var catalog: InventoryCatalog?
    @Published var statusMessage: String?
    @Published private(set) var lastError: String?

    private var ledger: InventoryLedger?

    /// Setzt einen frischen Katalog + Ledger und publiziert die Projektion.
    /// Wird vom Demo-Seeder und (später) von Persistenz/Push-Pfaden gerufen.
    func load(catalog: InventoryCatalog, ledger: InventoryLedger) {
        self.catalog = catalog
        self.ledger = ledger
        refresh()
    }

    /// Leer die Ansicht (z.B. vor dem Neuladen des Demo-Szenarios).
    func clear() {
        catalog = nil
        ledger = nil
        groups = []
        statusMessage = nil
        lastError = nil
    }

    /// Berechnet die Projektion frisch aus dem Ledger neu. Caching ist per
    /// `INVENTORY_MODEL.md` §8 bewusst vertagt.
    func refresh() {
        guard let catalog, let ledger else { return }
        do {
            groups = try KitchenLinkV2InventoryStockProjection.groups(
                catalog: catalog,
                ledger: ledger
            )
            lastError = nil
        } catch {
            groups = []
            lastError = error.localizedDescription
        }
    }

    /// Anzahl Zeilen gesamt (Helfer für Header-Statistik und Tests).
    var totalRowCount: Int {
        groups.reduce(0) { $0 + $1.rows.count }
    }

    /// Anzahl Zeilen mit kritischer Schwere (Helfer für Header und Tests).
    var criticalCount: Int {
        groups.reduce(0) { acc, group in
            acc + group.rows.lazy.filter { $0.urgency == .critical }.count
        }
    }

    // MARK: - Warenwirtschaft Aktionen (KL-INV-001 / Blueprint §11)

    var availableLocations: [StockLocation] {
        guard let catalog else { return [] }
        return Array(catalog.locations.values).sorted { $0.name < $1.name }
    }

    var availableIngredients: [Ingredient] {
        guard let catalog else { return [] }
        return Array(catalog.ingredients.values).sorted { $0.name < $1.name }
    }

    /// Verbucht eine unveränderliche Bewegung (Wareneingang, Verderb, Korrektur).
    func recordMovement(
        ingredientID: String,
        locationID: String,
        kind: StockMovementKind,
        amount: Decimal,
        note: String? = nil
    ) throws {
        guard let catalog, let ledger else {
            throw InventoryModelError.unknownLocation(id: locationID)
        }
        let ingredient = try catalog.ingredient(id: ingredientID)
        let quantity = try InventoryQuantity(amount: amount, unit: ingredient.baseUnit)
        let movement = StockMovement(
            ingredientID: ingredientID,
            locationID: locationID,
            kind: kind,
            quantity: quantity,
            note: note
        )
        try ledger.record(movement)
        refresh()
    }

    /// Führt einen Inventur-Abgleich durch: Differenz zwischen Ist und Soll wird
    /// als unveränderliche Korrekturbuchung erfasst.
    func recordAudit(
        locationID: String,
        counts: [String: Decimal],
        note: String? = nil
    ) throws {
        guard let catalog, let ledger else {
            throw InventoryModelError.unknownLocation(id: locationID)
        }
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let auditNote = note?.trimmingCharacters(in: .whitespaces).isEmpty == false ? note! : "Inventur"

        for (ingredientID, countedAmount) in counts {
            let ingredient = try catalog.ingredient(id: ingredientID)
            let currentPhysical = try projection.physicalQuantity(ingredientID: ingredientID, locationID: locationID)
            let countedQuantity = try InventoryQuantity(amount: countedAmount, unit: ingredient.baseUnit)

            let diff = countedQuantity.baseAmount - currentPhysical.baseAmount
            if diff > 0 {
                let diffQty = InventoryQuantity(uncheckedBaseAmount: diff, unit: ingredient.baseUnit)
                let movement = StockMovement(
                    ingredientID: ingredientID,
                    locationID: locationID,
                    kind: .correctionIncrease,
                    quantity: diffQty,
                    note: "\(auditNote): Ist \(countedQuantity.displayString()) > Soll \(currentPhysical.displayString())"
                )
                try ledger.record(movement)
            } else if diff < 0 {
                let diffQty = InventoryQuantity(uncheckedBaseAmount: abs(diff), unit: ingredient.baseUnit)
                let movement = StockMovement(
                    ingredientID: ingredientID,
                    locationID: locationID,
                    kind: .correctionDecrease,
                    quantity: diffQty,
                    note: "\(auditNote): Ist \(countedQuantity.displayString()) < Soll \(currentPhysical.displayString())"
                )
                try ledger.record(movement)
            }
        }
        refresh()
    }

    /// Berechnet Bestellvorschläge basierend auf aktuellem Bestand und Mindestbestand.
    func replenishmentSuggestions(for locationID: String? = nil) throws -> [ReplenishmentSuggestion] {
        guard let catalog, let ledger else { return [] }
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)

        let targetLocations = locationID != nil ? [locationID!] : Array(catalog.locations.keys)
        var results: [ReplenishmentSuggestion] = []
        for loc in targetLocations {
            let evaluations = try advisor.evaluateAll(at: loc)
            for eval in evaluations {
                if let suggestion = advisor.suggestion(for: eval) {
                    results.append(suggestion)
                }
            }
        }
        return results
    }
}
