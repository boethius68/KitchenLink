import Foundation

/// KL-MENU-005: Scan-zu-Publish-Brücke.
///
/// Veröffentlicht ein geprüftes, importiertes Menü (`[MenuSectionData]` aus dem
/// Draft-Review) in die Supabase-Venue, sodass die gescannte Karte auf dem
/// Gast-Web erscheint. Das ist die zweite Hälfte des Kern-Pitches: eine
/// Papierkarte scannen, prüfen und Minuten später bestellen Gäste per QR.
///
/// Der Schreibweg läuft ausschließlich über die SECURITY-DEFINER-RPC
/// `operator_publish_menu_v2` (Migration `20260722120000`), die genau wie die
/// Bestell- und Status-RPCs staff-gated ist. Authentifizierung und
/// Sitzungspersistenz teilen sich die Typen mit `KitchenLinkCloudOrderClient`
/// (`KitchenLinkCloudConfig`, `KitchenLinkCloudSession`,
/// `KitchenLinkCloudCredentialStore`, `KitchenLinkCloudServiceError`), damit ein
/// einmal unter „Service" angemeldeter Betreiber ohne erneutes Eintippen
/// veröffentlichen kann.

// MARK: - Nutzlast

/// Providerneutrale Veröffentlichungs-Nutzlast. Die Schlüssel sind bewusst
/// snake_case, damit sie 1:1 als `p_menu`-JSON an die RPC gehen.
struct KitchenLinkPublishMenu: Codable, Equatable {
    var categories: [Category]

    struct Category: Codable, Equatable {
        var name: String
        var kind: String
        /// Allergen-/Zusatzstoff-Legende (Code→Klartext) dieser Kategorie. Landet
        /// in `menu_categories.allergen_legend`, damit das Gast-Web die Codes zu
        /// einheitlichen Icons/Klartext auflösen kann.
        var allergenLegend: [String: String]
        var items: [Item]

        enum CodingKeys: String, CodingKey {
            case name
            case kind
            case allergenLegend = "allergen_legend"
            case items
        }
    }

    struct Item: Codable, Equatable {
        var slug: String
        var name: String
        var description: String
        var priceCents: Int
        var kind: String
        var allergenCodes: [String]
        /// Varianten/Portionen/Extras des Artikels. Landet in
        /// `menu_items.variant_options`.
        var variantOptions: [VariantOption]

        enum CodingKeys: String, CodingKey {
            case slug
            case name
            case description
            case priceCents = "price_cents"
            case kind
            case allergenCodes = "allergen_codes"
            case variantOptions = "variant_options"
        }
    }

    /// Eine Auswahloption eines Artikels (Portion, Extra oder Variante).
    struct VariantOption: Codable, Equatable {
        var id: String
        var name: String
        var priceCents: Int
        var kind: String
        var priceKind: String
        var groupID: String?
        var groupTitle: String?
        var minimumSelections: Int?
        var maximumSelections: Int?
        var selectionMode: String?
        var freeSelectionCount: Int?
        var allowsRepeats: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case priceCents = "price_cents"
            case kind
            case priceKind = "price_kind"
            case groupID = "group_id"
            case groupTitle = "group_title"
            case minimumSelections = "minimum_selections"
            case maximumSelections = "maximum_selections"
            case selectionMode = "selection_mode"
            case freeSelectionCount = "free_selection_count"
            case allowsRepeats = "allows_repeats"
        }
    }

    var itemCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}

/// Antwortzeile der RPC: welche Karte geschrieben wurde und wie viele
/// Kategorien/Artikel tatsächlich landeten.
struct KitchenLinkMenuPublishReceipt: Codable, Equatable {
    let menuID: String
    let categoryCount: Int
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case menuID = "menu_id"
        case categoryCount = "category_count"
        case itemCount = "item_count"
    }
}

// MARK: - Nutzlast-Bau (rein, testbar)

