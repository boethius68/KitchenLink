import Combine
import Foundation

struct LiveOrderLine: Identifiable, Codable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kind: MenuItemKind

    var lineTotalCents: Int {
        quantity * unitPriceCents
    }
}

struct LiveOrderMessage: Identifiable, Codable {
    let id: String
    let createdAt: Date
    let sourceDevice: String
    let venueID: String?
    let venueName: String?
    let serviceMode: ServiceMode?
    let tableID: String?
    let tableLabel: String?
    let customerNote: String
    let items: [LiveOrderLine]
    let totalCents: Int
    let status: OrderLifecycleStatus

    var operatorContextLine: String {
        let segments: [String] = [
            venueName,
            serviceMode?.title,
            tableLabel.map { "Tisch \($0)" }
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        if segments.isEmpty {
            return sourceDevice
        }
        return segments.joined(separator: " · ")
    }

    var sourceDeviceLine: String? {
        let trimmed = sourceDevice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "Gerät: \(trimmed)"
    }

    func with(id newID: String, status newStatus: OrderLifecycleStatus) -> LiveOrderMessage {
        LiveOrderMessage(
            id: newID,
            createdAt: createdAt,
            sourceDevice: sourceDevice,
            venueID: venueID,
            venueName: venueName,
            serviceMode: serviceMode,
            tableID: tableID,
            tableLabel: tableLabel,
            customerNote: customerNote,
            items: items,
            totalCents: totalCents,
            status: newStatus
        )
    }
}

enum SupabaseCapability: String, CaseIterable, Identifiable {
    case venues
    case tables
    case menus
    case menuCategories = "menu_categories"
    case menuItems = "menu_items"
    case qrTokens = "qr_tokens"
    case orders
    case orderItems = "order_items"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .venues:
            return "Venues"
        case .tables:
            return "Tables"
        case .menus:
            return "Menus"
        case .menuCategories:
            return "Menu Categories"
        case .menuItems:
            return "Menu Items"
        case .qrTokens:
            return "QR Tokens"
        case .orders:
            return "Orders"
        case .orderItems:
            return "Order Items"
        }
    }

    var selectField: String {
        switch self {
        case .qrTokens:
            return "token"
        default:
            return "id"
        }
    }

    var isCoreProductSchema: Bool {
        switch self {
        case .venues, .tables, .menus, .menuCategories, .menuItems, .qrTokens:
            return true
        case .orders, .orderItems:
            return false
        }
    }
}

struct SupabaseCapabilityStatus: Identifiable, Hashable {
    let capability: SupabaseCapability
    let isAvailable: Bool
    let detail: String

    var id: String { capability.id }
}

@MainActor
final class OrderRelayService: ObservableObject {
    enum Mode {
        case idle
        case owner
        case customer
    }

    private enum RemoteOrderSchemaMode {
        case enriched
        case legacy
    }

    private enum QRTokenSchemaAvailability {
        case unknown
        case available
        case unavailable
    }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var connectionText = "Nicht verbunden"
    @Published private(set) var isConnected = false
    @Published var receivedOrders: [LiveOrderMessage] = []
    @Published var trackedCustomerOrder: LiveOrderMessage?
    @Published private(set) var supabaseCapabilities: [SupabaseCapabilityStatus] = []
    @Published private(set) var isInspectingSupabase = false

    private let repository: any KitchenLinkRepository
    private let supabaseBaseURL = URL(string: "https://kiqboyshhsogvdvnleup.supabase.co/rest/v1")!
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtpcWJveXNoaHNvZ3Zkdm5sZXVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MjM1MDcsImV4cCI6MjA4NzE5OTUwN30.50-vumCzVs3BNhLrwgqZY6v0ZvAcqBU4P8Crrg0gBdc"
    private var pollingTask: Task<Void, Never>?
    private var trackedOrderTask: Task<Void, Never>?
    private var readSchemaMode: RemoteOrderSchemaMode = .enriched
    private var writeSchemaMode: RemoteOrderSchemaMode = .enriched
    private var qrTokenSchemaAvailability: QRTokenSchemaAvailability = .unknown
    private let session = URLSession.shared

    init(repository: any KitchenLinkRepository = LocalDemoRepository()) {
        self.repository = repository
    }

    func startHostingAsOwner() {
        guard mode != .owner else {
            return
        }
        trackedOrderTask?.cancel()
        trackedOrderTask = nil
        mode = .owner
        isConnected = true
        connectionText = "Lokales Demo-Backend aktiv"
        startPollingOrders()
    }

