import Foundation

/// Read-only Bestandsansicht für Betreiber:innen. Leitet sich ausschließlich
/// aus der echten `InventoryProjection` und `InventoryReplenishmentAdvisor`
/// der KL-INVENTORY-001-Domain ab — kein zweites Bestandsmodell, keine
/// Mockwerte. Buchen, Persistenz und Cloud-Sync bleiben bewusst vertagt
/// (siehe `INVENTORY_MODEL.md` §6/§7).
///
/// Rein Foundation, kein SwiftUI-Import: alle Zeilen- und Gruppen-Typen sind
/// wert-artig und ohne App-Abhängigkeit testbar (Muster:
/// `KitchenLinkV2TodayEvents.swift`).
///
/// Statusregel (`DESIGN_SYSTEM.md` §5/§6): Schwere wird auf die bestehende
/// 4-stufige Dringlichkeit abgebildet (`ok`→`neutral`, `warning`→`waiting`,
/// `critical`→`critical`). Zitrone taucht nirgends auf. Bis ein eigenes
/// `.stock`-Form-Muster vom Nutzer freigegeben ist, trägt die Zeile die
/// Dringlichkeit ausschließlich als Farbe auf dem Klartext-Verb — kein
/// generisches Symbol, das eine Operation vormacht, die es nicht gibt.
struct KitchenLinkV2InventoryStockRow: Identifiable, Equatable {
    let id: String
    let ingredientID: String
    let ingredientName: String
    let locationID: String
    let physical: InventoryQuantity
    let reserved: InventoryQuantity
    let available: InventoryQuantity
    let minimum: InventoryQuantity
    let target: InventoryQuantity
    let urgency: KitchenLinkV2Urgency
    let verb: String
    let detail: String
}

/// Lagerort-Sektion in der Bestandsansicht. Bündelt alle Zeilen eines
/// Lagerorts, damit die Ansicht sie als Gruppe rendern kann.
struct KitchenLinkV2InventoryLocationGroup: Identifiable, Equatable {
    let id: String
    let locationName: String
    let locationKind: StockLocation.Kind
    let rows: [KitchenLinkV2InventoryStockRow]
}

enum KitchenLinkV2InventoryStockProjection {
    /// Liefert die Bestandszeilen gruppiert nach Lagerort, sortiert nach
    /// operationaler Wichtigkeit (Küche vor Bar vor Lager/Keller/Eingang)
    /// und innerhalb jeder Gruppe nach Dringlichkeit, dann Zutatname.
    static func groups(
        catalog: InventoryCatalog,
        ledger: InventoryLedger
    ) throws -> [KitchenLinkV2InventoryLocationGroup] {
        let projection = InventoryProjection(catalog: catalog, ledger: ledger)
        let advisor = InventoryReplenishmentAdvisor(catalog: catalog, projection: projection)
        // `snapshot()` intentionally yields the complete cross product of all
        // ingredients and locations. Without a location-specific assortment
        // model, a pair with no ledger history does not mean "zero stock"; it
        // means "not known to be stocked here". Showing it as a shortage would
        // produce false operator alarms (for example wine in the kitchen).
        let snapshot = try projection.snapshot().filter { entry in
            !ledger.movements(
                ingredientID: entry.ingredientID,
                locationID: entry.locationID
            ).isEmpty
        }

        // Paare je Lagerort sammeln, Reihenfolge im Snapshot ist nicht
        // garantiert (Dictionary-Iteration), daher explizit gruppieren.
        var byLocation: [String: [InventorySnapshotEntry]] = [:]
        for entry in snapshot {
            byLocation[entry.locationID, default: []].append(entry)
        }

        var groups: [KitchenLinkV2InventoryLocationGroup] = []
        for (locationID, entries) in byLocation {
            let location = try catalog.location(id: locationID)
            let rows: [KitchenLinkV2InventoryStockRow] = try entries
                .map { entry in
                    let ingredient = try catalog.ingredient(id: entry.ingredientID)
                    let evaluation = try advisor.evaluate(
                        ingredientID: entry.ingredientID,
                        locationID: entry.locationID
                    )
                    let severity = evaluation.severity
                    return KitchenLinkV2InventoryStockRow(
                        id: entry.id,
                        ingredientID: entry.ingredientID,
                        ingredientName: ingredient.name,
                        locationID: entry.locationID,
                        physical: entry.physical,
                        reserved: entry.reserved,
                        available: entry.available,
                        minimum: evaluation.ingredient.minimumStock,
                        target: evaluation.ingredient.targetStock,
                        urgency: urgency(for: severity),
                        verb: verb(for: severity),
                        detail: detail(for: evaluation)
                    )
                }
                .sorted { lhs, rhs in
                    let lhsRank = urgencyRank(lhs.urgency)
                    let rhsRank = urgencyRank(rhs.urgency)
                    if lhsRank != rhsRank { return lhsRank < rhsRank }
                    return lhs.ingredientName.localizedCaseInsensitiveCompare(rhs.ingredientName) == .orderedAscending
                }

            groups.append(
                KitchenLinkV2InventoryLocationGroup(
                    id: locationID,
                    locationName: location.name,
                    locationKind: location.kind,
                    rows: rows
                )
            )
        }

        groups.sort { lhs, rhs in
            let lhsRank = locationKindRank(lhs.locationKind)
            let rhsRank = locationKindRank(rhs.locationKind)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.locationName.localizedCaseInsensitiveCompare(rhs.locationName) == .orderedAscending
        }
        return groups
    }

