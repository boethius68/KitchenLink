import UIKit

struct DemoMenuFixture: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let pageCount: Int
    let resourcePrefix: String
}

enum DemoMenuFixtures {
    static let all: [DemoMenuFixture] = [
        DemoMenuFixture(
            id: "scheune-berlin",
            title: "Scheune Berlin",
            subtitle: "Klassische Restaurantkarte",
            pageCount: 3,
            resourcePrefix: "scheune-berlin"
        ),
        DemoMenuFixture(
            id: "lichtburg-berlin",
            title: "Lichtburg Berlin",
            subtitle: "Deutsch und Englisch",
            pageCount: 7,
            resourcePrefix: "lichtburg-berlin"
        ),
        DemoMenuFixture(
            id: "alexxanders-chemnitz",
            title: "Alexxanders Chemnitz",
            subtitle: "Dichte saisonale Karte",
            pageCount: 4,
            resourcePrefix: "alexxanders-chemnitz"
        )
    ]

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