    func startBrowsingAsCustomer() {
        guard mode != .customer else {
            return
        }
        mode = .customer
        isConnected = true
        connectionText = "Lokales Demo-Backend aktiv"
    }

    func send(order: LiveOrderMessage) async -> LiveOrderMessage? {
        do {
            let placedOrder = try repository.createOrder(order.with(id: order.id, status: .pending))
            if mode == .owner {
                try await loadOrdersFromBackend()
            }
            connectionText = "Lokales Demo-Backend aktiv"
            isConnected = true
            return placedOrder
        } catch {
            connectionText = "Lokaler Speicherfehler: \(error.localizedDescription)"
            isConnected = false
            return nil
        }
    }

    func clearReceivedOrders() {
        do {
            try repository.clearOrders()
            receivedOrders.removeAll()
            trackedCustomerOrder = nil
            connectionText = "Lokale Bestellungen geleert"
            isConnected = true
        } catch {
            connectionText = "Lokaler Speicherfehler: \(error.localizedDescription)"
            isConnected = false
        }
    }

    func startTrackingCustomerOrder(orderID: String) {
        trackedOrderTask?.cancel()
        mode = .customer
        trackedOrderTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let order = try await self.loadTrackedOrder(orderID: orderID)
                    self.trackedCustomerOrder = order
                    self.connectionText = "Lokaler Bestellstatus wird aktualisiert"
                    self.isConnected = true
                } catch {
                    self.connectionText = "Lokaler Speicherfehler: \(error.localizedDescription)"
                    self.isConnected = false
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopTrackingCustomerOrder() {
        trackedOrderTask?.cancel()
        trackedOrderTask = nil
        trackedCustomerOrder = nil
    }

    func updateStatus(for order: LiveOrderMessage, to newStatus: OrderLifecycleStatus) async -> Bool {
        guard order.status.canTransition(to: newStatus) else {
            connectionText = "Ungueltiger Statuswechsel"
            return false
        }

        do {
            guard let updatedOrder = try repository.updateOrderStatus(orderID: order.id, to: newStatus) else {
                connectionText = "Bestellung nicht gefunden"
                return false
            }
            try await loadOrdersFromBackend()

            if trackedCustomerOrder?.id == order.id {
                trackedCustomerOrder = updatedOrder
            }

            connectionText = "Lokales Demo-Backend aktiv"
            isConnected = true
            return true
        } catch {
            connectionText = "Lokaler Speicherfehler: \(error.localizedDescription)"
            isConnected = false
            return false
        }
    }

    func stopNetworking(keepMode: Bool = false) {
        pollingTask?.cancel()
        pollingTask = nil
        trackedOrderTask?.cancel()
        trackedOrderTask = nil

        if !keepMode {
            mode = .idle
            isConnected = false
            connectionText = "Nicht verbunden"
            trackedCustomerOrder = nil
        }
    }

    func syncVenueProfile(_ venue: VenueProfile) async throws -> VenueProfile {
        let remoteVenue = try await fetchRemoteVenue(slug: venue.slug)

        var reconciledVenue = venue
        if let remoteVenue {
            reconciledVenue.id = remoteVenue.id
        }

        let remoteTables = try await fetchRemoteTables(venueID: reconciledVenue.id)
        reconciledVenue.tables = venue.tables.map { localTable in
            if let matchingRemoteTable = remoteTables.first(where: {
                $0.label.caseInsensitiveCompare(localTable.label) == .orderedSame
            }) {
                return VenueTable(
                    id: matchingRemoteTable.id,
                    label: localTable.label,
                    isActive: localTable.isActive
                )
            }
            return localTable
        }

        _ = try await upsertRemoteVenue(reconciledVenue)
        try await upsertRemoteTables(reconciledVenue.tables, venueID: reconciledVenue.id)
        try await deleteRemoteTables(
            venueID: reconciledVenue.id,
            keepingTableIDs: reconciledVenue.tables.map(\.id)
        )
        return reconciledVenue
    }

    func loadVenueProfile(
        slug: String,
        fallbackServiceModes: [ServiceMode]
    ) async throws -> VenueProfile {
        guard let remoteVenue = try await fetchRemoteVenue(slug: slug) else {
            throw SupabaseVenueSyncError.venueNotFound
        }

        return try await buildVenueProfile(
            from: remoteVenue,
            fallbackServiceModes: fallbackServiceModes
        )
    }

    func probeSupabaseCapabilities() async {
        guard !isInspectingSupabase else { return }
        isInspectingSupabase = true
        defer { isInspectingSupabase = false }

        var statuses: [SupabaseCapabilityStatus] = []
        for capability in SupabaseCapability.allCases {
            let status = await inspectSupabaseCapability(capability)
            statuses.append(status)
        }
        supabaseCapabilities = statuses
    }

    func syncQRTokens(for venue: VenueProfile) async throws -> Int {
        let remoteTokens = makeRemoteQRTokens(for: venue)
        do {
            try await upsertRemoteQRTokens(remoteTokens)
            try await deleteRemoteQRTokens(
                venueID: venue.id,
                keepingTokens: remoteTokens.map(\.token)
            )
            qrTokenSchemaAvailability = .available
            connectionText = "Supabase-QR-Tokens synchronisiert"
            isConnected = true
            return remoteTokens.count
        } catch {
            if shouldTreatAsMissingQRTokenSchema(after: error) {
                qrTokenSchemaAvailability = .unavailable
                connectionText = "Supabase online, aber qr_tokens fehlt noch"
                isConnected = true
                throw SupabaseQRTokenSyncError.schemaUnavailable
            }

            connectionText = "Supabase-QR-Sync fehlgeschlagen: \(error.localizedDescription)"
            isConnected = false
            throw error
        }
    }

    func resolveRemoteQRCode(
        _ rawCode: String,
        fallbackServiceModes: [ServiceMode] = ServiceMode.allCases
    ) async throws -> ResolvedVenueContext? {
        let token = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }

        if qrTokenSchemaAvailability != .unavailable {
            do {
                if let remoteToken = try await fetchRemoteQRToken(token) {
                    qrTokenSchemaAvailability = .available

                    guard remoteToken.isUsable,
                          let mode = QRContextMode(backendValue: remoteToken.modeRaw),
                          let remoteVenue = try await fetchRemoteVenue(id: remoteToken.venueID) else {
                        return nil
                    }

                    let venue = try await buildVenueProfile(
                        from: remoteVenue,
                        fallbackServiceModes: fallbackServiceModes
                    )
                    let resolvedTable = remoteToken.tableID.flatMap { tableID in
                        venue.tables.first(where: { $0.id == tableID })
                    }

                    if mode == .table, remoteToken.tableID != nil, resolvedTable == nil {
                        return nil
                    }

                    connectionText = "Supabase-QR-Kontext geladen"
                    isConnected = true
                    return ResolvedVenueContext(
                        token: token,
                        venue: venue,
                        mode: mode,
                        resolvedTable: resolvedTable
                    )
                }

                return nil
            } catch {
                if shouldTreatAsMissingQRTokenSchema(after: error) {
                    qrTokenSchemaAvailability = .unavailable
                } else {
                    connectionText = "Supabase-QR-Aufloesung fehlgeschlagen: \(error.localizedDescription)"
                    isConnected = false
                    throw error
                }
            }
        }

        guard let parsedCode = LocalQRTokenCodec.parse(token),
              let remoteVenue = try await fetchRemoteVenue(slug: parsedCode.slug) else {
            return nil
        }

        let venue = try await buildVenueProfile(
            from: remoteVenue,
            fallbackServiceModes: fallbackServiceModes
        )

        switch parsedCode.mode {
        case .venueShared:
            connectionText = "Supabase-Venue-Kontext geladen (Beta-Fallback)"
            isConnected = true
            return ResolvedVenueContext(
                token: token,
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

            connectionText = "Supabase-Tischkontext geladen (Beta-Fallback)"
            isConnected = true
            return ResolvedVenueContext(
                token: token,
                venue: venue,
                mode: .table,
                resolvedTable: matchedTable
            )
        }
    }

    private func startPollingOrders() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.mode == .owner {
                do {
                    try await self.loadOrdersFromBackend()
                    self.connectionText = "Lokales Demo-Backend aktiv"
                    self.isConnected = true
                } catch {
                    self.connectionText = "Lokaler Speicherfehler: \(error.localizedDescription)"
                    self.isConnected = false
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func loadOrdersFromBackend() async throws {
        receivedOrders = try repository.loadOrders()
    }

    private func loadTrackedOrder(orderID: String) async throws -> LiveOrderMessage {
        guard let order = try repository.loadOrder(orderID: orderID) else {
            throw URLError(.badServerResponse)
        }
        return order
    }

    private func createRemoteOrder(_ order: LiveOrderMessage) async throws -> SupabaseInsertedOrder {
        do {
            return try await createRemoteOrder(order, using: writeSchemaMode)
        } catch {
            guard writeSchemaMode == .enriched, shouldFallbackToLegacySchema(after: error) else {
                throw error
            }

            writeSchemaMode = .legacy
            return try await createRemoteOrder(order, using: .legacy)
        }
    }

    private func createRemoteOrderItems(orderID: String, lines: [LiveOrderLine]) async throws {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("order_items"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)

        let payload = lines.map {
            SupabaseCreateOrderItemRequest(
                orderID: orderID,
                name: $0.name,
                quantity: $0.quantity,
                unitPriceCents: $0.unitPriceCents,
                kind: $0.kind.rawValue
            )
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func patchOrderStatus(orderID: String, to status: OrderLifecycleStatus) async throws {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("orders"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(orderID)")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        applySupabaseHeaders(to: &request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(
            SupabasePatchOrderStatusRequest(status: status.rawValue)
        )

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func applySupabaseHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    }

    private func loadOrderRows(orderID: String? = nil) async throws -> [SupabaseOrderRow] {
        do {
            return try await loadOrderRows(using: readSchemaMode, orderID: orderID)
        } catch {
            guard readSchemaMode == .enriched, shouldFallbackToLegacySchema(after: error) else {
                throw error
            }

            readSchemaMode = .legacy
            return try await loadOrderRows(using: .legacy, orderID: orderID)
        }
    }

    private func loadOrderRows(
        using schemaMode: RemoteOrderSchemaMode,
        orderID: String? = nil
    ) async throws -> [SupabaseOrderRow] {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("orders"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "select", value: selectClause(for: schemaMode)),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: orderID == nil ? "50" : "1")
        ]

        if let orderID {
            queryItems.append(URLQueryItem(name: "id", value: "eq.\(orderID)"))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseOrderRow].self, from: data)
    }

    private func createRemoteOrder(
        _ order: LiveOrderMessage,
        using schemaMode: RemoteOrderSchemaMode
    ) async throws -> SupabaseInsertedOrder {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("orders"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = [
            SupabaseCreateOrderRequest(
                sourceDevice: order.sourceDevice,
                totalCents: order.totalCents,
                status: "pending",
                venueID: schemaMode == .enriched ? order.venueID : nil,
                tableID: schemaMode == .enriched ? order.tableID : nil,
                serviceMode: schemaMode == .enriched ? order.serviceMode?.rawValue : nil,
                customerNote: schemaMode == .enriched ? order.customerNote : nil
            )
        ]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        guard let created = try JSONDecoder().decode([SupabaseInsertedOrder].self, from: data).first else {
            throw URLError(.badServerResponse)
        }
        return created
    }

    private func fetchRemoteVenue(slug: String) async throws -> SupabaseVenueRecord? {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("venues"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,name,slug"),
            URLQueryItem(name: "slug", value: "eq.\(slug)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseVenueRecord].self, from: data).first
    }

    private func inspectSupabaseCapability(_ capability: SupabaseCapability) async -> SupabaseCapabilityStatus {
        var components = URLComponents(
            url: supabaseBaseURL.appendingPathComponent(capability.rawValue),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: capability.selectField),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return SupabaseCapabilityStatus(
                capability: capability,
                isAvailable: true,
                detail: "Erreichbar"
            )
        } catch let error as SupabaseRequestError {
            let normalizedBody = error.body.lowercased()
            if error.statusCode == 404 && normalizedBody.contains("schema cache") {
                return SupabaseCapabilityStatus(
                    capability: capability,
                    isAvailable: false,
                    detail: "Fehlt im Schema-Cache"
                )
            }

            return SupabaseCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: "HTTP \(error.statusCode)"
            )
        } catch {
            return SupabaseCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: error.localizedDescription
            )
        }
    }

    private func fetchRemoteVenue(id: String) async throws -> SupabaseVenueRecord? {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("venues"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,name,slug"),
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseVenueRecord].self, from: data).first
    }

    private func fetchRemoteTables(venueID: String) async throws -> [SupabaseTableRecord] {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("tables"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,venue_id,label,active"),
            URLQueryItem(name: "venue_id", value: "eq.\(venueID)"),
            URLQueryItem(name: "order", value: "label.asc"),
            URLQueryItem(name: "limit", value: "200")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseTableRecord].self, from: data)
    }

