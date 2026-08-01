import Foundation

/// KL-STATION-001 und KL-ORDER-001: Stationsfreigabe und Annahmeregel.
///
/// Getrenntes Protokoll neben `KitchenLinkCloudTransport`, damit dessen
/// Test-Spies unberührt bleiben; die konkrete
/// `URLSessionKitchenLinkCloudTransport` erfüllt beide.

struct KitchenLinkStationReceipt: Equatable, Sendable {
    let orderID: String
    let station: KitchenLinkStation
    let itemsMarked: Int
    /// Stationen, die an dieser Bestellung noch arbeiten.
    let openStations: [KitchenLinkStation]
    let orderReady: Bool

    static func decode(_ data: Data) throws -> KitchenLinkStationReceipt {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let orderID = root["order_id"] as? String,
              let stationRaw = root["station"] as? String,
              let station = KitchenLinkStation(rawValue: stationRaw) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let open = (root["open_stations"] as? [String] ?? [])
            .compactMap(KitchenLinkStation.init(rawValue:))
        return KitchenLinkStationReceipt(
            orderID: orderID,
            station: station,
            itemsMarked: root["items_marked"] as? Int ?? 0,
            openStations: open,
            orderReady: root["order_ready"] as? Bool ?? false
        )
    }
}

protocol KitchenLinkStationTransport: Sendable {
    func markStationReady(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        orderID: String,
        station: KitchenLinkStation
    ) async throws -> KitchenLinkStationReceipt

    func rejectOrder(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        orderID: String,
        reason: String
    ) async throws

    /// Kanäle, die vor der Zubereitung bestätigt werden müssen. Leer heißt:
    /// alles läuft automatisch durch (Blueprint §6.3, Standardfall).
    func loadConfirmationChannels(
        config: KitchenLinkCloudConfig,
        venueSlug: String
    ) async throws -> [ServiceMode]

    func setConfirmationChannels(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        channels: [ServiceMode]
    ) async throws
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkStationTransport {
    func markStationReady(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        orderID: String,
        station: KitchenLinkStation
    ) async throws -> KitchenLinkStationReceipt {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_order_id: String
            let p_station: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_mark_station_ready",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_order_id: orderID,
                    p_station: station.rawValue
                )
            )
        )
        return try KitchenLinkStationReceipt.decode(data)
    }

    func rejectOrder(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        orderID: String,
        reason: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_order_id: String
            let p_reason: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_reject_order",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_order_id: orderID, p_reason: reason)
            )
        )
    }

    func loadConfirmationChannels(
        config: KitchenLinkCloudConfig,
        venueSlug: String
    ) async throws -> [ServiceMode] {
        struct Row: Decodable {
            let orderConfirmationChannels: [String]?

            enum CodingKeys: String, CodingKey {
                case orderConfirmationChannels = "order_confirmation_channels"
            }
        }
        let data = try await restGet(
            config: config,
            accessToken: config.anonKey,
            path: "rest/v1/venues",
            queryItems: [
                URLQueryItem(name: "select", value: "order_confirmation_channels"),
                URLQueryItem(name: "slug", value: "eq.\(venueSlug)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return (rows.first?.orderConfirmationChannels ?? [])
            .compactMap(ServiceMode.init(rawValue:))
    }

    func setConfirmationChannels(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        channels: [ServiceMode]
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_channels: [String]
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_set_confirmation_channels",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_channels: channels.map(\.rawValue))
            )
        )
    }
}

/// Reine Regel: braucht diese Bestellung eine Bestätigung, bevor die Station
/// sie sieht? (Blueprint §6.3)
enum KitchenLinkOrderAcceptance {
    static func needsConfirmation(
        order: LiveOrderMessage,
        confirmationChannels: [ServiceMode]
    ) -> Bool {
        guard order.status == .pending else { return false }
        guard let mode = order.serviceMode else {
            // Ohne erkennbaren Kanal gilt die strengere Auslegung: sobald der
            // Betrieb überhaupt eine Bestätigungspflicht hat, wird bestätigt.
            return !confirmationChannels.isEmpty
        }
        return confirmationChannels.contains(mode)
    }

    /// Was die Station sieht: alles, was nicht auf Bestätigung wartet.
    static func stationVisible(
        orders: [LiveOrderMessage],
        confirmationChannels: [ServiceMode]
    ) -> [LiveOrderMessage] {
        orders.filter {
            !needsConfirmation(order: $0, confirmationChannels: confirmationChannels)
        }
    }

    static func awaitingConfirmation(
        orders: [LiveOrderMessage],
        confirmationChannels: [ServiceMode]
    ) -> [LiveOrderMessage] {
        orders.filter {
            needsConfirmation(order: $0, confirmationChannels: confirmationChannels)
        }
    }
}
