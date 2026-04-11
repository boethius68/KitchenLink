import SwiftUI

@main
struct kitchenlinkApp: App {
    @StateObject private var store: KitchenLinkStore
    @StateObject private var relay: OrderRelayService

    init() {
        let repository = LocalDemoRepository()
        _store = StateObject(wrappedValue: KitchenLinkStore(repository: repository))
        _relay = StateObject(wrappedValue: OrderRelayService(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(relay)
        }
    }
}
