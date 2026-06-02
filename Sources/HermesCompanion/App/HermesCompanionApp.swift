import SwiftUI

@main
struct SolarisApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            DiagnosticsCommands()
        }
    }
}
