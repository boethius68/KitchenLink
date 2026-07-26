import Foundation

final class MenuEditorItemModel: ObservableObject {
    enum CloudState: Equatable {
        case idle
        case saving
        case deleting
        case success(String)
        case error(String)
    }

    enum ValidationError: LocalizedError, Equatable, Identifiable {
        case emptyName
        case zeroPrice

        var id: Self { self }

        var errorDescription: String? {
            switch self {
            case .emptyName: "Name darf nicht leer sein"
            case .zeroPrice: "Preis muss größer als 0 sein"
            }
        }
    }

    @Published private(set) var cloudState: CloudState = .idle
    @Published private(set) var validationErrors: [ValidationError] = []

    private let config: KitchenLinkCloudConfig
    private let transport: any KitchenLinkMenuEditTransport
    private let store: KitchenLinkCloudCredentialStore

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        transport: any KitchenLinkMenuEditTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore()
    ) {
        self.config = config
        self.transport = transport
        self.store = store
    }

    var hasSession: Bool {
        store.loadSession() != nil
    }

    func validate(_ item: MenuItemData) -> Bool {
        var errors: [ValidationError] = []
        if item.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyName)
        }
        if item.priceCents <= 0 {
            errors.append(.zeroPrice)
        }
        validationErrors = errors
        return errors.isEmpty
    }

    func saveToCloud(
        item: MenuItemData,
        categoryName: String,
        categoryKind: String
    ) async {
        guard validate(item) else { return }
        guard let session = store.loadSession() else {
            cloudState = .error("Nicht angemeldet. Bitte in der Service-Ansicht anmelden.")
            return
        }
        cloudState = .saving
        let payload = buildCloudItem(from: item)
        do {
            let itemID = try await transport.upsertMenuItem(
                config: config, session: session,
                venueSlug: config.venueSlug,
                categoryName: categoryName,
                categoryKind: categoryKind,
                item: payload
            )
            cloudState = .success("Gespeichert (ID: …\(itemID.suffix(8)))")
        } catch {
            cloudState = .error(error.localizedDescription)
        }
    }

    func deleteFromCloud(item: MenuItemData) async {
        guard let session = store.loadSession() else {
            cloudState = .error("Nicht angemeldet.")
            return
        }
        cloudState = .deleting
        let slug = KitchenLinkMenuPublishPayload.slugify(item.displayName)
        do {
            let deleted = try await transport.deleteMenuItem(
                config: config, session: session,
                venueSlug: config.venueSlug,
                itemSlug: slug
            )
            cloudState = .success(deleted ? "Gelöscht" : "Nicht gefunden")
        } catch {
            cloudState = .error(error.localizedDescription)
        }
    }

    func updateAvailability(
        item: MenuItemData
    ) async {
        guard let session = store.loadSession() else {
            cloudState = .error("Nicht angemeldet.")
            return
        }
        cloudState = .saving
        let slug = KitchenLinkMenuPublishPayload.slugify(item.displayName)
        do {
            let ok = try await transport.setItemAvailability(
                config: config, session: session,
                venueSlug: config.venueSlug,
                itemSlug: slug,
                available: item.available,
                availableFrom: item.availableFrom,
                availableUntil: item.availableUntil
            )
            cloudState = .success(ok ? "Verfügbarkeit gespeichert" : "Nicht gefunden")
        } catch {
            cloudState = .error(error.localizedDescription)
        }
    }

    func clearFeedback() {
        cloudState = .idle
        validationErrors = []
    }

    private func buildCloudItem(from item: MenuItemData) -> KitchenLinkPublishMenu.Item {
        let slug = KitchenLinkMenuPublishPayload.slugify(item.displayName)
        return KitchenLinkPublishMenu.Item(
            slug: slug,
            name: item.displayName,
            description: item.description,
            priceCents: item.priceCents,
            kind: item.kind.rawValue,
            allergenCodes: MenuEditorCodes.list(from: item.resolvedAllergenCodes),
            variantOptions: KitchenLinkMenuPublishPayload.variantOptions(from: item)
        )
    }
}
