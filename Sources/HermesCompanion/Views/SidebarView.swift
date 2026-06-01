import SwiftUI

public enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case runs = "Recent Runs"
    case providers = "Provider Health"
    case settings = "Settings"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .dashboard: return "bolt.horizontal.circle.fill"
        case .runs: return "doc.text.magnifyingglass"
        case .providers: return "network"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct SidebarView: View {
    @Binding var selection: NavigationItem?
    
    public init(selection: Binding<NavigationItem?>) {
        self._selection = selection
    }
    
    public var body: some View {
        List(selection: $selection) {
            Section("Monitor") {
                ForEach([NavigationItem.dashboard, .runs, .providers]) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                    }
                }
            }
            
            Section("Configure") {
                NavigationLink(value: NavigationItem.settings) {
                    Label(NavigationItem.settings.rawValue, systemImage: NavigationItem.settings.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