    private func upsertRemoteVenue(_ venue: VenueProfile) async throws -> SupabaseVenueRecord {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("venues"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")

        request.httpBody = try JSONEncoder().encode([
            SupabaseUpsertVenueRequest(
                id: venue.id,
                name: venue.name,
                slug: venue.slug,
                timezone: "Europe/Berlin"
            )
        ])

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        guard let upsertedVenue = try JSONDecoder().decode([SupabaseVenueRecord].self, from: data).first else {
            throw URLError(.badServerResponse)
        }
        return upsertedVenue
    }

    private func upsertRemoteTables(_ tables: [VenueTable], venueID: String) async throws {
        guard !tables.isEmpty else { return }

        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("tables"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        request.httpBody = try JSONEncoder().encode(
            tables.map {
                SupabaseUpsertTableRequest(
                    id: $0.id,
                    venueID: venueID,
                    label: $0.label,
                    active: $0.isActive
                )
            }
        )

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func fetchRemoteQRToken(_ token: String) async throws -> SupabaseQRTokenRecord? {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("qr_tokens"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "token,venue_id,table_id,mode,active,expires_at"),
            URLQueryItem(name: "token", value: "eq.\(token)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseQRTokenRecord].self, from: data).first
    }

    private func upsertRemoteQRTokens(_ tokens: [SupabaseUpsertQRTokenRequest]) async throws {
        guard !tokens.isEmpty else { return }

        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("qr_tokens"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(tokens)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    private func deleteRemoteQRTokens(venueID: String, keepingTokens: [String]) async throws {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("qr_tokens"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "venue_id", value: "eq.\(venueID)")
        ]

        if !keepingTokens.isEmpty {
            let quotedTokens = keepingTokens
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
                .joined(separator: ",")
            queryItems.append(
                URLQueryItem(name: "token", value: "not.in.(\(quotedTokens))")
            )
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    private func buildVenueProfile(
        from remoteVenue: SupabaseVenueRecord,
        fallbackServiceModes: [ServiceMode]
    ) async throws -> VenueProfile {
        let remoteTables = try await fetchRemoteTables(venueID: remoteVenue.id)
            .sorted { lhs, rhs in
                lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
            }
        let supportedModes = fallbackServiceModes.isEmpty ? ServiceMode.allCases : fallbackServiceModes
        return VenueProfile(
            id: remoteVenue.id,
            name: remoteVenue.name,
            slug: remoteVenue.slug,
            supportedServiceModes: supportedModes,
            tables: remoteTables.map {
                VenueTable(
                    id: $0.id,
                    label: $0.label,
                    isActive: $0.active
                )
            }
        )
    }

    private func makeRemoteQRTokens(for venue: VenueProfile) -> [SupabaseUpsertQRTokenRequest] {
        let sharedToken = SupabaseUpsertQRTokenRequest(
            token: LocalQRTokenCodec.sharedCode(slug: venue.slug),
            venueID: venue.id,
            tableID: nil,
            mode: QRContextMode.venueShared.backendValue,
            active: true,
            expiresAt: nil
        )

        let tableTokens = venue.tables.map {
            SupabaseUpsertQRTokenRequest(
                token: LocalQRTokenCodec.tableCode(slug: venue.slug, tableLabel: $0.label),
                venueID: venue.id,
                tableID: $0.id,
                mode: QRContextMode.table.backendValue,
                active: $0.isActive,
                expiresAt: nil
            )
        }

        return [sharedToken] + tableTokens
    }

    // MARK: - Remote Menu Sync

    /// Loads the active menu for a venue from Supabase and maps it to local MenuSectionData.
    /// Returns an empty array if the venue has no active menu in Supabase.
    func loadRemoteMenu(venueID: String) async throws -> [MenuSectionData] {
        guard let menuID = try await fetchActiveMenuID(venueID: venueID) else {
            return []
        }

        let categories = try await fetchRemoteMenuCategories(menuID: menuID)
        var sections: [MenuSectionData] = []

        for category in categories {
            let items = try await fetchRemoteMenuItems(categoryID: category.id)
            let sectionKind = MenuItemKind(rawValue: category.kind) ?? .food
            let mappedItems = items.map { item in
                MenuItemData(
                    id: item.id,
                    name: item.name,
                    description: item.description,
                    priceCents: item.priceCents,
                    kind: MenuItemKind(rawValue: item.kind) ?? sectionKind,
                    allergenCodes: item.allergenCodes.isEmpty ? nil : item.allergenCodes.joined(separator: ",")
                )
            }
            let legend: [String: String]? = category.allergenLegend.isEmpty ? nil : category.allergenLegend
            sections.append(MenuSectionData(
                id: category.id,
                title: category.name,
                subtitle: category.subtitle ?? "",
                kind: sectionKind,
                items: mappedItems,
                importConfidence: 1.0,
                allergenLegend: legend
            ))
        }

        connectionText = "Supabase-Menü geladen (\(sections.count) Kategorien)"
        isConnected = true
        return sections
    }

    /// Writes local MenuSectionData to Supabase (menus → menu_categories → menu_items).
    /// Creates or replaces the active menu for the venue; orphaned categories and items are deleted.
    /// Returns the number of items written.
    func syncMenuToSupabase(sections: [MenuSectionData], venueID: String) async throws -> Int {
        let menuID = try await upsertActiveMenu(venueID: venueID)

        let remoteCategories = try await fetchRemoteMenuCategories(menuID: menuID)
        let keepCategoryIDs = sections.map(\.id)
        let orphanedCategoryIDs = remoteCategories
            .map(\.id)
            .filter { !keepCategoryIDs.contains($0) }

        for (sortIndex, section) in sections.enumerated() {
            try await upsertRemoteMenuCategory(section, menuID: menuID, sortOrder: sortIndex)
            let remoteItems = try await fetchRemoteMenuItems(categoryID: section.id)
            let keepItemIDs = section.items.map(\.id)
            let orphanedItemIDs = remoteItems.map(\.id).filter { !keepItemIDs.contains($0) }

            for (itemIndex, item) in section.items.enumerated() {
                try await upsertRemoteMenuItem(item, categoryID: section.id, sortOrder: itemIndex)
            }

            if !orphanedItemIDs.isEmpty {
                try await deleteRemoteMenuItems(ids: orphanedItemIDs)
            }
        }

        if !orphanedCategoryIDs.isEmpty {
            try await deleteRemoteMenuCategories(ids: orphanedCategoryIDs)
        }

        let totalItems = sections.reduce(0) { $0 + $1.items.count }
        connectionText = "Supabase-Menü synchronisiert (\(totalItems) Artikel)"
        isConnected = true
        return totalItems
    }

    private func fetchActiveMenuID(venueID: String) async throws -> String? {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("menus"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "venue_id", value: "eq.\(venueID)"),
            URLQueryItem(name: "active", value: "eq.true"),
            URLQueryItem(name: "order", value: "created_at.asc"),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseMenuIDRow].self, from: data).first?.id
    }

    private func upsertActiveMenu(venueID: String) async throws -> String {
        if let existingID = try await fetchActiveMenuID(venueID: venueID) {
            return existingID
        }

        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("menus"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode([
            SupabaseUpsertMenuRequest(venueID: venueID, name: "Standard", active: true)
        ])

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        guard let inserted = try JSONDecoder().decode([SupabaseMenuIDRow].self, from: data).first else {
            throw URLError(.badServerResponse)
        }
        return inserted.id
    }

    private func fetchRemoteMenuCategories(menuID: String) async throws -> [SupabaseMenuCategoryRecord] {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("menu_categories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,menu_id,name,subtitle,kind,sort_order,allergen_legend"),
            URLQueryItem(name: "menu_id", value: "eq.\(menuID)"),
            URLQueryItem(name: "order", value: "sort_order.asc")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseMenuCategoryRecord].self, from: data)
    }

    private func upsertRemoteMenuCategory(_ section: MenuSectionData, menuID: String, sortOrder: Int) async throws {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("menu_categories"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode([
            SupabaseUpsertMenuCategoryRequest(
                id: section.id,
                menuID: menuID,
                name: section.title,
                subtitle: section.subtitle.isEmpty ? nil : section.subtitle,
                kind: section.kind.rawValue,
                sortOrder: sortOrder,
                allergenLegend: section.allergenLegend ?? [:]
            )
        ])

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func deleteRemoteMenuCategories(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("menu_categories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "in.(\(ids.joined(separator: ",")))")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        applySupabaseHeaders(to: &request)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func fetchRemoteMenuItems(categoryID: String) async throws -> [SupabaseMenuItemRecord] {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("menu_items"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,category_id,name,description,price_cents,kind,allergen_codes,sort_order"),
            URLQueryItem(name: "category_id", value: "eq.\(categoryID)"),
            URLQueryItem(name: "order", value: "sort_order.asc")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([SupabaseMenuItemRecord].self, from: data)
    }

    private func upsertRemoteMenuItem(_ item: MenuItemData, categoryID: String, sortOrder: Int) async throws {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("menu_items"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let allergenArray: [String]
        if let codes = item.allergenCodes, !codes.isEmpty {
            allergenArray = codes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            allergenArray = []
        }

        request.httpBody = try JSONEncoder().encode([
            SupabaseUpsertMenuItemRequest(
                id: item.id,
                categoryID: categoryID,
                name: item.name,
                description: item.description,
                priceCents: item.priceCents,
                kind: item.kind.rawValue,
                allergenCodes: allergenArray,
                sortOrder: sortOrder
            )
        ])

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func deleteRemoteMenuItems(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("menu_items"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "in.(\(ids.joined(separator: ",")))")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        applySupabaseHeaders(to: &request)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func deleteRemoteTables(venueID: String, keepingTableIDs: [String]) async throws {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("tables"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "venue_id", value: "eq.\(venueID)")
        ]

        if !keepingTableIDs.isEmpty {
            queryItems.append(
                URLQueryItem(
                    name: "id",
                    value: "not.in.(\(keepingTableIDs.joined(separator: ",")))"
                )
            )
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        applySupabaseHeaders(to: &request)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func selectClause(for schemaMode: RemoteOrderSchemaMode) -> String {
        switch schemaMode {
        case .enriched:
            return "id,created_at,source_device,total_cents,status,venue_id,table_id,service_mode,customer_note,venue:venues(id,name,slug),table:tables(id,label),order_items(id,name,quantity,unit_price_cents,kind)"
        case .legacy:
            return "id,created_at,source_device,total_cents,status,order_items(id,name,quantity,unit_price_cents,kind)"
        }
    }

    private func shouldFallbackToLegacySchema(after error: Error) -> Bool {
        guard let requestError = error as? SupabaseRequestError else {
            return false
        }

        guard requestError.statusCode == 400 || requestError.statusCode == 404 else {
            return false
        }

        let message = requestError.body.lowercased()
        let legacySchemaIndicators = [
            "venue_id",
            "table_id",
            "service_mode",
            "customer_note",
            "relation",
            "venues",
            "tables",
            "column",
            "schema cache"
        ]
        return legacySchemaIndicators.contains { message.contains($0) }
    }

    private func shouldTreatAsMissingQRTokenSchema(after error: Error) -> Bool {
        guard let requestError = error as? SupabaseRequestError else {
            return false
        }

        guard requestError.statusCode == 400 || requestError.statusCode == 404 else {
            return false
        }

        let message = requestError.body.lowercased()
        return message.contains("qr_tokens") && (
            message.contains("schema cache") ||
                message.contains("could not find the table") ||
                message.contains("relation")
        )
    }

    private func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw SupabaseRequestError(statusCode: http.statusCode, body: body)
        }
    }
}

private struct SupabaseCreateOrderRequest: Encodable {
    let sourceDevice: String
    let totalCents: Int
    let status: String
    let venueID: String?
    let tableID: String?
    let serviceMode: String?
    let customerNote: String?

    enum CodingKeys: String, CodingKey {
        case sourceDevice = "source_device"
        case totalCents = "total_cents"
        case status
        case venueID = "venue_id"
        case tableID = "table_id"
        case serviceMode = "service_mode"
        case customerNote = "customer_note"
    }
}

private struct SupabaseUpsertVenueRequest: Encodable {
    let id: String
    let name: String
    let slug: String
    let timezone: String
}

private struct SupabaseUpsertTableRequest: Encodable {
    let id: String
    let venueID: String
    let label: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case venueID = "venue_id"
        case label
        case active
    }
}

private struct SupabaseUpsertQRTokenRequest: Encodable {
    let token: String
    let venueID: String
    let tableID: String?
    let mode: String
    let active: Bool
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case token
        case venueID = "venue_id"
        case tableID = "table_id"
        case mode
        case active
        case expiresAt = "expires_at"
    }
}

private struct SupabaseVenueRecord: Decodable {
    let id: String
    let name: String
    let slug: String
}

private struct SupabaseTableRecord: Decodable {
    let id: String
    let venueID: String
    let label: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case venueID = "venue_id"
        case label
        case active
    }
}

private struct SupabaseQRTokenRecord: Decodable {
    let token: String
    let venueID: String
    let tableID: String?
    let modeRaw: String
    let active: Bool
    let expiresAtRaw: String?

    enum CodingKeys: String, CodingKey {
        case token
        case venueID = "venue_id"
        case tableID = "table_id"
        case modeRaw = "mode"
        case active
        case expiresAtRaw = "expires_at"
    }

    var isUsable: Bool {
        guard active else { return false }
        guard let expiresAtRaw else { return true }
        guard let expiresAt = parseSupabaseDate(expiresAtRaw) else { return true }
        return expiresAt > .now
    }
}

private struct SupabasePatchOrderStatusRequest: Encodable {
    let status: String
}

private struct SupabaseInsertedOrder: Decodable {
    let id: String
}

private struct SupabaseCreateOrderItemRequest: Encodable {
    let orderID: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kind: String

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kind
    }
}

private struct SupabaseOrderRow: Decodable {
    let id: String
    let createdAtRaw: String
    let sourceDevice: String
    let totalCents: Int
    let statusRaw: String
    let venueID: String?
    let tableID: String?
    let serviceModeRaw: String?
    let customerNote: String?
    let venue: SupabaseVenueRow?
    let table: SupabaseTableRow?
    let orderItems: [SupabaseOrderItemRow]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtRaw = "created_at"
        case sourceDevice = "source_device"
        case totalCents = "total_cents"
        case statusRaw = "status"
        case venueID = "venue_id"
        case tableID = "table_id"
        case serviceModeRaw = "service_mode"
        case customerNote = "customer_note"
        case venue
        case table
        case orderItems = "order_items"
    }

    var asLiveOrder: LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: Self.parseDate(createdAtRaw) ?? .now,
            sourceDevice: sourceDevice,
            venueID: venueID ?? venue?.id,
            venueName: venue?.name,
            serviceMode: serviceModeRaw.flatMap(ServiceMode.init(rawValue:)),
            tableID: tableID ?? table?.id,
            tableLabel: table?.label,
            customerNote: customerNote ?? "",
            items: orderItems.map(\.asLiveLine),
            totalCents: totalCents,
            status: OrderLifecycleStatus(rawValue: statusRaw) ?? .pending
        )
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFractional.date(from: raw) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

private struct SupabaseVenueRow: Decodable {
    let id: String
    let name: String?
    let slug: String?
}

private struct SupabaseTableRow: Decodable {
    let id: String
    let label: String?
}

private struct SupabaseRequestError: LocalizedError {
    let statusCode: Int
    let body: String

    var errorDescription: String? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            return "HTTP \(statusCode)"
        }
        return "HTTP \(statusCode): \(trimmedBody)"
    }
}

private enum SupabaseVenueSyncError: LocalizedError {
    case venueNotFound

