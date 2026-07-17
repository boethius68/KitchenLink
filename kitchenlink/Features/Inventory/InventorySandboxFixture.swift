import Foundation

/// Deterministische Sandbox-Fixture fuer die Warenwirtschaft. Liefert
/// 12 Zutaten, 4 Rezepte, 2 Lagerorte, 2 Lieferanten sowie beispielhafte
/// Wareneingaenge, Verbraeuche, Verderb und einen ausgewogenen Transfer.
enum InventorySandboxFixture {
    static let supplierKochBerg = "supplier-kochberg"
    static let supplierWeinGut = "supplier-weingut-hoelle"

    static let ingredientFlour = "ingredient-mehl"
    static let ingredientMozzarella = "ingredient-mozzarella"
    static let ingredientTomato = "ingredient-tomaten"
    static let ingredientBasil = "ingredient-basilikum"
    static let ingredientOliveOil = "ingredient-olivenoel"
    static let ingredientEggs = "ingredient-eier"
    static let ingredientSugar = "ingredient-zucker"
    static let ingredientMascarpone = "ingredient-mascarpone"
    static let ingredientEspresso = "ingredient-espresso"
    static let ingredientRedWine = "ingredient-rotwein"
    static let ingredientWhiteWine = "ingredient-weisswein"
    static let ingredientGarlic = "ingredient-knoblauch"

    static let locationKitchen = "location-kueche"
    static let locationBar = "location-bar"

    static let recipePizzaMargherita = "recipe-pizza-margherita"
    static let recipeSpaghettiBolognese = "recipe-spaghetti-bolognese"
    static let recipeTiramisu = "recipe-tiramisu"
    static let recipeGarlicBread = "recipe-knoblauchbrot"

    static let salesItemPizza = "sales-pizza-margherita"
    static let salesItemSpaghetti = "sales-spaghetti-bolognese"
    static let salesItemTiramisu = "sales-tiramisu"
    static let salesItemGarlicBread = "sales-knoblauchbrot"
    static let salesItemRedWine = "sales-rotwein"

