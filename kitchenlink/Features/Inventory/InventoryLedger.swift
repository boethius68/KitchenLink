import Foundation

/// Append-only Bestandsledger. Verarbeitet Bewegungen streng in der
/// Reihenfolge ihres Eintreffens und schuetzt Idempotenz, Transfers und
/// Gegenbuchungen.
final class InventoryLedger {
    private(set) var catalog: InventoryCatalog
    private(set) var movements: [StockMovement]
    private var byIdempotencyKey: [String: StockMovement]
    private var reversedOriginalIDs: Set<String>
    private var reversedTransferGroups: Set<String>

    init(catalog: InventoryCatalog) {
        self.catalog = catalog
        self.movements = []
        self.byIdempotencyKey = [:]
        self.reversedOriginalIDs = []
        self.reversedTransferGroups = []
    }

    /// Anzahl Bewegungen im Ledger.
    var count: Int { movements.count }

    /// Ersetzt den Katalog durch eine neue Version, ohne die Historie zu
    /// beruehren. Prueft, dass alle in der Historie verwendeten Zutaten und
    /// Lagerorte im neuen Katalog noch existieren.
    func updateCatalog(_ newCatalog: InventoryCatalog) throws {
        for movement in movements {
            if newCatalog.ingredients[movement.ingredientID] == nil {
                throw InventoryLedgerError.unknownIngredientInHistory(
                    ingredient: movement.ingredientID, movement: movement.id
                )
            }
            if newCatalog.locations[movement.locationID] == nil {
                throw InventoryLedgerError.unknownLocationInHistory(
                    location: movement.locationID, movement: movement.id
                )
            }
        }
        self.catalog = newCatalog
    }

    /// Zeichnet eine neue Bewegung auf. Bei gesetztem `idempotencyKey` und
    /// identischer Signatur wird der urspruengliche Eintrag zurueckgegeben,
    /// bei unterschiedlicher Signatur wird ein Konflikt ausgeloest. Reversal-
    /// und Transfer-Schutz laufen vor der Idempotenzpruefung, damit ein
    /// zweiter Storno desselben Originals immer als Verstoß gegen die
    /// Schutzregel scheitert, auch wenn die Idempotenzschluessel kollidieren.
    @discardableResult
    func record(_ movement: StockMovement) throws -> StockMovement {
        try validate(movement: movement, against: catalog)

        if movement.kind == .reversal, let originalID = movement.reversalOfID {
            guard let original = movements.first(where: { $0.id == originalID }) else {
                throw InventoryLedgerError.unknownReversalTarget(movement: originalID)
            }
            guard !reversedOriginalIDs.contains(originalID) else {
                throw InventoryLedgerError.alreadyReversed(original: originalID)
            }
            if original.kind == .reversal {
                throw InventoryLedgerError.reversalOfReversal(original: originalID)
            }
            reversedOriginalIDs.insert(originalID)
            if let group = original.transferGroupID {
                reversedTransferGroups.insert(group)
            }
        }

        if let group = movement.transferGroupID {
            try validateTransferGroup(movement: movement, group: group)
        }

        if let key = movement.idempotencyKey, let existing = byIdempotencyKey[key] {
            if existing.fingerprint() == movement.fingerprint() {
                return existing
            }
            throw InventoryLedgerError.idempotencyConflict(
                key: key,
                existing: existing.id,
                attempted: movement.id
            )
        }

        if let key = movement.idempotencyKey {
            byIdempotencyKey[key] = movement
        }
        movements.append(movement)
        return movement
    }

    /// Erstellt eine Gegenbuchung fuer `original` und zeichnet sie auf.
    @discardableResult
    func reverse(
        _ original: StockMovement,
        reason: String? = nil,
        timestamp: Date = .now
    ) throws -> StockMovement {
        let reversal = StockMovement.reversal(of: original, timestamp: timestamp, note: reason)
        return try record(reversal)
    }

    /// Liefert die Bewegung mit der angegebenen ID, falls vorhanden.
    func movement(id: String) -> StockMovement? {
        movements.first(where: { $0.id == id })
    }

    /// Liefert alle Bewegungen fuer die angegebene Zutat am angegebenen
    /// Lagerort, in chronologischer Reihenfolge.
    func movements(ingredientID: String, locationID: String) -> [StockMovement] {
        movements.filter { $0.ingredientID == ingredientID && $0.locationID == locationID }
    }

    /// Liefert alle Bewegungen, die mit `reference` verknuepft sind.
    func movements(reference: String) -> [StockMovement] {
        movements.filter { $0.reference == reference }
    }

    /// Liefert alle Bewegungen mit dem angegebenen Idempotenzschluessel.
    func movements(idempotencyKey: String) -> [StockMovement] {
        movements.filter { $0.idempotencyKey == idempotencyKey }
    }

