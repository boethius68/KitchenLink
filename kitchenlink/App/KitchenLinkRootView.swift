import SwiftUI

struct KitchenLinkRootView: View {
    var body: some View {
        KitchenLinkV2BusinessHomeView()
            .preferredColorScheme(forcedColorScheme)
    }

    private var forcedColorScheme: ColorScheme? {
        switch KitchenLinkDesignPreviewConfiguration.forcedAppearance() {
        case .dark:
            return .dark
        case .light:
            return .light
        case nil:
            return nil
        }
    }
}
