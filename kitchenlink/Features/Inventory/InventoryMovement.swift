import Foundation

/// Kategorie einer Bestandsbewegung. Die `correction*`-Faelle modellieren
/// positive bzw. negative Bestandskorrekturen, die uebrigen Faelle
/// entsprechen 1:1 der in `PRODUCT_BLUEPRINT` §11 genannten Bewegungen.
enum StockMovementKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Wareneingang: erhoeht den physischen Bestand.
    case receipt
    /// Verbrauch durch Verkauf/Rezept: vermindert den physischen Bestand.
    case consumption
    /// Verderb, Bruch, Eigenverbrauch: vermindert den physischen Bestand.
    case waste
    /// Bestandskorrektur, die den physischen Bestand erhoeht (z. B. Nachzaehlung).
    case correctionIncrease
    /// Bestandskorrektur, die den physischen Bestand vermindert (z. B. Schwund).
    case correctionDecrease
    /// Transfer raus aus einem Lagerort.
    case transferOut
    /// Transfer rein in einen Lagerort.
    case transferIn
    /// Reservierung fuer eine Vorbestellung (veraendert nur `reserved`, nicht `physical`).
    case reservation
    /// Freigabe einer Reservierung (loescht `reserved`).
    case release
    /// Storno bzw. Gegenbuchung, die eine andere Bewegung aufhebt.
    case reversal

    /// Bucket, auf den sich die Bewegung auswirkt.
    enum Bucket: String, Codable, Equatable, Hashable, Sendable {
        case physical
        case reserved
    }

    /// Vorzeichen der Bewegung.
    enum Sign: Int, Codable, Equatable, Hashable, Sendable {
        case positive = 1
        case negative = -1
    }

    /// Bucket, in dem die Bewegung wirkt.
    var bucket: Bucket {
        switch self {
        case .reservation, .release:
            return .reserved
        case .receipt, .consumption, .waste, .correctionIncrease, .correctionDecrease,
             .transferOut, .transferIn, .reversal:
            return .physical
        }
    }

    /// Vorzeichen der Bewegung. Bei `.reversal` wird das Vorzeichen durch das
    /// aufzuhebende Original bestimmt und erst in der Projektion berechnet.
    /// Reservationen erhoehen `reserved` (positiv), Freigaben verringern es.
    var sign: Sign? {
        switch self {
        case .receipt, .correctionIncrease, .transferIn, .reservation:
            return .positive
        case .consumption, .waste, .correctionDecrease, .transferOut, .release:
            return .negative
        case .reversal:
            return nil
        }
    }

    /// Anzeigetitel der Bewegung auf Deutsch.
    var displayTitle: String {
        switch self {
        case .receipt: return "Wareneingang"
        case .consumption: return "Verbrauch"
        case .waste: return "Verderb"
        case .correctionIncrease: return "Korrektur (+)"
        case .correctionDecrease: return "Korrektur (-)"
        case .transferOut: return "Transfer raus"
        case .transferIn: return "Transfer rein"
        case .reservation: return "Reservierung"
        case .release: return "Freigabe"
        case .reversal: return "Gegenbuchung"
        }
    }
}