/// Baut aus dem geprüften Sandbox-Menü die Veröffentlichungs-Nutzlast. Rein und
/// ohne Netzwerk, damit die einzige knifflige Logik — stabile, eindeutige Slugs
/// — vollständig unit-getestet werden kann.
enum KitchenLinkMenuPublishPayload {
    static func build(from sections: [MenuSectionData]) -> KitchenLinkPublishMenu {
        var slugRegistry = SlugRegistry()

        let categories: [KitchenLinkPublishMenu.Category] = sections.compactMap { section in
            let items: [KitchenLinkPublishMenu.Item] = section.items.map { item in
                let displayName = item.displayName
                let slug = slugRegistry.unique(for: slugify(displayName))
                return KitchenLinkPublishMenu.Item(
                    slug: slug,
                    name: displayName,
                    description: item.description,
                    priceCents: item.priceCents,
                    kind: item.kind.rawValue,
                    allergenCodes: allergenCodes(from: item),
                    variantOptions: variantOptions(from: item)
                )
            }
            guard !items.isEmpty else { return nil }
            return KitchenLinkPublishMenu.Category(
                name: section.title,
                kind: section.kind.rawValue,
                allergenLegend: normalizedLegend(section.allergenLegend),
                items: items
            )
        }

        return KitchenLinkPublishMenu(categories: categories)
    }

    /// Bereinigt die Legende: klein geschriebene, getrimmte Codes auf
    /// nicht-leere Klartexte. So bleibt `allergen_legend` konsistent mit den
    /// (klein geschriebenen) Codes in `allergen_codes`.
    static func normalizedLegend(_ legend: [String: String]?) -> [String: String] {
        guard let legend else { return [:] }
        var result: [String: String] = [:]
        for (rawCode, rawTitle) in legend {
            let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty, !title.isEmpty else { continue }
            result[code] = title
        }
        return result
    }

    /// Übersetzt die Varianten/Portionen/Extras eines Artikels in die
    /// Veröffentlichungs-Form. Leere Namen oder negative Preise werden
    /// ausgelassen.
    static func variantOptions(from item: MenuItemData) -> [KitchenLinkPublishMenu.VariantOption] {
        item.variants.compactMap { variant in
            let name = variant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, variant.priceCents >= 0 else { return nil }
            return KitchenLinkPublishMenu.VariantOption(
                id: variant.id,
                name: name,
                priceCents: variant.priceCents,
                kind: variant.kind.rawValue,
                priceKind: variant.priceKind.rawValue,
                groupID: variant.groupID,
                groupTitle: variant.groupTitle,
                minimumSelections: variant.minimumSelections,
                maximumSelections: variant.maximumSelections,
                selectionMode: variant.selectionMode,
                freeSelectionCount: variant.freeSelectionCount,
                allowsRepeats: variant.allowsRepeats
            )
        }
    }