    /// Erstellt den Katalog. Mengenangaben sind klein genug, um Ueberlauf in
    /// Tests zu vermeiden, aber gross genug, um Reservierung, Verderb und
    /// Transfer real abzubilden.
    static func makeCatalog() throws -> InventoryCatalog {
        try InventoryCatalog(
            ingredients: [
                try Ingredient(
                    id: ingredientFlour, name: "Mehl Type 00",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 2, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 6, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientMozzarella, name: "Mozzarella",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 1, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 3, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientTomato, name: "San-Marzano-Tomaten",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 1.5, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 4, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientBasil, name: "Basilikum",
                    baseUnit: .mass(.gram),
                    minimumStock: try quantity(value: 50, unit: .mass(.gram)),
                    targetStock: try quantity(value: 200, unit: .mass(.gram))
                ),
                try Ingredient(
                    id: ingredientOliveOil, name: "Olivenoel",
                    baseUnit: .volume(.liter),
                    minimumStock: try quantity(value: 1, unit: .volume(.liter)),
                    targetStock: try quantity(value: 3, unit: .volume(.liter))
                ),
                try Ingredient(
                    id: ingredientEggs, name: "Eier",
                    baseUnit: .count,
                    minimumStock: try quantity(value: 12, unit: .count),
                    targetStock: try quantity(value: 60, unit: .count)
                ),
                try Ingredient(
                    id: ingredientSugar, name: "Zucker",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 0.5, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 2, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientMascarpone, name: "Mascarpone",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 0.5, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 1.5, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientEspresso, name: "Espresso-Bohnen",
                    baseUnit: .mass(.kilogram),
                    minimumStock: try quantity(value: 0.5, unit: .mass(.kilogram)),
                    targetStock: try quantity(value: 2, unit: .mass(.kilogram))
                ),
                try Ingredient(
                    id: ingredientRedWine, name: "Rotwein (Chianti)",
                    baseUnit: .volume(.liter),
                    minimumStock: try quantity(value: 3, unit: .volume(.liter)),
                    targetStock: try quantity(value: 9, unit: .volume(.liter))
                ),
                try Ingredient(
                    id: ingredientWhiteWine, name: "Weisswein (Vermentino)",
                    baseUnit: .volume(.liter),
                    minimumStock: try quantity(value: 3, unit: .volume(.liter)),
                    targetStock: try quantity(value: 9, unit: .volume(.liter))
                ),
                try Ingredient(
                    id: ingredientGarlic, name: "Knoblauch",
                    baseUnit: .count,
                    minimumStock: try quantity(value: 10, unit: .count),
                    targetStock: try quantity(value: 30, unit: .count)
                )
            ],
            salesItems: [
                SalesItem(id: salesItemPizza, name: "Pizza Margherita", recipeID: recipePizzaMargherita),
                SalesItem(id: salesItemSpaghetti, name: "Spaghetti Bolognese", recipeID: recipeSpaghettiBolognese),
                SalesItem(id: salesItemTiramisu, name: "Tiramisu", recipeID: recipeTiramisu),
                SalesItem(id: salesItemGarlicBread, name: "Knoblauchbrot", recipeID: recipeGarlicBread),
                SalesItem(id: salesItemRedWine, name: "Glas Chianti", recipeID: nil)
            ],
            recipes: [
                Recipe(
                    id: recipePizzaMargherita, name: "Pizza Margherita",
                    components: [
                        try RecipeComponent(ingredientID: ingredientFlour, quantity: try quantity(value: 0.250, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientMozzarella, quantity: try quantity(value: 0.150, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientTomato, quantity: try quantity(value: 0.120, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientBasil, quantity: try quantity(value: 5, unit: .mass(.gram))),
                        try RecipeComponent(ingredientID: ingredientOliveOil, quantity: try quantity(value: 0.015, unit: .volume(.liter)))
                    ]
                ),
                Recipe(
                    id: recipeSpaghettiBolognese, name: "Spaghetti Bolognese",
                    components: [
                        try RecipeComponent(ingredientID: ingredientFlour, quantity: try quantity(value: 0.180, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientTomato, quantity: try quantity(value: 0.200, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientGarlic, quantity: try quantity(value: 1, unit: .count)),
                        try RecipeComponent(ingredientID: ingredientOliveOil, quantity: try quantity(value: 0.020, unit: .volume(.liter)))
                    ]
                ),
                Recipe(
                    id: recipeTiramisu, name: "Tiramisu",
                    components: [
                        try RecipeComponent(ingredientID: ingredientMascarpone, quantity: try quantity(value: 0.080, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientEggs, quantity: try quantity(value: 1, unit: .count)),
                        try RecipeComponent(ingredientID: ingredientSugar, quantity: try quantity(value: 0.020, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientEspresso, quantity: try quantity(value: 0.010, unit: .mass(.kilogram)))
                    ]
                ),
                Recipe(
                    id: recipeGarlicBread, name: "Knoblauchbrot",
                    components: [
                        try RecipeComponent(ingredientID: ingredientFlour, quantity: try quantity(value: 0.120, unit: .mass(.kilogram))),
                        try RecipeComponent(ingredientID: ingredientGarlic, quantity: try quantity(value: 2, unit: .count)),
                        try RecipeComponent(ingredientID: ingredientOliveOil, quantity: try quantity(value: 0.010, unit: .volume(.liter)))
                    ]
                )
            ],
            locations: [
                StockLocation(id: locationKitchen, name: "Kueche", kind: .kitchen),
                StockLocation(id: locationBar, name: "Bar", kind: .bar)
            ],
            suppliers: [
                Supplier(id: supplierKochBerg, name: "Kochberg Foodservice", contact: "+49 30 123456"),
                Supplier(id: supplierWeinGut, name: "Weingut Hoelle", contact: "+49 621 987654")
            ],
            purchasePrices: [
                try PurchasePrice(
                    supplierID: supplierKochBerg, ingredientID: ingredientFlour,
                    pricePerBaseUnit: Decimal(string: "2.40")!, validFrom: .now
                ),
                try PurchasePrice(
                    supplierID: supplierKochBerg, ingredientID: ingredientMozzarella,
                    pricePerBaseUnit: Decimal(string: "9.80")!, validFrom: .now
                ),
                try PurchasePrice(
                    supplierID: supplierKochBerg, ingredientID: ingredientRedWine,
                    pricePerBaseUnit: Decimal(string: "8.50")!, validFrom: .now
                ),
                try PurchasePrice(
                    supplierID: supplierWeinGut, ingredientID: ingredientWhiteWine,
                    pricePerBaseUnit: Decimal(string: "11.20")!, validFrom: .now
                )
            ]
        )
    }

    /// Erstellt den Katalog, einen Ledger und die initiale Bewegungschronik
    /// (Wareneingaenge, ein paar Verbraeuche, ein Verderb und ein Transfer).
    /// Die Bewegungen sind so gewaehlt, dass der Kuechen- und Barbestand
    /// sichtbar getrennt projiziert werden koennen.
    static func makePopulatedLedger(
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> (InventoryCatalog, InventoryLedger) {
        let catalog = try makeCatalog()
        let ledger = InventoryLedger(catalog: catalog)

        // Wareneingaenge Kueche
        try ledger.record(.receipt(
            ingredientID: ingredientFlour, locationID: locationKitchen,
            quantity: try quantity(value: 5, unit: .mass(.kilogram)),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientMozzarella, locationID: locationKitchen,
            quantity: try quantity(value: 2, unit: .mass(.kilogram)),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientTomato, locationID: locationKitchen,
            quantity: try quantity(value: 3, unit: .mass(.kilogram)),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientBasil, locationID: locationKitchen,
            quantity: try quantity(value: 150, unit: .mass(.gram)),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientOliveOil, locationID: locationKitchen,
            quantity: try quantity(value: 2, unit: .volume(.liter)),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientGarlic, locationID: locationKitchen,
            quantity: try quantity(value: 24, unit: .count),
            reference: "po-2024-001", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientEggs, locationID: locationKitchen,
            quantity: try quantity(value: 36, unit: .count),
            reference: "po-2024-001", timestamp: timestamp
        ))

        // Wareneingaenge Bar
        try ledger.record(.receipt(
            ingredientID: ingredientRedWine, locationID: locationBar,
            quantity: try quantity(value: 6, unit: .volume(.liter)),
            reference: "po-2024-002", timestamp: timestamp
        ))
        try ledger.record(.receipt(
            ingredientID: ingredientWhiteWine, locationID: locationBar,
            quantity: try quantity(value: 6, unit: .volume(.liter)),
            reference: "po-2024-002", timestamp: timestamp
        ))

        // Verbrauch: 3 Pizzen
        let resolver = InventoryRecipeResolver(catalog: catalog)
        let order = InventoryOrderLine(
            id: "line-pizza-1",
            salesItemID: salesItemPizza,
            quantity: 3,
            reference: "order-fixture-1"
        )
        let resolved = try resolver.resolve(
            lines: [order], at: locationKitchen, timestamp: timestamp
        )
        for movement in resolved.consumptions {
            _ = try ledger.record(movement)
        }

        // Verbrauch: 2 Spaghetti
        let spaghetti = InventoryOrderLine(
            id: "line-spaghetti-1",
            salesItemID: salesItemSpaghetti,
            quantity: 2,
            reference: "order-fixture-1"
        )
        for movement in try resolver.resolve(
            lines: [spaghetti], at: locationKitchen, timestamp: timestamp
        ).consumptions {
            _ = try ledger.record(movement)
        }

        // Verderb: 200 g Basilikum
        try ledger.record(.waste(
            ingredientID: ingredientBasil, locationID: locationKitchen,
            quantity: try quantity(value: 200, unit: .mass(.gram)),
            reference: nil, note: "Verdorben", timestamp: timestamp
        ))

        // Transfer: 1 kg Mehl von Kueche -> Bar
        let group = "transfer-flour-2024-001"
        try ledger.record(StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientFlour, locationID: locationKitchen,
            kind: .transferOut,
            quantity: try quantity(value: 1, unit: .mass(.kilogram)),
            reference: "transfer-flour", transferGroupID: group
        ))
        try ledger.record(StockMovement(
            timestamp: timestamp,
            ingredientID: ingredientFlour, locationID: locationBar,
            kind: .transferIn,
            quantity: try quantity(value: 1, unit: .mass(.kilogram)),
            reference: "transfer-flour", transferGroupID: group
        ))

        return (catalog, ledger)
    }

    private static func quantity(value: Decimal, unit: MeasurementUnit) throws -> InventoryQuantity {
        try InventoryQuantity(amount: value, unit: unit)
    }
}