    /// Flache, ungruppierte Projektion aller Zeilen, sortiert nach Dringlichkeit
    /// dann Zutatname. Praktisch für Tests und künftige Such-/Filteransichten.
    static func rows(
        catalog: InventoryCatalog,
        ledger: InventoryLedger
    ) throws -> [KitchenLinkV2InventoryStockRow] {
        try groups(catalog: catalog, ledger: ledger).flatMap(\.rows)
    }

    /// Schwere → Dringlichkeit. `ok` wird bewusst auf `neutral` (nicht `fresh`)
    /// abgebildet: `fresh` ist im Bestandskontext keine sinnvolle Aussage —
    /// eine gut geführte Zutat ist schlicht vorhanden, kein Alarm.
    static func urgency(for severity: ReplenishmentEvaluation.Severity) -> KitchenLinkV2Urgency {
        switch severity {
        case .ok: return .neutral
        case .warning: return .waiting
        case .critical: return .critical
        }
    }

    /// Klartext-Verb je Schwere. Kurz und operationnal, für die einzeilige
    /// Zeile neben dem Bestandswert.
    static func verb(for severity: ReplenishmentEvaluation.Severity) -> String {
        switch severity {
        case .ok: return "verfügbar"
        case .warning: return "knapp"
        case .critical: return "kritisch"
        }
    }

    /// Kompakte, UI-taugliche Begruendung. Die vollstaendige Domain-Erklaerung
    /// bleibt am Advisor; hier vermeiden wir doppelte Zahlenkolonnen und zeigen
    /// den naechsten sinnvollen Kontext ohne Abschneiden.
    static func detail(for evaluation: ReplenishmentEvaluation) -> String {
        switch evaluation.severity {
        case .ok:
            return "Über Minimum \(evaluation.ingredient.minimumStock.displayString())"
        case .warning:
            return "Unter Minimum \(evaluation.ingredient.minimumStock.displayString()) · Ziel \(evaluation.ingredient.targetStock.displayString())"
        case .critical:
            return "Negativer Bestand · Buchungen prüfen"
        }
    }

    /// Dringlichkeits-Rang: kritisch oben, dann wartend, dann frisch, dann
    /// neutral. Spiegelt `KitchenLinkV2TodayEventBuilder.urgencyRank` aus
    /// der Heute-Ansicht, damit die Sortieraussage über alle V2-Oberflächen
    /// hinweg dieselbe bleibt.
    static func urgencyRank(_ urgency: KitchenLinkV2Urgency) -> Int {
        switch urgency {
        case .critical: return 0
        case .waiting: return 1
        case .fresh: return 2
        case .neutral: return 3
        }
    }

    /// Operationaler Rang eines Lagerorts. Die Küche steht als primärer
    /// Produktionsort oben, danach die Bar, danach Lager/Keller/Eingang —
    /// dort, wo Operatoren in der Regel nur gelegentlich nachsehen.
    static func locationKindRank(_ kind: StockLocation.Kind) -> Int {
        switch kind {
        case .kitchen: return 0
        case .bar: return 1
        case .storage: return 2
        case .cellar: return 3
        case .receiving: return 4
        }
    }
}
