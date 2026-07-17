import Foundation

/// Dimensionssichere Mengeneinheit fuer die Warenwirtschaft.
///
/// Die Sandbox unterstuetzt drei Dimensionen:
/// - `mass` in Gramm (gerundet auf 0,001 g), anzeigbar in g oder kg
/// - `volume` in Milliliter (gerundet auf 0,001 ml), anzeigbar in ml oder l
/// - `count` als ganze Einheiten (gerundet auf 1)
///
/// Bewertung, FIFO und steuerliche Logik sind bewusst vertagt und werden in
/// `INVENTORY_MODEL.md` §6 festgehalten.
enum MeasurementUnit: Codable, Equatable, Hashable, Sendable {
    case mass(MassUnit)
    case volume(VolumeUnit)
    case count

    enum MassUnit: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
        case gram = "g"
        case kilogram = "kg"
    }

    enum VolumeUnit: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
        case milliliter = "ml"
        case liter = "l"
    }

    /// Anzeigename der Dimension, auf Deutsch.
    var dimensionTitle: String {
        switch self {
        case .mass: return "Masse"
        case .volume: return "Volumen"
        case .count: return "Stueck"
        }
    }

    /// Anzeigekuerzel der Basiseinheit (g, ml, Stk).
    var shortSymbol: String {
        switch self {
        case .mass: return "g"
        case .volume: return "ml"
        case .count: return "Stk"
        }
    }

    /// Anzeigekuerzel der gewaehlten Einheit.
    var displaySymbol: String {
        switch self {
        case .mass(let unit): return unit.rawValue
        case .volume(let unit): return unit.rawValue
        case .count: return "Stk"
        }
    }

    /// Kompatible Einheiten, mit denen ohne Konversion addiert oder verglichen
    /// werden darf. Zwei Einheiten sind genau dann kompatibel, wenn sie
    /// derselben Dimension angehoeren.
    func isCompatible(with other: MeasurementUnit) -> Bool {
        switch (self, other) {
        case (.mass, .mass), (.volume, .volume), (.count, .count):
            return true
        default:
            return false
        }
    }

    /// Faktor zur Umrechnung in die jeweilige Basiseinheit (Gramm, Milliliter,
    /// Stueck). Die Sandbox akzeptiert ausschliesslich diese drei Basen.
    var baseFactor: Decimal {
        switch self {
        case .mass(let unit):
            return unit == .kilogram ? 1_000 : 1
        case .volume(let unit):
            return unit == .liter ? 1_000 : 1
        case .count:
            return 1
        }
    }
}

/// Wert mit fester Einheit. Werte werden intern in der jeweiligen Basiseinheit
/// (Gramm, Milliliter, Stueck) als `Decimal` gehalten.
///
/// Initialisierung rundet automatisch in die Basiseinheit und lehnt negative
/// Werte ab; `zero` ist die einzige zulaessige Nullmenge.
struct InventoryQuantity: Codable, Equatable, Hashable, Sendable {
    /// Betrag in der Basiseinheit (Gramm, Milliliter, Stueck).
    let baseAmount: Decimal
    let unit: MeasurementUnit

    /// Interner Konstruktor fuer Aggregationen (z. B. Projektion), die den
    /// Wert bereits in der Basiseinheit halten und keine weitere Pruefung
    /// benoetigen. Negative Werte sind erlaubt, damit Operator:innen
    /// Fehlbuchungen sehen, statt still auf Null geclampt zu werden.
    init(uncheckedBaseAmount amount: Decimal, unit: MeasurementUnit) {
        self.baseAmount = amount
        self.unit = unit
    }

    /// Erstellt eine Menge und rundet sie deterministisch in die Basiseinheit.
    /// - Parameter amount: Betrag in der angegebenen Einheit. Negativ oder NaN
    ///   wird abgelehnt.
    /// - Throws: `InventoryQuantityError.negativeAmount` oder
    ///   `InventoryQuantityError.nonFiniteAmount`.
    init(amount: Decimal, unit: MeasurementUnit) throws {
        guard amount.isFinite else {
            throw InventoryQuantityError.nonFiniteAmount
        }
        guard !amount.isSignMinus else {
            throw InventoryQuantityError.negativeAmount(amount: amount, unit: unit)
        }
        let base = amount * unit.baseFactor
        let rounded = Self.round(base, dimension: unit)
        self.init(uncheckedBaseAmount: rounded, unit: Self.canonicalUnit(for: unit))
    }

    /// Stellt die Nullmenge her; einziger Konstruktor, der keine Pruefung
    /// benoetigt, weil das Ergebnis immer gueltig ist.
    static func zero(_ unit: MeasurementUnit) -> InventoryQuantity {
        InventoryQuantity(uncheckedBaseAmount: 0, unit: canonicalUnit(for: unit))
    }

    private static func canonicalUnit(for unit: MeasurementUnit) -> MeasurementUnit {
        switch unit {
        case .mass: return .mass(.gram)
        case .volume: return .volume(.milliliter)
        case .count: return .count
        }
    }

    /// Liefert die Menge in der Basiseinheit (Gramm, Milliliter, Stueck).
    var amount: Decimal { baseAmount }

