import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel: HermesViewModel
    @State private var navigationSelection: NavigationItem? = .dashboard
    
    public init(service: any HermesService = DynamicHermesService()) {
        self._viewModel = StateObject(wrappedValue: HermesViewModel(service: service))
    }
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(selection: $navigationSelection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                // Premium Graphite & Violet Depth Base
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.10), // Slate graphite top
                        Color(red: 0.04, green: 0.03, blue: 0.06)  // Faint solar violet depth bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Ambient top-center solar flare (illuminating the orb region)
                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.50, blue: 0.05).opacity(0.06), // Solaris orange core highlight
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 520
                )
                .ignoresSafeArea()
                
                Group {
                    switch navigationSelection {
                    case .dashboard:
                        DashboardView(viewModel: viewModel)
                    case .runs:
                        RunsView(viewModel: viewModel)
                    case .providers:
                        ProvidersView(viewModel: viewModel)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    case .none:
                        Text("Select an option")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .navigationTitle(navigationSelection?.rawValue ?? "Solaris")
            }
            // Publish focused values so DiagnosticsCommands can reach them from the menu bar
            .focusedValue(\.hermesViewModel, viewModel)
            .focusedValue(\.navigationSelection, navigationSelection ?? .dashboard)
        }
        .task {
            await viewModel.loadAllData()
        }
        .preferredColorScheme(.dark)
    }
}
