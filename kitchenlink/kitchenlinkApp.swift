import SwiftUI

@main
struct kitchenlinkApp: App {
    @StateObject private var store = KitchenLinkStore()
    @StateObject private var relay = OrderRelayService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(relay)
        }
    }
}
