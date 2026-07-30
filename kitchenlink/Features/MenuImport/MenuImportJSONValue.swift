import Foundation

/// Ein kodierbarer JSON-Baum.
///
/// Gebraucht, weil das Anbieterschema (`MenuImportExtractionSchema`) als Teil
/// eines `Encodable`-Anfragekörpers verschickt wird. `[String: Any]` lässt sich
/// nicht durch `JSONEncoder` schieben, und ein vorserialisiertes Fragment
/// wieder einzufädeln wäre ein Umweg mit Fehlerpotenzial. Ein expliziter Baum
/// ist stattdessen prüfbar und typsicher.
indirect enum MenuImportJSONValue: Encodable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([MenuImportJSONValue])
    case object([String: MenuImportJSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let values): try container.encode(values)
        case .object(let values): try container.encode(values)
        }
    }
}

extension MenuImportJSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension MenuImportJSONValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: MenuImportJSONValue...) {
        self = .array(elements)
    }
}

extension MenuImportJSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, MenuImportJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
