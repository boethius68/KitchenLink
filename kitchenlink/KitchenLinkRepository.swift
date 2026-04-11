import Foundation

protocol KitchenLinkRepository {
    func loadVenueProfile(fallback: VenueProfile) -> VenueProfile
    func saveVenueProfile(_ venue: VenueProfile) throws
    func resolveQRCode(_ rawCode: String, venue: VenueProfile) -> ResolvedVenueContext?

    func loadMenuSections(fallback: [MenuSectionData]) -> [MenuSectionData]
    func saveMenuSections(_ sections: [MenuSectionData]) throws

    func loadOrders() throws -> [LiveOrderMessage]
    func loadOrder(orderID: String) throws -> LiveOrderMessage?
    func createOrder(_ order: LiveOrderMessage) throws -> LiveOrderMessage
    func updateOrderStatus(orderID: String, to status: OrderLifecycleStatus) throws -> LiveOrderMessage?
    func clearOrders() throws
}

final class LocalDemoRepository: KitchenLinkRepository {
    private let venueStorageKey = "kitchenlink.venue.v2"
    private let menuStorageKey = "kitchenlink.menu.v1"
    private let orderStorageKey = "kitchenlink.orders.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadVenueProfile(fallback: VenueProfile) -> VenueProfile {
        guard let data = defaults.data(forKey: venueStorageKey),
              let venue = try? decoder.decode(VenueProfile.self, from: data) else {
            return fallback
        }
        return venue
    }

    func saveVenueProfile(_ venue: VenueProfile) throws {
        let data = try encoder.encode(venue)
        defaults.set(data, forKey: venueStorageKey)
    }

    func loadMenuSections(fallback: [MenuSectionData]) -> [MenuSectionData] {
        guard let data = defaults.data(forKey: menuStorageKey),
              let sections = try? decoder.decode([MenuSectionData].self, from: data) else {
            return fallback
        }
        return sections
    }

    func saveMenuSections(_ sections: [MenuSectionData]) throws {
        let data = try encoder.encode(sections)
        defaults.set(data, forKey: menuStorageKey)
    }

    func resolveQRCode(_ rawCode: String, venue: VenueProfile) -> ResolvedVenueContext? {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }

        if code == LocalQRTokenCodec.sharedCode(slug: venue.slug) {
            return ResolvedVenueContext(
                token: code,
                venue: venue,
                mode: .venueShared,
                resolvedTable: nil
            )
        }

        if let matchedTable = venue.tables.first(where: {
            LocalQRTokenCodec.tableCode(slug: venue.slug, tableLabel: $0.label) == code
        }) {
            return ResolvedVenueContext(
                token: code,
                venue: venue,
                mode: .table,
                resolvedTable: matchedTable
            )
        }

        guard let parsedCode = LocalQRTokenCodec.parse(code),
              parsedCode.slug.caseInsensitiveCompare(venue.slug) == .orderedSame else {
            return nil
        }

        switch parsedCode.mode {
        case .venueShared:
            return ResolvedVenueContext(
                token: code,
                venue: venue,
                mode: .venueShared,
                resolvedTable: nil
            )

        case .table:
            guard let tableLabel = parsedCode.tableLabel,
                  let matchedTable = venue.tables.first(where: {
                      $0.label.caseInsensitiveCompare(tableLabel) == .orderedSame
                  }) else {
                return nil
            }

            return ResolvedVenueContext(
                token: code,
                venue: venue,
                mode: .table,
                resolvedTable: matchedTable
            )
        }
    }

    func loadOrders() throws -> [LiveOrderMessage] {
        guard let data = defaults.data(forKey: orderStorageKey) else {
            return []
        }

        let orders = try decoder.decode([LiveOrderMessage].self, from: data)
        return orders.sorted { $0.createdAt > $1.createdAt }
    }

    func loadOrder(orderID: String) throws -> LiveOrderMessage? {
        try loadOrders().first(where: { $0.id == orderID })
    }

    func createOrder(_ order: LiveOrderMessage) throws -> LiveOrderMessage {
        var orders = try loadOrders()
        let savedOrder = order.with(id: order.id.isEmpty ? UUID().uuidString.lowercased() : order.id, status: .pending)

        orders.removeAll { $0.id == savedOrder.id }
        orders.insert(savedOrder, at: 0)
        try persistOrders(orders)
        return savedOrder
    }

    func updateOrderStatus(orderID: String, to status: OrderLifecycleStatus) throws -> LiveOrderMessage? {
        var orders = try loadOrders()
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            return nil
        }

        let updatedOrder = orders[index].with(id: orders[index].id, status: status)
        orders[index] = updatedOrder
        try persistOrders(orders)
        return updatedOrder
    }

    func clearOrders() throws {
        defaults.removeObject(forKey: orderStorageKey)
    }

    private func persistOrders(_ orders: [LiveOrderMessage]) throws {
        let data = try encoder.encode(orders)
        defaults.set(data, forKey: orderStorageKey)
    }
}

enum LocalQRTokenCodec {
    static let scheme = "kitchenlink"

    static func sharedCode(slug: String) -> String {
        "\(scheme)://venue/\(slug)/shared"
    }

    static func tableCode(slug: String, tableLabel: String) -> String {
        let encodedLabel = tableLabel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tableLabel
        return "\(scheme)://table/\(slug)/\(encodedLabel)"
    }

    static func parse(_ rawCode: String) -> ParsedQRCode? {
        guard let url = URL(string: rawCode), url.scheme == scheme else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        switch url.host?.lowercased() {
        case "venue":
            guard pathComponents.count == 2,
                  pathComponents[1].lowercased() == "shared" else {
                return nil
            }
            return ParsedQRCode(
                slug: pathComponents[0].lowercased(),
                mode: .venueShared,
                tableLabel: nil
            )

        case "table":
            guard pathComponents.count == 2 else {
                return nil
            }
            return ParsedQRCode(
                slug: pathComponents[0].lowercased(),
                mode: .table,
                tableLabel: pathComponents[1].removingPercentEncoding ?? pathComponents[1]
            )

        default:
            return nil
        }
    }
}

struct ParsedQRCode {
    let slug: String
    let mode: QRContextMode
    let tableLabel: String?
}
