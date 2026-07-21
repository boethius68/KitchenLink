import UIKit

struct DemoMenuFixture: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let pageCount: Int
    let resourcePrefix: String
    let coverage: [DemoMenuCapability]
    let isSynthetic: Bool

    init(
        id: String,
        title: String,
        subtitle: String,
        pageCount: Int,
        resourcePrefix: String,
        coverage: [DemoMenuCapability] = [],
        isSynthetic: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.pageCount = pageCount
        self.resourcePrefix = resourcePrefix
        self.coverage = coverage
        self.isSynthetic = isSynthetic
    }
}

enum DemoMenuCapability: String, CaseIterable, Hashable {
    case allergens
    case additives
    case categories
    case descriptions
    case foodAndDrinks
    case variants
    case setMenu
    case bilingual
    case denseLayout

    var title: String {
        switch self {
        case .allergens: return "Allergene"
        case .additives: return "Zusatzstoffe"
        case .categories: return "Kategorien"
        case .descriptions: return "Beschreibungen"
        case .foodAndDrinks: return "Speisen & Getränke"
        case .variants: return "Varianten & Extras"
        case .setMenu: return "Gangmenü"
        case .bilingual: return "Zweisprachig"
        case .denseLayout: return "Dichtes Layout"
        }
    }
}

enum DemoMenuFixtures {
    static let kitchenLinkTestRestaurant = DemoMenuFixture(
        id: "kitchenlink-pruefkueche",
        title: "KitchenLink Prüfküche",
        subtitle: "Deterministische Vollabdeckung",
        pageCount: 3,
        resourcePrefix: "kitchenlink-pruefkueche",
        coverage: [
            .allergens,
            .additives,
            .categories,
            .descriptions,
            .foodAndDrinks,
            .variants,
            .setMenu,
        ],
        isSynthetic: true
    )

    static let scheuneBerlin = DemoMenuFixture(
        id: "scheune-berlin",
        title: "Scheune Berlin",
        subtitle: "Reale Karte · Codes und Extras",
        pageCount: 3,
        resourcePrefix: "scheune-berlin",
        coverage: [.allergens, .categories, .descriptions, .variants, .denseLayout]
    )

    static let lichtburgBerlin = DemoMenuFixture(
        id: "lichtburg-berlin",
        title: "Lichtburg Berlin",
        subtitle: "Reale Karte · Deutsch und Englisch",
        pageCount: 7,
        resourcePrefix: "lichtburg-berlin",
        coverage: [.categories, .descriptions, .variants, .setMenu, .bilingual, .denseLayout]
    )

    static let alexxandersChemnitz = DemoMenuFixture(
        id: "alexxanders-chemnitz",
        title: "Alexxanders Chemnitz",
        subtitle: "Reale dichte Saison- und Menükarte",
        pageCount: 4,
        resourcePrefix: "alexxanders-chemnitz",
        coverage: [.categories, .descriptions, .variants, .setMenu, .denseLayout]
    )

    /// Exactly three deliberately complementary cards shown in the app. The
    /// synthetic card guarantees all structured fields; two real cards retain
    /// difficult typography, columns and multilingual input.
    static let selectable: [DemoMenuFixture] = [
        kitchenLinkTestRestaurant,
        lichtburgBerlin,
        alexxandersChemnitz,
    ]

    /// Stable historical set used by the OCR gold baseline. Do not silently
    /// change this list; threshold and anchor files key off these IDs.
    static let all: [DemoMenuFixture] = [
        scheuneBerlin,
        lichtburgBerlin,
        alexxandersChemnitz,
    ]

    /// The human review also receives the deterministic full-coverage card.
    static let reviewFixtures: [DemoMenuFixture] = [kitchenLinkTestRestaurant] + all

    static func images(for fixture: DemoMenuFixture, bundle: Bundle = .main) -> [UIImage] {
        (1...fixture.pageCount).compactMap { page in
            let resourceName = fixture.resourcePrefix + "-" + String(page)
            let url = bundle.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "DemoMenus"
            ) ?? bundle.url(forResource: resourceName, withExtension: "png")

            guard let url else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
    }
}
