import Foundation

/// KL-TABLE-002: Bestellaufnahme durch den Kellner.
///
/// Das ist der Pfad, den `DECISIONS.md` (Local-First, 23. Juli 2026) für den
/// Cloud-Ausfall vorsieht: „Gäste bestellen verbal, der Kellner erfasst die
/// Bestellung auf dem Service-iPhone. Der dauerhafte Speicher garantiert, dass
/// die Bestellung nicht verloren geht." Bis hierher gab es diesen Pfad im
/// Produkt nicht — `Service` konnte nur Status schalten.
///
/// Reihenfolge ist die eigentliche Aussage dieses Modells:
///
///   1. Die Bestellung wird **zuerst** im lokalen Ereignisprotokoll
///      festgeschrieben (`repository.createOrder`, append-only, idempotent).
///   2. Erst danach gilt sie als angenommen und wird dem Kellner bestätigt.
///   3. Die Cloud ist Folge, nicht Bedingung: der Outbox-Versand läuft
///      danach und darf scheitern, ohne die Bestellung zu gefährden.
///
/// Das ist dieselbe Regel wie beim Gast-Hub (KL-OFFLINE-004): kein ACK vor dem
/// dauerhaften Commit.

@MainActor
final class KitchenLinkWaiterOrderModel: ObservableObject {
    enum Phase: Equatable {
        case composing
        case placing
        /// Lokal dauerhaft festgeschrieben. `syncedToCloud` sagt, ob der
        /// anschließende Cloud-Versand in diesem Versuch geklappt hat.
        case placed(orderID: String, syncedToCloud: Bool)
        case failed(String)
    }

    /// Eine Position im Aufnahme-Bildschirm.
    struct Line: Identifiable, Equatable {
        let item: MenuItemData
        var quantity: Int

        var id: String { item.id }
        var lineTotalCents: Int { quantity * item.priceCents }
    }

    @Published private(set) var phase: Phase = .composing
    @Published private(set) var lines: [String: Line] = [:]
    @Published var selectedTable: KitchenLinkVenueTable?
    @Published var serviceMode: ServiceMode = .dineIn
    @Published var customerNote: String = ""

    private let repository: any KitchenLinkRepository
    private let venue: VenueProfile
    private let sections: [MenuSectionData]
    private let syncCloud: (() async -> Bool)?

    init(
        repository: any KitchenLinkRepository,
        venue: VenueProfile,
        sections: [MenuSectionData],
        syncCloud: (() async -> Bool)? = nil
    ) {
        self.repository = repository
        self.venue = venue
        self.sections = sections
        self.syncCloud = syncCloud
    }

    /// Nur verfügbare Artikel — ein ausverkauftes Gericht darf der Kellner
    /// genauso wenig aufnehmen wie der Gast es bestellen kann.
    var orderableSections: [MenuSectionData] {
        sections.compactMap { section in
            let items = section.items.filter(\.available)
            guard !items.isEmpty else { return nil }
            var copy = section
            copy.items = items
            return copy
        }
    }

    var totalCents: Int {
        lines.values.reduce(0) { $0 + $1.lineTotalCents }
    }

    var itemCount: Int {
        lines.values.reduce(0) { $0 + $1.quantity }
    }

    var isEmpty: Bool { itemCount == 0 }

    /// Ein Tisch ist Pflicht, sobald vor Ort serviert wird — sonst weiß die
    /// Küche nicht, wohin. Theke und Abholung kommen ohne aus.
    var requiresTable: Bool { serviceMode == .dineIn }

    var canPlace: Bool {
        guard !isEmpty, phase != .placing else { return false }
        return !requiresTable || selectedTable != nil
    }

    var placementBlockedReason: String? {
        if isEmpty { return "Noch keine Position aufgenommen." }
        if requiresTable && selectedTable == nil { return "Bitte einen Tisch wählen." }
        return nil
    }

    func quantity(for item: MenuItemData) -> Int {
        lines[item.id]?.quantity ?? 0
    }

    func increment(_ item: MenuItemData) {
        var line = lines[item.id] ?? Line(item: item, quantity: 0)
        guard line.quantity < 99 else { return }
        line.quantity += 1
        lines[item.id] = line
        resetAfterEdit()
    }

    func decrement(_ item: MenuItemData) {
        guard var line = lines[item.id] else { return }
        line.quantity -= 1
        if line.quantity <= 0 {
            lines.removeValue(forKey: item.id)
        } else {
            lines[item.id] = line
        }
        resetAfterEdit()
    }

    func reset() {
        lines = [:]
        customerNote = ""
        phase = .composing
    }

    /// Nimmt die Bestellung an: lokal festschreiben, dann Cloud versuchen.
    func place() async {
        guard canPlace else {
            phase = .failed(placementBlockedReason ?? "Bestellung unvollständig.")
            return
        }

        let table = requiresTable ? selectedTable : nil
        let message = LiveOrderMessage(
            id: UUID().uuidString.lowercased(),
            createdAt: Date(),
            sourceDevice: "Kellner · \(venue.name)",
            venueID: venue.id,
            venueName: venue.name,
            serviceMode: serviceMode,
            tableID: table?.id,
            tableLabel: table?.label,
            customerNote: customerNote.trimmingCharacters(in: .whitespacesAndNewlines),
            items: orderLines(),
            totalCents: totalCents,
            status: .pending
        )

        phase = .placing
        let placed: LiveOrderMessage
        do {
            // Bewusst synchron: der Schreibvorgang ist ein einzelner
            // SQLite-Commit, und ein Nebenläufigkeits-Umweg würde nur die
            // Reihenfolge verwischen, auf die es hier ankommt.
            placed = try repository.createOrder(message)
        } catch {
            // Kein ACK ohne dauerhaften Commit: der Kellner sieht den Fehler und
            // die Positionen bleiben stehen, damit nichts neu getippt wird.
            phase = .failed(Self.message(for: error))
            return
        }

        // Ab hier ist die Bestellung sicher. Der Cloud-Versand ist Beiwerk und
        // wird bei Misserfolg von der Outbox wiederholt.
        let synced = await syncCloud?() ?? false
        lines = [:]
        customerNote = ""
        phase = .placed(orderID: placed.id, syncedToCloud: synced)
    }

    private func orderLines() -> [LiveOrderLine] {
        lines.values
            .sorted { $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending }
            .map { line in
                LiveOrderLine(
                    id: line.item.id,
                    name: line.item.name,
                    quantity: line.quantity,
                    unitPriceCents: line.item.priceCents,
                    kind: line.item.kind
                )
            }
    }

    /// Nach einer Änderung ist eine vorherige Bestätigung nicht mehr gemeint.
    private func resetAfterEdit() {
        switch phase {
        case .placed, .failed:
            phase = .composing
        case .composing, .placing:
            break
        }
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
