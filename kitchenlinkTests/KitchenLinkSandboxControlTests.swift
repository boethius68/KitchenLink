import XCTest
@testable import kitchenlink

final class KitchenLinkSandboxControlTests: XCTestCase {

    func testScenarioTypesAndDescriptions() {
        let scenarios = KitchenLinkSandboxScenarioType.allCases
        XCTAssertEqual(scenarios.count, 4)

        for scenario in scenarios {
            XCTAssertFalse(scenario.title.isEmpty)
            XCTAssertFalse(scenario.subtitle.isEmpty)
            XCTAssertFalse(scenario.icon.isEmpty)
            XCTAssertFalse(scenario.id.isEmpty)
        }

        XCTAssertEqual(KitchenLinkSandboxScenarioType.lunchRush.title, "Mittagsansturm")
        XCTAssertEqual(KitchenLinkSandboxScenarioType.shiftClosing.title, "Tagesabschluss & Kassenprüfung")
        XCTAssertEqual(KitchenLinkSandboxScenarioType.offlineDisaster.title, "Netzwerkausfall & Venue-Hub")
    }

    func testFaultStateDefaults() {
        let fault = KitchenLinkSandboxFaultState()
        XCTAssertFalse(fault.simulatePaymentTimeout)
        XCTAssertFalse(fault.simulateCashVariance)
        XCTAssertFalse(fault.simulateIngredientDepletion)
        XCTAssertFalse(fault.simulateCloudOffline)
    }

    func testBackupExporterJSONCreationAndValidation() {
        let json = KitchenLinkBackupExporter.createSnapshotJSON(
            venueName: "Gasthaus Alte Mühle",
            venueSlug: "alte-muehle",
            tableCount: 12,
            activeOrdersCount: 6,
            cashBalanceCents: 29460,
            tseCount: 2
        )

        XCTAssertTrue(json.contains("\"schemaVersion\" : \"2.0-sandbox-beta\""))
        XCTAssertTrue(json.contains("\"venueName\" : \"Gasthaus Alte M\u{00FC}hle\""))
        XCTAssertTrue(json.contains("\"status\" : \"consistent\""))

        let isValid = KitchenLinkBackupExporter.validateSnapshot(jsonString: json)
        XCTAssertTrue(isValid)
    }

    func testCorruptBackupFailsValidation() {
        XCTAssertFalse(KitchenLinkBackupExporter.validateSnapshot(jsonString: "invalid json string"))
        XCTAssertFalse(KitchenLinkBackupExporter.validateSnapshot(jsonString: "{\"schemaVersion\": \"1.0-deprecated\"}"))
    }
}