    /// Erzeugt einen URL-tauglichen Slug aus einem Artikelnamen. Deutsche
    /// Umlaute werden ausgeschrieben (ä→ae), übrige Diakritika entfernt, alles
    /// Nicht-Alphanumerische zu Bindestrichen verdichtet. Leeres Ergebnis fällt
    /// auf „artikel" zurück (wird bei Bedarf durchnummeriert).
    static func slugify(_ input: String) -> String {
        var value = input
        let umlauts: [(String, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"),
            ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"), ("ß", "ss")
        ]
        for (from, to) in umlauts {
            value = value.replacingOccurrences(of: from, with: to)
        }
        value = value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        value = value.lowercased()

        var out = ""
        var pendingDash = false
        for character in value {
            if character.isASCII && (character.isLetter || character.isNumber) {
                if pendingDash && !out.isEmpty {
                    out.append("-")
                }
                out.append(character)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "artikel" : out
    }

    /// Zerlegt den kombinierten Allergen-Code-String (z. B. "a,c" oder "a c")
    /// in einzelne Codes.
    static func allergenCodes(from item: MenuItemData) -> [String] {
        guard let raw = item.resolvedAllergenCodes, !raw.isEmpty else { return [] }
        let separators = CharacterSet(charactersIn: ",;/| ").union(.whitespacesAndNewlines)
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Hält vergebene Slugs fest und hängt bei Kollision `-2`, `-3`, … an.
    private struct SlugRegistry {
        private var used: Set<String> = []

        mutating func unique(for base: String) -> String {
            if !used.contains(base) {
                used.insert(base)
                return base
            }
            var suffix = 2
            var candidate = "\(base)-\(suffix)"
            while used.contains(candidate) {
                suffix += 1
                candidate = "\(base)-\(suffix)"
            }
            used.insert(candidate)
            return candidate
        }
    }
}

// MARK: - Transport

/// Schmales Transport-Protokoll nur für die Veröffentlichung. Getrennt vom
/// `KitchenLinkCloudTransport` (Bestellungen), damit dessen Test-Spy
/// unangetastet bleibt; die konkrete `URLSessionKitchenLinkCloudTransport`
/// erfüllt beide.
protocol KitchenLinkMenuPublishTransport: Sendable {
    func publishMenu(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        menu: KitchenLinkPublishMenu
    ) async throws -> KitchenLinkMenuPublishReceipt
}

// MARK: - Model

/// Steuert die Veröffentlichung einer vorbereiteten Nutzlast. Nutzt eine bereits
/// gespeicherte Betreiber-Sitzung, wenn vorhanden; andernfalls meldet die
/// Ansicht mit E-Mail/Passwort an (dieselben vertrauten Zugangsdaten wie unter
/// „Service" — keine technischen Formulare, Usability-Leitplanke).
@MainActor
final class KitchenLinkMenuPublishModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case publishing
        case published(KitchenLinkMenuPublishReceipt)
        case failed(String)
    }

    /// Öffentliche Sandbox-Gast-Web-Basis (Hostinger). Getrennt von der
    /// Supabase-URL: die veröffentlichte Karte wird hier für Gäste sichtbar.
    static let guestWebHost = "kitchenlink.luneq.eu"

    @Published private(set) var phase: Phase = .idle

    let payload: KitchenLinkPublishMenu
    let categoryCount: Int
    let itemCount: Int

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let publisher: KitchenLinkMenuPublishTransport
    private let store: KitchenLinkCloudCredentialStore

    init(
        payload: KitchenLinkPublishMenu,
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        publisher: KitchenLinkMenuPublishTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore()
    ) {
        self.payload = payload
        self.categoryCount = payload.categories.count
        self.itemCount = payload.itemCount
        self.config = config
        self.auth = auth
        self.publisher = publisher
        self.store = store
    }

    convenience init(
        sections: [MenuSectionData],
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        publisher: KitchenLinkMenuPublishTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore()
    ) {
        self.init(
            payload: KitchenLinkMenuPublishPayload.build(from: sections),
            config: config,
            auth: auth,
            publisher: publisher,
            store: store
        )
    }

    /// Ob bereits eine Betreiber-Sitzung vorliegt (dann genügt ein Tap).
    var hasSession: Bool {
        store.loadSession() != nil
    }

    /// Anzeige-URL der veröffentlichten Karte für Gäste.
    var guestMenuURLText: String {
        "\(Self.guestWebHost)/\(config.venueSlug)/menu"
    }

    /// Nichts zu veröffentlichen (defensiv: der Review-Weg liefert nie leer).
    var isEmpty: Bool {
        payload.categories.isEmpty
    }

    /// Veröffentlicht mit der gespeicherten Sitzung. Bei abgelaufener Sitzung
    /// wird genau einmal per Refresh-Token erneuert.
    func publishUsingStoredSession() async {
        guard let session = store.loadSession() else {
            phase = .failed("Bitte zuerst anmelden.")
            return
        }
        await publish(with: session, allowRefresh: true)
    }

    /// Meldet mit vertrauten Zugangsdaten an und veröffentlicht anschließend.
    func signInAndPublish(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            phase = .failed("E-Mail und Passwort sind erforderlich.")
            return
        }
        guard !isEmpty else {
            phase = .failed("Es gibt keine geprüften Artikel zum Veröffentlichen.")
            return
        }

        phase = .publishing
        do {
            let session = try await auth.signIn(
                config: config,
                email: trimmedEmail,
                password: password
            )
            store.save(session: session)
            // Frische Sitzung: kein zusätzlicher Refresh-Pfad nötig.
            await publish(with: session, allowRefresh: false)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private func publish(with session: KitchenLinkCloudSession, allowRefresh: Bool) async {
        guard !isEmpty else {
            phase = .failed("Es gibt keine geprüften Artikel zum Veröffentlichen.")
            return
        }

        phase = .publishing
        do {
            let receipt = try await publisher.publishMenu(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                menu: payload
            )
            phase = .published(receipt)
        } catch KitchenLinkCloudServiceError.unauthorized where allowRefresh {
            await refreshAndPublish(refreshToken: session.refreshToken)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private func refreshAndPublish(refreshToken: String) async {
        do {
            let refreshed = try await auth.refresh(config: config, refreshToken: refreshToken)
            store.save(session: refreshed)
            let receipt = try await publisher.publishMenu(
                config: config,
                session: refreshed,
                venueSlug: config.venueSlug,
                menu: payload
            )
            phase = .published(receipt)
        } catch {
            // Totes Refresh-Token: Sitzung verwerfen, erneute Anmeldung anbieten.
            store.clearSession()
            phase = .failed("Die Anmeldung ist abgelaufen. Bitte erneut anmelden.")
        }
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
