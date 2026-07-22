import Foundation
import SwiftUI

@main
struct kitchenlinkApp: App {
    @StateObject private var store: KitchenLinkStore
    @StateObject private var relay: OrderRelayService

    init() {
        let repository: LocalDemoRepository
        let uiTestSuite = "sf.kitchenlink.ui-tests"
        if ProcessInfo.processInfo.arguments.contains("--kitchenlink-ui-test-default-menu"),
           let uiTestDefaults = UserDefaults(suiteName: uiTestSuite) {
            uiTestDefaults.removePersistentDomain(forName: uiTestSuite)
            repository = LocalDemoRepository(defaults: uiTestDefaults)
        } else {
            repository = LocalDemoRepository()
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