    /// Liefert die Menge in einer konkreten Anzeigeeinheit (z. B. Kilogramm).
    func amount(in target: MeasurementUnit) throws -> Decimal {
        guard unit.isCompatible(with: target) else {
            throw InventoryQuantityError.incompatibleUnits(left: unit, right: target)
        }
        let converted = baseAmount / target.baseFactor
        return Self.round(converted, dimension: target)
    }

    /// Addiert zwei Mengen gleicher Dimension.
    static func + (lhs: InventoryQuantity, rhs: InventoryQuantity) throws -> InventoryQuantity {
        guard lhs.unit.isCompatible(with: rhs.unit) else {
            throw InventoryQuantityError.incompatibleUnits(left: lhs.unit, right: rhs.unit)
        }
        let sum = lhs.baseAmount + rhs.baseAmount
        return InventoryQuantity(uncheckedBaseAmount: sum, unit: lhs.unit)
    }

    /// Subtrahiert zwei Mengen gleicher Dimension; negative Ergebnisse werden
    /// zugelassen, damit Aufloesungen (Reservierung vs. Bestand) frueh
    /// sichtbar werden koennen, statt intern still abzuschneiden.
    static func - (lhs: InventoryQuantity, rhs: InventoryQuantity) throws -> InventoryQuantity {
        guard lhs.unit.isCompatible(with: rhs.unit) else {
            throw InventoryQuantityError.incompatibleUnits(left: lhs.unit, right: rhs.unit)
        }
        let diff = lhs.baseAmount - rhs.baseAmount
        return InventoryQuantity(uncheckedBaseAmount: diff, unit: lhs.unit)
    }

    /// Multipliziert die Menge mit einem dimensionslosen Skalar.
    static func * (lhs: InventoryQuantity, scalar: Int) throws -> InventoryQuantity {
        guard scalar >= 0 else {
            throw InventoryQuantityError.negativeScalar(scalar: scalar)
        }
        let product = lhs.baseAmount * Decimal(scalar)
        return InventoryQuantity(uncheckedBaseAmount: product, unit: lhs.unit)
    }

    static func < (lhs: InventoryQuantity, rhs: InventoryQuantity) -> Bool {
        guard lhs.unit.isCompatible(with: rhs.unit) else { return false }
        return lhs.baseAmount < rhs.baseAmount
    }

    static func <= (lhs: InventoryQuantity, rhs: InventoryQuantity) -> Bool {
        guard lhs.unit.isCompatible(with: rhs.unit) else { return false }
        return lhs.baseAmount <= rhs.baseAmount
    }

    static func > (lhs: InventoryQuantity, rhs: InventoryQuantity) -> Bool {
        guard lhs.unit.isCompatible(with: rhs.unit) else { return false }
        return lhs.baseAmount > rhs.baseAmount
    }

    static func >= (lhs: InventoryQuantity, rhs: InventoryQuantity) -> Bool {
        guard lhs.unit.isCompatible(with: rhs.unit) else { return false }
        return lhs.baseAmount >= rhs.baseAmount
    }

    /// Liefert `true`, wenn der Bestand exakt oder echt unter `threshold`
    /// liegt. Liegt die Dimension nicht zueinander, wird `false`
    /// zurueckgegeben, damit Aufrufer den Fehler getrennt protokollieren
    /// koennen.
    func isBelow(_ threshold: InventoryQuantity) -> Bool {
        guard unit.isCompatible(with: threshold.unit) else { return false }
        return baseAmount < threshold.baseAmount
    }

    /// Deterministische Rundung in die Aufloesung der jeweiligen Dimension:
    /// - Masse/Volumen: 0,001 Basiseinheit (Milligramm bzw. Mikroliter)
    /// - Stueck: 1
    ///
    /// Verwendet `NSDecimalNumber` mit Modus `plain` (Half-up, away from
    /// zero), damit die Ergebnisse in Tests exakt reproduzierbar sind und
    /// nicht von Schwebe-Arithmetik abhaengen.
    static func round(_ value: Decimal, dimension: MeasurementUnit) -> Decimal {
        var input = value
        var output = Decimal()
        let scale: Int
        switch dimension {
        case .mass, .volume: scale = 3
        case .count: scale = 0
        }
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    /// Formatierte Anzeige in der Basiseinheit, locale-fest auf `de_DE`.
    func displayString() -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        switch unit {
        case .mass, .volume:
            formatter.maximumFractionDigits = 3
        case .count:
            formatter.maximumFractionDigits = 0
        }
        let number = formatter.string(from: baseAmount as NSDecimalNumber) ?? "0"
        return "\(number) \(unit.shortSymbol)"
    }
}

enum InventoryQuantityError: LocalizedError, Equatable {
    case negativeAmount(amount: Decimal, unit: MeasurementUnit)
    case nonFiniteAmount
    case incompatibleUnits(left: MeasurementUnit, right: MeasurementUnit)
    case negativeScalar(scalar: Int)

    var errorDescription: String? {
        switch self {
        case .negativeAmount(let amount, let unit):
            return "Negative Mengen sind nicht erlaubt (Betrag \(amount) in \(unit.displaySymbol))."
        case .nonFiniteAmount:
            return "Mengen muessen endlich sein."
        case .incompatibleUnits(let left, let right):
            return "Einheiten \(left.displaySymbol) und \(right.displaySymbol) sind nicht kombinierbar."
        case .negativeScalar(let scalar):
            return "Skalar \(scalar) muss >= 0 sein."
        }
    }
}
