import SwiftUI

@main
struct HermesCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