    var errorDescription: String? {
        switch self {
        case .venueNotFound:
            return "Zu diesem Slug wurde in Supabase keine Venue gefunden."
        }
    }
}

enum SupabaseQRTokenSyncError: LocalizedError, Equatable {
    case schemaUnavailable

    var errorDescription: String? {
        switch self {
        case .schemaUnavailable:
            return "Die Tabelle qr_tokens ist im Supabase-Projekt noch nicht vorhanden."
        }
    }
}

private struct SupabaseOrderItemRow: Decodable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kindRaw: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kindRaw = "kind"
    }

    var asLiveLine: LiveOrderLine {
        LiveOrderLine(
            id: id,
            name: name,
            quantity: quantity,
            unitPriceCents: unitPriceCents,
            kind: MenuItemKind(rawValue: kindRaw) ?? .food
        )
    }
}

private struct SupabaseMenuIDRow: Decodable {
    let id: String
}

private struct SupabaseUpsertMenuRequest: Encodable {
    let venueID: String
    let name: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case venueID = "venue_id"
        case name
        case active
    }
}

private struct SupabaseMenuCategoryRecord: Decodable {
    let id: String
    let menuID: String
    let name: String
    let subtitle: String?
    let kind: String
    let sortOrder: Int
    let allergenLegend: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case menuID = "menu_id"
        case name
        case subtitle
        case kind
        case sortOrder = "sort_order"
        case allergenLegend = "allergen_legend"
    }
}