/// Ein einzelner Eintrag im append-only Bestandsledger.
///
/// Felder:
/// - `id`: global eindeutige Kennung der Bewegung.
/// - `timestamp`: Zeitpunkt der Eintragung (UTC, monoton steigend).
/// - `kind`: Kategorie der Bewegung.
/// - `quantity`: positive Menge in der Basiseinheit der Zutat.
/// - `reference`: optionaler fachlicher Verweis (z. B. `order:123:line:1`).
/// - `idempotencyKey`: optionaler Schluessel, der Wiederholungen erkennt.
/// - `reversalOfID`: nur fuer `.reversal` gesetzt, Verweis auf Original.
/// - `transferGroupID`: nur fuer `.transferOut`/`.transferIn` gesetzt.
/// - `note`: optionaler Freitext.
struct StockMovement: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var timestamp: Date
    var ingredientID: String
    var locationID: String
    var kind: StockMovementKind
    var quantity: InventoryQuantity
    var reference: String?
    var idempotencyKey: String?
    var reversalOfID: String?
    var transferGroupID: String?
    var note: String?

    init(
        id: String = UUID().uuidString,
        timestamp: Date = .now,
        ingredientID: String,
        locationID: String,
        kind: StockMovementKind,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        reversalOfID: String? = nil,
        transferGroupID: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ingredientID = ingredientID
        self.locationID = locationID
        self.kind = kind
        self.quantity = quantity
        self.reference = reference
        self.idempotencyKey = idempotencyKey
        self.reversalOfID = reversalOfID
        self.transferGroupID = transferGroupID
        self.note = note
    }

    /// Erstellt einen Wareneingang.
    static func receipt(
        ingredientID: String,
        locationID: String,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: .receipt,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt einen Verbrauch (Verkauf oder Rezeptaufloesung).
    static func consumption(
        ingredientID: String,
        locationID: String,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: .consumption,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt eine Reservierung.
    static func reservation(
        ingredientID: String,
        locationID: String,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: .reservation,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt eine Freigabe (Aufhebung einer Reservierung).
    static func release(
        ingredientID: String,
        locationID: String,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: .release,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt eine Verderb-/Bruch-Bewegung.
    static func waste(
        ingredientID: String,
        locationID: String,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: .waste,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt eine positive oder negative Bestandskorrektur.
    static func correction(
        ingredientID: String,
        locationID: String,
        increase: Bool,
        quantity: InventoryQuantity,
        reference: String? = nil,
        idempotencyKey: String? = nil,
        note: String? = nil,
        timestamp: Date = .now
    ) -> StockMovement {
        StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientID,
            locationID: locationID,
            kind: increase ? .correctionIncrease : .correctionDecrease,
            quantity: quantity,
            reference: reference,
            idempotencyKey: idempotencyKey,
            note: note
        )
    }

    /// Erstellt eine Storno-/Gegenbuchungs-Bewegung fuer das Original
    /// `original`. Die neue Bewegung erbt Zutat, Lagerort und Menge aus dem
    /// Original, setzt `reversalOfID` und verlaesst sich darauf, dass der
    /// Ledger das Original spaeter aus der Historie findet.
    static func reversal(
        of original: StockMovement,
        timestamp: Date = .now,
        note: String? = nil,
        idempotencyKey: String? = nil
    ) -> StockMovement {
        StockMovement(
            id: UUID().uuidString,
            timestamp: timestamp,
            ingredientID: original.ingredientID,
            locationID: original.locationID,
            kind: .reversal,
            quantity: original.quantity,
            reference: original.reference,
            idempotencyKey: idempotencyKey ?? "reversal:\(original.id)",
            reversalOfID: original.id,
            note: note
        )
    }

    /// Strukturelle Signatur einer Bewegung ohne `id` und `timestamp`, fuer
    /// Idempotenzvergleich und Tests.
    func fingerprint(includingTimestamp: Bool = false) -> String {
        var parts: [String] = [
            ingredientID,
            locationID,
            kind.rawValue,
            quantity.baseAmount.description,
            quantity.unit.shortSymbol
        ]
        if let reference { parts.append("ref=\(reference)") }
        if let idempotencyKey { parts.append("key=\(idempotencyKey)") }
        if let reversalOfID { parts.append("rev=\(reversalOfID)") }
        if let transferGroupID { parts.append("grp=\(transferGroupID)") }
        if includingTimestamp {
            parts.append("ts=\(timestamp.timeIntervalSince1970)")
        }
        return parts.joined(separator: "|")
    }
}

extension StockMovement {
    /// Liefert die effektive Vorzeichenauspraegung fuer die Projektion. Bei
    /// `.reversal` wird das Vorzeichen des Originals negiert.
    func resolvedSign(originalSign: StockMovementKind.Sign) -> StockMovementKind.Sign {
        switch kind {
        case .reversal:
            return originalSign == .positive ? .negative : .positive
        default:
            return kind.sign ?? originalSign
        }
    }
}
