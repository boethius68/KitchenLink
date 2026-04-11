import Combine
import Foundation

@MainActor
final class KitchenLinkStore: ObservableObject {
    @Published var menuSections: [MenuSectionData]
    @Published var isOperatorLoggedIn = false
    @Published var venueProfile: VenueProfile
    @Published var activeVenueContext: ResolvedVenueContext?
    @Published var trackedCustomerOrder: CustomerTrackedOrder?

    private let ownerEmail = "owner@kitchenlink.test"
    private let ownerPassword = "123456"
    private let repository: any KitchenLinkRepository

    var sharedDemoQRCode: String {
        LocalQRTokenCodec.sharedCode(slug: venueProfile.slug)
    }

    var demoQRCodeContexts: [ResolvedVenueContext] {
        let sortedTables = venueProfile.tables.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
        }

        return [makeSharedDemoContext()] + sortedTables.map { makeTableDemoContext(table: $0) }
    }

    init(repository: any KitchenLinkRepository = LocalDemoRepository()) {
        self.repository = repository

        let loadedVenue = repository.loadVenueProfile(fallback: Self.makeDemoVenue())
        let normalizedVenue = Self.makeSyncReadyVenueProfile(loadedVenue)
        venueProfile = normalizedVenue

        menuSections = repository.loadMenuSections(fallback: DemoMenuFactory.buildDefaultSections())

        if normalizedVenue != loadedVenue {
            persistVenueProfile()
        }
    }

    func loginOperator(email: String, password: String) -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = normalizedEmail == ownerEmail && normalizedPassword == ownerPassword
        isOperatorLoggedIn = success
        return success
    }

    func logoutOperator() {
        isOperatorLoggedIn = false
    }

    func setSharedVenueContext() {
        activeVenueContext = makeSharedDemoContext()
    }

    func ensureDemoVenueContext() {
        if activeVenueContext == nil {
            activeVenueContext = makeSharedDemoContext()
        }
    }

    func setActiveVenueContext(_ context: ResolvedVenueContext) {
        activeVenueContext = context
    }

    @discardableResult
    func resolveDemoQRCode(_ rawCode: String) -> ResolvedVenueContext? {
        let resolvedContext = repository.resolveQRCode(rawCode, venue: venueProfile)
        activeVenueContext = resolvedContext
        return resolvedContext
    }

    func updateVenue(
        name: String,
        slug: String,
        supportedServiceModes: [ServiceMode]
    ) -> Result<Void, VenueProfileValidationError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure(.missingName)
        }

        let normalizedSlug = Self.normalizeVenueSlug(slug)
        guard !normalizedSlug.isEmpty else {
            return .failure(.missingSlug)
        }

        let normalizedModes = ServiceMode.allCases.filter { supportedServiceModes.contains($0) }
        guard !normalizedModes.isEmpty else {
            return .failure(.missingServiceMode)
        }

        venueProfile.name = trimmedName
        venueProfile.slug = normalizedSlug
        venueProfile.supportedServiceModes = normalizedModes
        persistVenueProfile()
        refreshActiveVenueContext()
        return .success(())
    }

    func prepareVenueProfileForRemoteSync() -> VenueProfile {
        let normalizedVenue = Self.makeSyncReadyVenueProfile(venueProfile)
        if normalizedVenue != venueProfile {
            venueProfile = normalizedVenue
            persistVenueProfile()
            refreshActiveVenueContext()
        }
        return venueProfile
    }

    func replaceVenueProfile(_ profile: VenueProfile) {
        let normalizedVenue = Self.makeSyncReadyVenueProfile(profile)
        venueProfile = normalizedVenue
        persistVenueProfile()
        refreshActiveVenueContext()
    }

    func addTable(label: String) -> Result<VenueTable, VenueTableMutationError> {
        let normalizedLabel = Self.normalizeTableLabel(label)
        guard !normalizedLabel.isEmpty else {
            return .failure(.missingLabel)
        }

        guard !venueProfile.tables.contains(where: {
            $0.label.caseInsensitiveCompare(normalizedLabel) == .orderedSame
        }) else {
            return .failure(.duplicateLabel)
        }

        let newTable = VenueTable(
            id: UUID().uuidString.lowercased(),
            label: normalizedLabel,
            isActive: true
        )
        venueProfile.tables.append(newTable)
        persistVenueProfile()
        refreshActiveVenueContext()
        return .success(newTable)
    }

    func setTableActive(id: String, isActive: Bool) {
        guard let index = venueProfile.tables.firstIndex(where: { $0.id == id }) else { return }
        venueProfile.tables[index].isActive = isActive
        persistVenueProfile()
        refreshActiveVenueContext()
    }

    func removeTable(id: String) {
        venueProfile.tables.removeAll { $0.id == id }
        persistVenueProfile()
        refreshActiveVenueContext()
    }

    func resetVenueToDemo() {
        venueProfile = Self.makeDemoVenue()
        persistVenueProfile()
        refreshActiveVenueContext()
    }

    func tableDemoQRCode(for table: VenueTable) -> String {
        LocalQRTokenCodec.tableCode(slug: venueProfile.slug, tableLabel: table.label)
    }

    func clearTrackedCustomerOrder() {
        trackedCustomerOrder = nil
    }

    func recordTrackedOrder(
        id: String,
        serviceMode: ServiceMode,
        tableLabel: String?,
        totalCents: Int,
        itemCount: Int,
        customerNote: String,
        createdAt: Date,
        status: OrderLifecycleStatus
    ) {
        trackedCustomerOrder = CustomerTrackedOrder(
            id: id,
            venueName: venueProfile.name,
            serviceMode: serviceMode,
            tableLabel: tableLabel,
            totalCents: totalCents,
            itemCount: itemCount,
            createdAt: createdAt,
            customerNote: customerNote,
            status: status
        )
    }

    func updateTrackedOrderStatus(_ status: OrderLifecycleStatus) {
        guard var trackedCustomerOrder else { return }
        trackedCustomerOrder.status = status
        self.trackedCustomerOrder = trackedCustomerOrder
    }

    func addMenuItem(sectionID: String, name: String, description: String, priceCents: Int, kind: MenuItemKind) {
        guard let index = menuSections.firstIndex(where: { $0.id == sectionID }) else {
            return
        }

        let item = MenuItemData(
            id: "custom-\(UUID().uuidString)",
            name: name,
            description: description,
            priceCents: priceCents,
            kind: kind
        )
        menuSections[index].items.append(item)
        persistMenuSections()
    }

    func replaceMenu(with sections: [MenuSectionData]) {
        guard !sections.isEmpty else { return }
        menuSections = sections
        persistMenuSections()
    }

    func appendMenu(with sections: [MenuSectionData]) {
        guard !sections.isEmpty else { return }
        menuSections.append(contentsOf: sections)
        persistMenuSections()
    }

    func resetMenuToDemo() {
        menuSections = DemoMenuFactory.buildDefaultSections()
        persistMenuSections()
    }

    private func persistMenuSections() {
        do {
            try repository.saveMenuSections(menuSections)
        } catch {
            print("Menu save failed: \(error.localizedDescription)")
        }
    }

    private func persistVenueProfile() {
        do {
            try repository.saveVenueProfile(venueProfile)
        } catch {
            print("Venue save failed: \(error.localizedDescription)")
        }
    }

    private func refreshActiveVenueContext() {
        guard let currentToken = activeVenueContext?.token else { return }
        activeVenueContext = repository.resolveQRCode(currentToken, venue: venueProfile) ?? makeSharedDemoContext()
    }

    private func makeSharedDemoContext() -> ResolvedVenueContext {
        ResolvedVenueContext(
            token: sharedDemoQRCode,
            venue: venueProfile,
            mode: .venueShared,
            resolvedTable: nil
        )
    }

    private func makeTableDemoContext(table: VenueTable) -> ResolvedVenueContext {
        ResolvedVenueContext(
            token: tableDemoQRCode(for: table),
            venue: venueProfile,
            mode: .table,
            resolvedTable: table
        )
    }

    private static func makeDemoVenue() -> VenueProfile {
        VenueProfile(
            id: "164ca4d2-8a69-4f4f-aa2a-167253fbf4b6",
            name: "KitchenLink Demo Bistro",
            slug: "demo",
            supportedServiceModes: [.dineIn, .bar, .pickup],
            tables: [
                VenueTable(id: "7e2f57de-b0a4-4d34-95b6-4d12bc2c9406", label: "A1", isActive: true),
                VenueTable(id: "d7f5ceba-71f2-4f79-b4e6-5f5c8de1c4d0", label: "A2", isActive: true),
                VenueTable(id: "0c705b93-b78f-433b-8070-dae23612d108", label: "B1", isActive: true),
                VenueTable(id: "d0b242f9-a014-4755-98e8-9446abf0eb02", label: "B2", isActive: true),
                VenueTable(id: "c1c8e617-6ddb-4947-90ee-03f0c62de284", label: "C1", isActive: false)
            ]
        )
    }

    private static func makeSyncReadyVenueProfile(_ profile: VenueProfile) -> VenueProfile {
        var normalizedProfile = profile
        normalizedProfile.id = normalizedUUID(from: profile.id)
        normalizedProfile.slug = normalizeVenueSlug(profile.slug)
        normalizedProfile.tables = profile.tables.map { table in
            VenueTable(
                id: normalizedUUID(from: table.id),
                label: normalizeTableLabel(table.label),
                isActive: table.isActive
            )
        }
        return normalizedProfile
    }

    private static func normalizedUUID(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let uuid = UUID(uuidString: trimmed) {
            return uuid.uuidString.lowercased()
        }
        return UUID().uuidString.lowercased()
    }

    private static func normalizeVenueSlug(_ rawValue: String) -> String {
        let lowercased = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let replacedWhitespace = lowercased.replacingOccurrences(
            of: #"\s+"#,
            with: "-",
            options: .regularExpression
        )
        let filteredScalars = replacedWhitespace.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }
        let filtered = String(String.UnicodeScalarView(filteredScalars))
        let collapsed = filtered.replacingOccurrences(
            of: #"-{2,}"#,
            with: "-",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func normalizeTableLabel(_ rawValue: String) -> String {
        let uppercased = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let filteredScalars = uppercased.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }
        return String(String.UnicodeScalarView(filteredScalars))
    }
}
