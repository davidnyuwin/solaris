import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var showingSaveAlert = false
    @AppStorage("UseMockService") private var useMockService = true
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Hermes Integration Endpoint").foregroundColor(.white.opacity(0.5))) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Server Endpoint URL", text: $viewModel.apiEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                    
                    Text("Specify the URL of your local Hermes Agent API relay daemon. E.g. http://localhost:5080.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("App Preference").foregroundColor(.white.opacity(0.5))) {
                Toggle("Developer Mock Data Mode", isOn: $useMockService)
                Toggle("Launch at Login", isOn: .constant(true))
                Toggle("Keep Window Floating on Top", isOn: .constant(false))
            }
            
            Section {
                Button("Save and Reload Services") {
                    showingSaveAlert = true
                    Task {
                        await viewModel.loadAllData()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.hermesTeal)
            }
        }
        .formStyle(.grouped)
        .background(Color.hermesObsidian.ignoresSafeArea())
        .alert("Settings Updated", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Endpoint updated to \(viewModel.apiEndpoint). Services will sync using this pathway in the future.")
        }
    }
}
