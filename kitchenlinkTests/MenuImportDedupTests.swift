import Foundation
import Testing
@testable import kitchenlink

/// KL-SCAN-002: Deduplizierung gespiegelter Sektionen zweisprachiger Karten.
///
/// Viele deutsche Karten drucken erst den kompletten deutschen Teil und danach
/// denselben Teil auf Englisch. Weil die Sektionstitel abweichen, überleben die
/// Gerichte doppelt. `dropMirroredSections` entfernt die Spiegel über zwei
/// konservative Signale (exakte Namensgleichheit; identische Preis-Multimenge ab
/// 5 Gerichten), ohne je ein echtes Gericht zu verlieren.

private func item(_ name: String, _ priceCents: Int, kind: MenuItemKind = .food) -> MenuItemData {
    MenuItemData(
        id: "item-\(name)-\(priceCents)-\(UUID().uuidString)",
        name: name,
        description: "",
        priceCents: priceCents,
        kind: kind
    )
}

private func section(_ title: String, kind: MenuItemKind = .food, _ items: [MenuItemData]) -> MenuSectionData {
    MenuSectionData(
        id: "section-\(title)-\(UUID().uuidString)",
        title: title,
        subtitle: "",
        kind: kind,
        items: items
    )
}

@Test func dropsNameMirroredSectionWithIdenticalDishNames() {
    // Italienische Gerichtsnamen sind in beiden Sprachteilen identisch.
    let sections = [
        section("Antipasti - Vorspeisen", [item("Bruschetta", 500), item("Carpaccio", 1400)]),
        section("Pizze", [item("Margherita", 1000)]),
        section("Antipasti - Starters", [item("Bruschetta", 500), item("Carpaccio", 1400)]),
    ]
    let result = MenuImportService.dropMirroredSections(sections)
    #expect(result.map(\.title) == ["Antipasti - Vorspeisen", "Pizze"])
    #expect(result.flatMap { $0.items }.count == 3)
}

@Test func dropsPriceMirroredSectionWithTranslatedNames() {
    // Übersetzte Namen, gleiche Preise, >= 5 Gerichte -> Preis-Spiegel greift.
    let german = section("Säfte und Wasser", kind: .drink, [
        item("Orangensaft", 260, kind: .drink),
        item("Apfelsaft", 260, kind: .drink),
        item("Traubensaft", 280, kind: .drink),
        item("Apfelschorle", 260, kind: .drink),
        item("Mineralwasser", 250, kind: .drink),
    ])
    let english = section("Juices and water", kind: .drink, [
        item("Orange juice", 260, kind: .drink),
        item("Apple juice", 260, kind: .drink),
        item("Grape juice", 280, kind: .drink),
        item("Apple juice spritzer", 260, kind: .drink),
        item("Mineral water", 250, kind: .drink),
    ])
    let result = MenuImportService.dropMirroredSections([german, english])
    #expect(result.map(\.title) == ["Säfte und Wasser"])
}

@Test func keepsSmallSectionWithCoincidentallyEqualPrices() {
    // Rot- und Weißweine zu je gleichen zwei Preisen sind KEINE Spiegel: unter
    // der 5-Gerichte-Schwelle greift nur der (hier fehlende) Namens-Spiegel.
    let red = section("Rotweine", kind: .drink, [
        item("Chianti", 590, kind: .drink),
        item("Primitivo", 690, kind: .drink),
    ])
    let white = section("Weißweine", kind: .drink, [
        item("Pinot Grigio", 590, kind: .drink),
        item("Soave", 690, kind: .drink),
    ])
    let result = MenuImportService.dropMirroredSections([red, white])
    #expect(result.map(\.title) == ["Rotweine", "Weißweine"])
}

@Test func keepsPartialMirrorSectionWithUniqueDish() {
    // Enthält eine Sektion auch nur EIN neues Gericht (und < 5 Artikel), bleibt
    // sie vollständig erhalten — kein echtes Gericht darf verloren gehen.
    let first = section("Dolci", [item("Tiramisu", 590), item("Panna Cotta", 550)])
    let second = section("Nachtisch", [item("Tiramisu", 590), item("Zabaione", 620)])
    let result = MenuImportService.dropMirroredSections([first, second])
    #expect(result.map(\.title) == ["Dolci", "Nachtisch"])
    #expect(result.flatMap { $0.items }.map(\.name).contains("Zabaione"))
}

@Test func eachEarlierSectionAbsorbsOnlyOnePriceMirror() {
    // Zwei identische spätere Sektionen dürfen nicht beide auf EINE frühere
    // fallen: die zweite bleibt (kein Über-Löschen bei 1:1-Zuordnung).
    let prices = [700, 800, 900, 1000, 1100]
    let a = section("Pasta - Nudeln", prices.enumerated().map { item("Nudel \($0.offset)", $0.element) })
    let b = section("Pasta - Noodles", prices.enumerated().map { item("Noodle \($0.offset)", $0.element) })
    let c = section("Pasta - Pâtes", prices.enumerated().map { item("Pâtes \($0.offset)", $0.element) })
    let result = MenuImportService.dropMirroredSections([a, b, c])
    // a absorbiert b; c findet keine freie frühere Signatur -> bleibt.
    #expect(result.map(\.title) == ["Pasta - Nudeln", "Pasta - Pâtes"])
}
