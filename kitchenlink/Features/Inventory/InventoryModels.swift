import Foundation

/// Zutat mit Basiseinheit, Mindest- und Zielbestand.
///
/// Bewertung, FIFO-Berechnung, Allergene und Lieferanten-Zuordnung sind
/// bewusst vertagt (siehe `INVENTORY_MODEL.md` §6) und werden durch
/// zusaetzliche Wert- und Beziehungs-Objekte ergaenzt, sobald die
/// Persistenzschnittstelle festgelegt ist.
struct Ingredient: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var baseUnit: MeasurementUnit
    var minimumStock: InventoryQuantity
    var targetStock: InventoryQuantity

    init(
        id: String,
        name: String,
        baseUnit: MeasurementUnit,
        minimumStock: InventoryQuantity,
        targetStock: InventoryQuantity
    ) throws {
        guard minimumStock.unit.isCompatible(with: baseUnit) else {
            throw InventoryModelError.incompatibleStockUnit(
                ingredient: id, dimension: baseUnit.dimensionTitle
            )
        }
        guard targetStock.unit.isCompatible(with: baseUnit) else {
            throw InventoryModelError.incompatibleStockUnit(
                ingredient: id, dimension: baseUnit.dimensionTitle
            )
        }
        guard minimumStock <= targetStock else {
            throw InventoryModelError.minimumAboveTarget(ingredient: id)
        }
        self.id = id
        self.name = name
        self.baseUnit = baseUnit
        self.minimumStock = minimumStock
        self.targetStock = targetStock
    }
}

/// Verkaufsartikel. Verbindet einen Menuepunkt optional mit einem Rezept.
/// Artikel ohne Rezept (z. B. einzelne Flasche Wein) sind zulaessig und
/// fuehren zu keiner Bestandsbewegung.
struct SalesItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var recipeID: String?
}

/// Rezept mit Komponenten. Mehrere Verkaufsartikel koennen dasselbe Rezept
/// referenzieren.
struct Recipe: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var components: [RecipeComponent]
}

/// Einzelne Zutat innerhalb eines Rezepts in der Basiseinheit der Zutat.
struct RecipeComponent: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String
    var ingredientID: String
    var quantity: InventoryQuantity
    var note: String?

    init(
        id: String = UUID().uuidString,
        ingredientID: String,
        quantity: InventoryQuantity,
        note: String? = nil
    ) throws {
        self.id = id
        self.ingredientID = ingredientID
        self.quantity = quantity
        self.note = note
    }
}

/// Lagerort (Kueche, Bar, Keller, Hauptlager, ...). Mehrere Lagerorte
/// innerhalb einer Venue sind zulaessig.
struct StockLocation: Identifiable, Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Equatable, Hashable, Sendable {
        case kitchen
        case bar
        case cellar
        case storage
        case receiving
    }

    let id: String
    var name: String
    var kind: Kind
}

/// Lieferant. Kontaktdaten und Einkaufspreise sind bewusst getrennt, damit
/// Preisanpassungen nicht den Lieferantenstamm beruehren.
struct Supplier: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var name: String
    var contact: String?

    init(id: String, name: String, contact: String? = nil) {
        self.id = id
        self.name = name
        self.contact = contact
    }
}

/// Optionaler Einkaufspreis pro Zutat und Lieferant, in EUR pro Basiseinheit
/// der Zutat. Mehrere aktive Preise pro Paar sind zulaessig; der juengste
/// gewinnt bei Auswertungen.
struct PurchasePrice: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    var supplierID: String
    var ingredientID: String
    var pricePerBaseUnit: Decimal
    var currency: String
    var validFrom: Date
    var validUntil: Date?

    init(
        id: String = UUID().uuidString,
        supplierID: String,
        ingredientID: String,
        pricePerBaseUnit: Decimal,
        currency: String = "EUR",
        validFrom: Date = .now,
        validUntil: Date? = nil
    ) throws {
        guard pricePerBaseUnit.isFinite, !pricePerBaseUnit.isSignMinus else {
            throw InventoryModelError.negativePurchasePrice(ingredient: ingredientID)
        }
        guard currency.count == 3 else {
            throw InventoryModelError.invalidCurrency(code: currency)
        }
        if let validUntil, validUntil < validFrom {
            throw InventoryModelError.invertedValidityRange
        }
        self.id = id
        self.supplierID = supplierID
        self.ingredientID = ingredientID
        self.pricePerBaseUnit = pricePerBaseUnit
        self.currency = currency
        self.validFrom = validFrom
        self.validUntil = validUntil
    }
}

