import Foundation
import Testing
@testable import kitchenlink

/// Unit-Tests für die read-only Bestandsprojektion der V2-Bestand-Ansicht.
/// Rein Foundation — kein Relay, kein Repository, kein SwiftUI. Muster analog
/// `KitchenLinkV2TodayEventsTests`. Die darunterliegende Domain (`InventoryProjection`,
/// `ReplenishmentEvaluation`, Fixture) ist durch MiniMaxs 53 Tests bereits
/// abgedeckt; hier wird ausschließlich die UI-seitige Projektion und die
/// Schwere→Dringlichkeit-Abbildung geprüft.
struct KitchenLinkV2InventoryStockProjectionTests {

    // MARK: - Severity → Urgency Mapping

    @Test
    func severityOkMapsToNeutral() {
        #expect(
            KitchenLinkV2InventoryStockProjection.urgency(for: .ok) == .neutral
        )
        #expect(
            KitchenLinkV2InventoryStockProjection.verb(for: .ok) == "verfügbar"
        )
    }

    @Test
    func severityWarningMapsToWaiting() {
        #expect(
            KitchenLinkV2InventoryStockProjection.urgency(for: .warning) == .waiting
        )
        #expect(
            KitchenLinkV2InventoryStockProjection.verb(for: .warning) == "knapp"
        )
    }

    @Test
    func severityCriticalMapsToCritical() {
        #expect(
            KitchenLinkV2InventoryStockProjection.urgency(for: .critical) == .critical
        )
        #expect(
            KitchenLinkV2InventoryStockProjection.verb(for: .critical) == "kritisch"
        )
    }

    // MARK: - Leerer Katalog

    @Test
    func emptyCatalogProducesNoGroups() throws {
        let catalog = try InventoryCatalog()
        let ledger = InventoryLedger(catalog: catalog)
        let groups = try KitchenLinkV2InventoryStockProjection.groups(
            catalog: catalog,
            ledger: ledger
        )
        #expect(groups.isEmpty)
    }

    // MARK: - Sandbox-Fixture

    @Test
    func fixtureProducesBothLocations() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let groups = try KitchenLinkV2InventoryStockProjection.groups(
            catalog: catalog,
            ledger: ledger
        )

        // Fixture definiert 2 Lagerorte (Küche, Bar).
        #expect(groups.count == 2)

        let kinds = Set(groups.map(\.locationKind))
        #expect(kinds.contains(.kitchen))
        #expect(kinds.contains(.bar))
    }

    @Test
    func fixtureRowTotalMatchesCrossProduct() throws {
        // 12 Zutaten × 2 Lagerorte = 24 Projektionszeilen.
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        #expect(rows.count == 24)
    }

    @Test
    func fixtureSurfacesAtLeastOneCriticalRow() throws {
        // Die Fixture zeichnet absichtlich einen Basilikum-Verderb und
        // Verbrauch ab, sodass mindestens ein Paar negativ oder unter dem
        // Mindestbestand liegt. Die UI muss das sichtbar machen.
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        #expect(rows.contains { $0.urgency == .critical })
    }

    @Test
    func rowsAreSortedByUrgencyThenIngredientName() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        // Innerhalb jeder Lagerort-Gruppe muss die Reihenfolge
        // critical < waiting < fresh < neutral sein, dann alphabetisch.
        // Wir verifizieren nur das Monotonieversprechen pro Gruppe; die
        // exakte Reihenfolge ist durch die Fixture determiniert.
        for group in try KitchenLinkV2InventoryStockProjection.groups(
            catalog: catalog,
            ledger: ledger
        ) {
            let ranks = group.rows.map {
                KitchenLinkV2InventoryStockProjection.urgencyRank($0.urgency)
            }
            let sortedRanks = ranks.sorted()
            #expect(ranks == sortedRanks)
        }
    }

    @Test
    func kitchenSortsAheadOfBar() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let groups = try KitchenLinkV2InventoryStockProjection.groups(
            catalog: catalog,
            ledger: ledger
        )
        // Erste Gruppe ist die Küche (operationaler Rang 0), zweite die Bar.
        #expect(groups.first?.locationKind == .kitchen)
        #expect(groups.last?.locationKind == .bar)
    }

    // MARK: - Zeilenform

    @Test
    func rowCarriesResolvedIngredientName() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        // Namen dürfen nicht leer sein und müssen im Katalog auflösbar sein.
        for row in rows {
            let ingredient = try catalog.ingredient(id: row.ingredientID)
            #expect(row.ingredientName == ingredient.name)
            #expect(row.ingredientName.isEmpty == false)
        }
    }

    @Test
    func rowExposesPhysicalReservedAvailable() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        // available muss == physical - reserved sein (die Domain definiert
        // das so; die Projektion reicht es durch).
        for row in rows {
            let expected = try row.physical - row.reserved
            #expect(row.available == expected)
        }
    }

    @Test
    func rowExposesExplanation() throws {
        let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
        let rows = try KitchenLinkV2InventoryStockProjection.rows(
            catalog: catalog,
            ledger: ledger
        )
        for row in rows {
            #expect(row.explanation.isEmpty == false)
        }
    }
}
