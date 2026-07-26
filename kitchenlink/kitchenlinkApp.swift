import Foundation
import SwiftUI

@main
struct kitchenlinkApp: App {
    @StateObject private var store: KitchenLinkStore
    @StateObject private var relay: OrderRelayService

    init() {
        let repository: any KitchenLinkRepository
        let uiTestSuite = "sf.kitchenlink.ui-tests"
        if ProcessInfo.processInfo.arguments.contains("--kitchenlink-ui-test-default-menu"),
           let uiTestDefaults = UserDefaults(suiteName: uiTestSuite) {
            // UI tests stay on the deterministic in-memory-suite demo repository
            // so they never inherit a persisted order log between runs.
            uiTestDefaults.removePersistentDomain(forName: uiTestSuite)
            repository = LocalDemoRepository(defaults: uiTestDefaults)
        } else {
            // Real launches keep orders in the durable event log (local-first),
            // while venue/menu/QR data stays on the demo repository underneath.
            repository = EventLogOrderRepository.makeDefault()
        }
        _store = StateObject(wrappedValue: KitchenLinkStore(repository: repository))
        _relay = StateObject(wrappedValue: OrderRelayService(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            KitchenLinkRootView()
                .environmentObject(store)
                .environmentObject(relay)
        }
    }
}