private struct SupabaseUpsertMenuCategoryRequest: Encodable {
    let id: String
    let menuID: String
    let name: String
    let subtitle: String?
    let kind: String
    let sortOrder: Int
    let allergenLegend: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case menuID = "menu_id"
        case name
        case subtitle
        case kind
        case sortOrder = "sort_order"
        case allergenLegend = "allergen_legend"
    }
}

private struct SupabaseMenuItemRecord: Decodable {
    let id: String
    let categoryID: String
    let name: String
    let description: String
    let priceCents: Int
    let kind: String
    let allergenCodes: [String]
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case name
        case description
        case priceCents = "price_cents"
        case kind
        case allergenCodes = "allergen_codes"
        case sortOrder = "sort_order"
    }
}

private struct SupabaseUpsertMenuItemRequest: Encodable {
    let id: String
    let categoryID: String
    let name: String
    let description: String
    let priceCents: Int
    let kind: String
    let allergenCodes: [String]
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case name
        case description
        case priceCents = "price_cents"
        case kind
        case allergenCodes = "allergen_codes"
        case sortOrder = "sort_order"
    }
}

private func parseSupabaseDate(_ raw: String) -> Date? {
    let formatterWithFractional = ISO8601DateFormatter()
    formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let date = formatterWithFractional.date(from: raw) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: raw)
}