enum InventoryModelError: LocalizedError, Equatable {
    case incompatibleStockUnit(ingredient: String, dimension: String)
    case minimumAboveTarget(ingredient: String)
    case negativePurchasePrice(ingredient: String)
    case invalidCurrency(code: String)
    case invertedValidityRange
    case duplicateComponentIngredient(ingredient: String, recipe: String)
    case unknownIngredient(component: String, recipe: String)
    case unknownLocation(id: String)
    case unknownSalesItem(id: String)
    case unknownRecipe(id: String)
    case unknownSupplier(id: String)
    case unknownIngredientReference(id: String)

    var errorDescription: String? {
        switch self {
        case .incompatibleStockUnit(let ingredient, let dimension):
            return "Mindest- oder Zielbestand der Zutat \(ingredient) passt nicht zur Dimension \(dimension)."
        case .minimumAboveTarget(let ingredient):
            return "Mindestbestand der Zutat \(ingredient) liegt ueber dem Zielbestand."
        case .negativePurchasePrice(let ingredient):
            return "Einkaufspreis fuer \(ingredient) darf nicht negativ sein."
        case .invalidCurrency(let code):
            return "Waehrungscode \(code) ist kein gueltiger ISO-4217-Dreibuchstabencode."
        case .invertedValidityRange:
            return "Gueltigkeit 'von' liegt nach 'bis'."
        case .duplicateComponentIngredient(let ingredient, let recipe):
            return "Rezept \(recipe) enthaelt die Zutat \(ingredient) mehrfach."
        case .unknownIngredient(let component, let recipe):
            return "Komponente \(component) in Rezept \(recipe) verweist auf eine unbekannte Zutat."
        case .unknownLocation(let id):
            return "Unbekannter Lagerort \(id)."
        case .unknownSalesItem(let id):
            return "Unbekannter Verkaufsartikel \(id)."
        case .unknownRecipe(let id):
            return "Unbekanntes Rezept \(id)."
        case .unknownSupplier(let id):
            return "Unbekannter Lieferant \(id)."
        case .unknownIngredientReference(let id):
            return "Unbekannte Zutat \(id)."
        }
    }
}

/// Konsistenter In-Memory-Bestand der Stammdaten. Prueft Verkettungen
/// (Rezept -> Zutat, Rezept -> eindeutige Komponenten) beim Hinzufuegen.
struct InventoryCatalog: Codable, Equatable, Sendable {
    private(set) var ingredients: [String: Ingredient]
    private(set) var salesItems: [String: SalesItem]
    private(set) var recipes: [String: Recipe]
    private(set) var locations: [String: StockLocation]
    private(set) var suppliers: [String: Supplier]
    private(set) var purchasePrices: [String: PurchasePrice]