    private func validate(
        movement: StockMovement,
        against catalog: InventoryCatalog
    ) throws {
        guard catalog.ingredients[movement.ingredientID] != nil else {
            throw InventoryLedgerError.unknownIngredient(
                ingredient: movement.ingredientID, movement: movement.id
            )
        }
        guard catalog.locations[movement.locationID] != nil else {
            throw InventoryLedgerError.unknownLocation(
                location: movement.locationID, movement: movement.id
            )
        }
        let ingredient = try catalog.ingredient(id: movement.ingredientID)
        guard movement.quantity.unit.isCompatible(with: ingredient.baseUnit) else {
            throw InventoryLedgerError.unitMismatch(
                movement: movement.id, expected: ingredient.baseUnit
            )
        }
        if movement.kind == .reversal {
            guard movement.reversalOfID != nil else {
                throw InventoryLedgerError.reversalMissingReference(movement: movement.id)
            }
        } else if movement.reversalOfID != nil {
            throw InventoryLedgerError.reversalOfIDOnNonReversal(movement: movement.id)
        }
        if movement.kind == .transferOut || movement.kind == .transferIn {
            guard movement.transferGroupID != nil else {
                throw InventoryLedgerError.transferMissingGroup(movement: movement.id)
            }
        } else if movement.transferGroupID != nil {
            throw InventoryLedgerError.transferGroupOnNonTransfer(movement: movement.id)
        }
    }

    private func validateTransferGroup(
        movement: StockMovement,
        group: String
    ) throws {
        guard !reversedTransferGroups.contains(group) else {
            throw InventoryLedgerError.alreadyReversedTransfer(group: group)
        }
        let siblings = movements.filter { $0.transferGroupID == group }
        let direction: StockMovementKind
        switch movement.kind {
        case .transferOut: direction = .transferIn
        case .transferIn: direction = .transferOut
        default:
            throw InventoryLedgerError.transferGroupOnNonTransfer(movement: movement.id)
        }
        guard let opposite = siblings.first(where: { $0.kind == direction }) else {
            return
        }
        guard opposite.ingredientID == movement.ingredientID else {
            throw InventoryLedgerError.transferIngredientMismatch(
                group: group, left: opposite.ingredientID, right: movement.ingredientID
            )
        }
        guard opposite.locationID != movement.locationID else {
            throw InventoryLedgerError.transferSameLocation(group: group)
        }
        guard opposite.quantity == movement.quantity else {
            throw InventoryLedgerError.transferQuantityMismatch(
                group: group, left: opposite.quantity, right: movement.quantity
            )
        }
    }
}

enum InventoryLedgerError: LocalizedError, Equatable {
    case unknownIngredient(ingredient: String, movement: String)
    case unknownLocation(location: String, movement: String)
    case unknownIngredientInHistory(ingredient: String, movement: String)
    case unknownLocationInHistory(location: String, movement: String)
    case unitMismatch(movement: String, expected: MeasurementUnit)
    case idempotencyConflict(key: String, existing: String, attempted: String)
    case unknownReversalTarget(movement: String)
    case alreadyReversed(original: String)
    case reversalOfReversal(original: String)
    case reversalMissingReference(movement: String)
    case reversalOfIDOnNonReversal(movement: String)
    case transferMissingGroup(movement: String)
    case transferGroupOnNonTransfer(movement: String)
    case transferIngredientMismatch(group: String, left: String, right: String)
    case transferSameLocation(group: String)
    case transferQuantityMismatch(group: String, left: InventoryQuantity, right: InventoryQuantity)
    case alreadyReversedTransfer(group: String)

    var errorDescription: String? {
        switch self {
        case .unknownIngredient(let ingredient, let movement):
            return "Bewegung \(movement) verweist auf unbekannte Zutat \(ingredient)."
        case .unknownLocation(let location, let movement):
            return "Bewegung \(movement) verweist auf unbekannten Lagerort \(location)."
        case .unknownIngredientInHistory(let ingredient, let movement):
            return "Historie enthaelt Bewegung \(movement) mit unbekannter Zutat \(ingredient)."
        case .unknownLocationInHistory(let location, let movement):
            return "Historie enthaelt Bewegung \(movement) mit unbekanntem Lagerort \(location)."
        case .unitMismatch(let movement, let expected):
            return "Bewegung \(movement) hat eine zur Zutat inkompatible Einheit (erwartet \(expected.displaySymbol))."
        case .idempotencyConflict(let key, let existing, let attempted):
            return "Idempotenzschluessel \(key) ist bereits mit Bewegung \(existing) belegt, Konflikt mit \(attempted)."
        case .unknownReversalTarget(let movement):
            return "Gegenbuchung verweist auf unbekannte Bewegung \(movement)."
        case .alreadyReversed(let original):
            return "Bewegung \(original) wurde bereits storniert."
        case .reversalOfReversal(let original):
            return "Bewegung \(original) ist selbst eine Gegenbuchung und darf nicht storniert werden."
        case .reversalMissingReference(let movement):
            return "Gegenbuchung \(movement) enthaelt keinen Verweis auf das Original."
        case .reversalOfIDOnNonReversal(let movement):
            return "Bewegung \(movement) ist keine Gegenbuchung, enthaelt aber reversalOfID."
        case .transferMissingGroup(let movement):
            return "Transfer \(movement) enthaelt keine transferGroupID."
        case .transferGroupOnNonTransfer(let movement):
            return "Bewegung \(movement) ist kein Transfer, enthaelt aber transferGroupID."
        case .transferIngredientMismatch(let group, let left, let right):
            return "Transfergruppe \(group) enthaelt unterschiedliche Zutaten (\(left) vs. \(right))."
        case .transferSameLocation(let group):
            return "Transfergruppe \(group) hat Quelle und Ziel identisch."
        case .transferQuantityMismatch(let group, let left, let right):
            return "Transfergruppe \(group) hat unterschiedliche Mengen (\(left.displayString()) vs. \(right.displayString()))."
        case .alreadyReversedTransfer(let group):
            return "Transfergruppe \(group) wurde bereits storniert."
        }
    }
}
