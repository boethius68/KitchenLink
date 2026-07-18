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
}
