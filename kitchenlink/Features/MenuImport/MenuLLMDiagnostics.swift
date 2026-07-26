import Foundation

/// Diagnostics for provider responses that miss the lossless extraction
/// contract.
///
/// Extracted from `MenuImportService` so the failure paths are directly
/// testable: a real ten-page regression was undiagnosable because the decode
/// error had been discarded, and the only way to learn anything was to pay for
/// another run.
enum MenuLLMDiagnostics {
    /// Turns a contract mapping failure into a message that names the actual
    /// cause: which coding path failed and why.
    ///
    /// The truncation is deliberate. This string travels into
    /// `pageOutcomes[].detail` and therefore into every review report, so it
    /// stays bounded. `KITCHENLINK_LLM_DIAGNOSTICS=1` additionally appends a
    /// bounded excerpt of the provider's own text, which is what distinguishes
    /// a truncated response from a well-formed one that simply disagrees with
    /// the contract. Only menu content travels here — never the API key, which
    /// lives in the request headers.
    static func describeContractMappingFailure(
    _ failure: Error?,
    jsonText: String,
    rawText: String
    ) -> String {
    let headline = "JSON konnte nicht in den verlustfreien Extraktionsvertrag übertragen werden"
    var parts = [headline]

    if let decodingError = failure as? DecodingError {
        parts.append(describeDecodingError(decodingError))
    } else if let failure {
        parts.append("Fehler: \(failure.localizedDescription)")
    }

    // A response that stops mid-object is a length problem, not a schema
    // problem, and the two need opposite fixes.
    let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, !hasBalancedJSONDelimiters(trimmed) {
        parts.append(
            "Antwort ist unvollständig (unbalancierte Klammern, \(trimmed.count) Zeichen) — deutet auf Abschneiden, nicht auf ein Schemaproblem."
        )
    }

    if configValue(forKey: "KITCHENLINK_LLM_DIAGNOSTICS") == "1" {
        parts.append("Rohantwort (\(rawText.count) Zeichen): \(excerpt(rawText, limit: 1200))")
    }

    return parts.joined(separator: " · ")
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
    func path(_ context: DecodingError.Context) -> String {
        let keys = context.codingPath.map(\.stringValue).filter { !$0.isEmpty }
        return keys.isEmpty ? "(Wurzel)" : keys.joined(separator: ".")
    }
    switch error {
    case let .keyNotFound(key, context):
        return "Feld fehlt: \(path(context)).\(key.stringValue)"
    case let .typeMismatch(type, context):
        return "Falscher Typ bei \(path(context)): \(type) erwartet"
    case let .valueNotFound(type, context):
        return "Wert fehlt bei \(path(context)): \(type) erwartet"
    case let .dataCorrupted(context):
        return "Ungültiges JSON bei \(path(context)): \(context.debugDescription)"
    @unknown default:
        return "Unbekannter Dekodierfehler: \(error)"
    }
    }

    /// Cheap structural check for a truncated response. Ignores delimiters
    /// inside string literals, including escaped quotes.
    static func hasBalancedJSONDelimiters(_ text: String) -> Bool {
    var braces = 0
    var brackets = 0
    var insideString = false
    var escaped = false
    for character in text {
        if escaped {
            escaped = false
            continue
        }
        if character == "\\", insideString {
            escaped = true
            continue
        }
        if character == "\"" {
            insideString.toggle()
            continue
        }
        guard !insideString else { continue }
        switch character {
        case "{": braces += 1
        case "}": braces -= 1
        case "[": brackets += 1
        case "]": brackets -= 1
        default: break
        }
        if braces < 0 || brackets < 0 { return false }
    }
    return braces == 0 && brackets == 0 && !insideString
    }

    private static func excerpt(_ text: String, limit: Int) -> String {
    let collapsed = text
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    guard collapsed.count > limit else { return collapsed }
    return String(collapsed.prefix(limit)) + "… [abgeschnitten]"
    }


    private static func configValue(forKey key: String) -> String? {
        if let environment = ProcessInfo.processInfo.environment[key] {
            let trimmed = environment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let bundled = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