    init(
        ingredients: [Ingredient] = [],
        salesItems: [SalesItem] = [],
        recipes: [Recipe] = [],
        locations: [StockLocation] = [],
        suppliers: [Supplier] = [],
        purchasePrices: [PurchasePrice] = []
    ) throws {
        var ingredientIndex: [String: Ingredient] = [:]
        for ingredient in ingredients {
            if ingredientIndex[ingredient.id] != nil {
                throw InventoryModelError.unknownIngredientReference(id: ingredient.id)
            }
            ingredientIndex[ingredient.id] = ingredient
        }

        var locationIndex: [String: StockLocation] = [:]
        for location in locations {
            if locationIndex[location.id] != nil {
                throw InventoryModelError.unknownLocation(id: location.id)
            }
            locationIndex[location.id] = location
        }

        var supplierIndex: [String: Supplier] = [:]
        for supplier in suppliers {
            if supplierIndex[supplier.id] != nil {
                throw InventoryModelError.unknownSupplier(id: supplier.id)
            }
            supplierIndex[supplier.id] = supplier
        }

        var recipeIndex: [String: Recipe] = [:]
        for recipe in recipes {
            if recipeIndex[recipe.id] != nil {
                throw InventoryModelError.unknownRecipe(id: recipe.id)
            }
            try Self.validate(recipe: recipe, ingredients: ingredientIndex)
            recipeIndex[recipe.id] = recipe
        }

        var salesItemIndex: [String: SalesItem] = [:]
        for item in salesItems {
            if salesItemIndex[item.id] != nil {
                throw InventoryModelError.unknownSalesItem(id: item.id)
            }
            if let recipeID = item.recipeID, recipeIndex[recipeID] == nil {
                throw InventoryModelError.unknownRecipe(id: recipeID)
            }
            salesItemIndex[item.id] = item
        }

        var priceIndex: [String: PurchasePrice] = [:]
        for price in purchasePrices {
            if priceIndex[price.id] != nil {
                throw InventoryModelError.negativePurchasePrice(ingredient: price.ingredientID)
            }
            if ingredientIndex[price.ingredientID] == nil {
                throw InventoryModelError.unknownIngredientReference(id: price.ingredientID)
            }
            if supplierIndex[price.supplierID] == nil {
                throw InventoryModelError.unknownSupplier(id: price.supplierID)
            }
            priceIndex[price.id] = price
        }

        self.ingredients = ingredientIndex
        self.salesItems = salesItemIndex
        self.recipes = recipeIndex
        self.locations = locationIndex
        self.suppliers = supplierIndex
        self.purchasePrices = priceIndex
    }

    func ingredient(id: String) throws -> Ingredient {
        guard let ingredient = ingredients[id] else {
            throw InventoryModelError.unknownIngredientReference(id: id)
        }
        return ingredient
    }

    func recipe(id: String) throws -> Recipe {
        guard let recipe = recipes[id] else {
            throw InventoryModelError.unknownRecipe(id: id)
        }
        return recipe
    }

    func salesItem(id: String) throws -> SalesItem {
        guard let item = salesItems[id] else {
            throw InventoryModelError.unknownSalesItem(id: id)
        }
        return item
    }

    func location(id: String) throws -> StockLocation {
        guard let location = locations[id] else {
            throw InventoryModelError.unknownLocation(id: id)
        }
        return location
    }

    func supplier(id: String) throws -> Supplier {
        guard let supplier = suppliers[id] else {
            throw InventoryModelError.unknownSupplier(id: id)
        }
        return supplier
    }

    func activePurchasePrice(ingredientID: String, on date: Date) -> PurchasePrice? {
        purchasePrices.values
            .filter { $0.ingredientID == ingredientID }
            .filter { price in
                price.validFrom <= date && (price.validUntil ?? .distantFuture) >= date
            }
            .sorted { lhs, rhs in
                lhs.validFrom > rhs.validFrom
            }
            .first
    }

    private static func validate(
        recipe: Recipe,
        ingredients: [String: Ingredient]
    ) throws {
        var seen: Set<String> = []
        for component in recipe.components {
            if seen.contains(component.ingredientID) {
                throw InventoryModelError.duplicateComponentIngredient(
                    ingredient: component.ingredientID, recipe: recipe.id
                )
            }
            seen.insert(component.ingredientID)
            guard let ingredient = ingredients[component.ingredientID] else {
                throw InventoryModelError.unknownIngredient(
                    component: component.id, recipe: recipe.id
                )
            }
            guard component.quantity.unit.isCompatible(with: ingredient.baseUnit) else {
                throw InventoryModelError.incompatibleStockUnit(
                    ingredient: ingredient.id, dimension: ingredient.baseUnit.dimensionTitle
                )
            }
        }
    }
}
