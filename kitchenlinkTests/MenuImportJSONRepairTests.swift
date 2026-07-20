import Foundation
import Testing
@testable import kitchenlink

/// KL-SCAN-002: Reparatur unescapter Anführungszeichen in LLM-JSON.
struct MenuImportJSONRepairTests {
    private func decodes(_ s: String) -> Bool {
        guard let d = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: d)) != nil
    }

    @Test func repairsUnescapedQuoteInName() {
        let broken = #"{"items":[{"name":"Wurstsalat „Scheune"","price":1}]}"#
        #expect(!decodes(broken))
        let fixed = MenuImportService.repairJSONStringQuotes(broken)
        #expect(decodes(fixed))
        let obj = try? JSONSerialization.jsonObject(with: fixed.data(using: .utf8)!) as? [String: Any]
        let items = obj?["items"] as? [[String: Any]]
        #expect((items?.first?["name"] as? String) == #"Wurstsalat „Scheune""#)
    }

    @Test func leavesCleanJSONUnchanged() {
        let clean = #"{"sections":[{"title":"Vorspeisen","items":[{"name":"Suppe","price_cents":690}]}]}"#
        #expect(MenuImportService.repairJSONStringQuotes(clean) == clean)
    }

    @Test func preservesEmptyStringsAndEscapes() {
        let s = #"{"a":"","b":"er sagte \"ok\"","c":123}"#
        #expect(MenuImportService.repairJSONStringQuotes(s) == s)
        #expect(decodes(MenuImportService.repairJSONStringQuotes(s)))
    }
}
