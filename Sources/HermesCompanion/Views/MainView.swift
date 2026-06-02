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
            .navigationTitle(navigationSelection?.rawValue ?? "Hermes Companion")
        }
        .task {
            await viewModel.loadAllData()
        }
        .preferredColorScheme(.dark)
    }
}
