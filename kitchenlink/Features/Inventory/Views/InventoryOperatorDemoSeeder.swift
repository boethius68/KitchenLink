import Foundation

/// Seeded die Bestandsansicht mit der deterministischen Sandbox-Fixture aus
/// KL-INVENTORY-001 (`InventorySandboxFixture.makePopulatedLedger()`). Kein
/// zweites Modell, keine erfundenen Bestände: die Ansicht sieht exakt die
/// Zutaten, Rezepte und Bewegungen, gegen die die 53 Inventory-Domain-Tests
/// schon laufen. Muster analog `KitchenLinkV2DemoOperationsSeeder`, nur dass
/// der Inventory-Pfad keine Order-Relay berührt.
@MainActor
enum InventoryOperatorDemoSeeder {
    /// Lädt die Sandbox-Fixture in das Model und liefert die Anzahl Zeilen,
    /// die nach der Projektion sichtbar sind.
    @discardableResult
    static func seed(
        into model: InventoryOperatorModel
    ) -> Int {
        do {
            let (catalog, ledger) = try InventorySandboxFixture.makePopulatedLedger()
            model.load(catalog: catalog, ledger: ledger)
            return model.totalRowCount
        } catch {
            model.statusMessage = "Demo-Szenario konnte nicht geladen werden: \(error.localizedDescription)"
            return 0
        }
    }
}
