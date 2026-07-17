import Foundation

/// Projektion des aktuellen Bestands aus dem append-only Ledger. Werte
/// werden frisch berechnet, damit jede Aufrufstelle den aktuellen Stand
/// sieht; Caching und Snapshots folgen mit der spaeteren
/// Persistenzschnittstelle (siehe `INVENTORY_MODEL.md` §7).
struct InventoryProjection {
    let catalog: InventoryCatalog
    let ledger: InventoryLedger

    init(catalog: InventoryCatalog, ledger: InventoryLedger) {
        self.catalog = catalog
        self.ledger = ledger
    }

    /// Physischer Bestand: Summe aller Wareneingaenge, Verbraeuche,
    /// Verderb, Korrekturen, Transfers und Gegenbuchungen am Lagerort.
    /// Negative Werte sind erlaubt und werden sichtbar zurueckgegeben, damit
    /// Operatoren Fehlbuchungen frueh erkennen koennen.
    func physicalQuantity(
        ingredientID: String,
        locationID: String
    ) throws -> InventoryQuantity {
        let ingredient = try catalog.ingredient(id: ingredientID)
        let unit = ingredient.baseUnit
        var total: Decimal = 0
        for movement in ledger.movements(ingredientID: ingredientID, locationID: locationID) {
            let contribution = try signedContribution(of: movement, in: ledger)
            guard contribution.bucket == .physical else { continue }
            total += contribution.signedAmount
        }
        return InventoryQuantity(uncheckedBaseAmount: total, unit: Self.canonicalUnit(for: unit))
    }

    /// Reservierter Bestand: Saldo aus Reservierungen und Freigaben am
    /// Lagerort. Negative Werte sind hier unzulaessig und werden daher auf
    /// Null geclampt, aber mit einer zusaetzlichen Pruefung dokumentiert.
    func reservedQuantity(
        ingredientID: String,
        locationID: String
    ) throws -> InventoryQuantity {
        let ingredient = try catalog.ingredient(id: ingredientID)
        let unit = ingredient.baseUnit
        var total: Decimal = 0
        for movement in ledger.movements(ingredientID: ingredientID, locationID: locationID) {
            let contribution = try signedContribution(of: movement, in: ledger)
            guard contribution.bucket == .reserved else { continue }
            total += contribution.signedAmount
        }
        if total < 0 {
            return InventoryQuantity(uncheckedBaseAmount: 0, unit: Self.canonicalUnit(for: unit))
        }
        return InventoryQuantity(uncheckedBaseAmount: total, unit: Self.canonicalUnit(for: unit))
    }

    /// Verfuegbarer Bestand: physischer Bestand minus reservierter Bestand.
    /// Negative Werte sind erlaubt, damit Operatoren Fehlbuchungen erkennen.
    func availableQuantity(
        ingredientID: String,
        locationID: String
    ) throws -> InventoryQuantity {
        let physical = try physicalQuantity(ingredientID: ingredientID, locationID: locationID)
        let reserved = try reservedQuantity(ingredientID: ingredientID, locationID: locationID)
        return try physical - reserved
    }

    /// Stichprobenartige Inventur-Sicht: liefert pro (Zutat, Lagerort) den
    /// physischen, reservierten und verfuegbaren Bestand.
    func snapshot() throws -> [InventorySnapshotEntry] {
        var entries: [InventorySnapshotEntry] = []
        for ingredient in catalog.ingredients.values {
            for location in catalog.locations.values {
                let physical = try physicalQuantity(
                    ingredientID: ingredient.id, locationID: location.id
                )
                let reserved = try reservedQuantity(
                    ingredientID: ingredient.id, locationID: location.id
                )
                let available = try availableQuantity(
                    ingredientID: ingredient.id, locationID: location.id
                )
                entries.append(
                    InventorySnapshotEntry(
                        ingredientID: ingredient.id,
                        locationID: location.id,
                        physical: physical,
                        reserved: reserved,
                        available: available
                    )
                )
            }
        }
        return entries
    }

    private static func canonicalUnit(for unit: MeasurementUnit) -> MeasurementUnit {
        switch unit {
        case .mass: return .mass(.gram)
        case .volume: return .volume(.milliliter)
        case .count: return .count
        }
    }

    private func signedContribution(
        of movement: StockMovement,
        in ledger: InventoryLedger
    ) throws -> InventoryContribution {
        if movement.kind == .reversal, let originalID = movement.reversalOfID {
            guard let original = ledger.movement(id: originalID) else {
                throw InventoryProjectionError.missingReversalTarget(movement: movement.id)
            }
            let originalSign = original.kind.sign ?? .positive
            let reversedSign: StockMovementKind.Sign = originalSign == .positive ? .negative : .positive
            return InventoryContribution(
                bucket: original.kind.bucket,
                signedAmount: movement.quantity.baseAmount * Decimal(reversedSign.rawValue)
            )
        }
        guard let sign = movement.kind.sign else {
            throw InventoryProjectionError.unsupportedKindForProjection(
                movement: movement.id, kind: movement.kind
            )
        }
        return InventoryContribution(
            bucket: movement.kind.bucket,
            signedAmount: movement.quantity.baseAmount * Decimal(sign.rawValue)
        )
    }
}

struct InventoryContribution: Equatable, Sendable {
    let bucket: StockMovementKind.Bucket
    let signedAmount: Decimal
}

struct InventorySnapshotEntry: Identifiable, Equatable, Sendable {
    var id: String { "\(ingredientID)@\(locationID)" }
    let ingredientID: String
    let locationID: String
    let physical: InventoryQuantity
    let reserved: InventoryQuantity
    let available: InventoryQuantity
}

enum InventoryProjectionError: LocalizedError, Equatable {
    case missingReversalTarget(movement: String)
    case unsupportedKindForProjection(movement: String, kind: StockMovementKind)

    var errorDescription: String? {
        switch self {
        case .missingReversalTarget(let movement):
            return "Gegenbuchung \(movement) verweist auf unbekanntes Original."
        case .unsupportedKindForProjection(let movement, let kind):
            return "Bewegung \(movement) mit Kategorie \(kind.rawValue) ist nicht projektionsfaehig."
        }
    }
}
