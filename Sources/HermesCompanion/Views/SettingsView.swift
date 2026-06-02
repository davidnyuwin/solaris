import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var showingSaveAlert = false
    @AppStorage("UseMockService") private var useMockService = true
    @AppStorage("HermesServiceMode") private var serviceMode = HermesServiceMode.mock.rawValue
    
    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }
    @State private var testStatus: TestStatus = .idle
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Hermes Integration Endpoint").foregroundColor(.white.opacity(0.5))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Server Endpoint URL", text: $viewModel.apiEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                            .onChange(of: viewModel.apiEndpoint) {
                                testStatus = .idle
                            }
                        
                        Button(action: testConnection) {
                            if testStatus == .testing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .disabled(viewModel.apiEndpoint.isEmpty || testStatus == .testing)
                    }
                    
                    // Visual network diagnostic reports
                    switch testStatus {
                    case .idle:
                        Text("Specify the URL of your local Hermes Agent API relay daemon. E.g. http://localhost:9119.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    case .testing:
                        Text("Probing local daemon on port \(URL(string: viewModel.apiEndpoint)?.port ?? 9119)...")
                            .font(.caption)
                            .foregroundColor(.amber)
                    case .success:
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emerald)
                            Text("Connection established successfully! Hermes is online.")
                                .foregroundColor(.emerald)
                        }
                        .font(.caption)
                    case .failure(let err):
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.rose)
                            Text(err)
                                .foregroundColor(.rose)
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("App Preference").foregroundColor(.white.opacity(0.5))) {
                Picker("Connection Mode", selection: $serviceMode) {
                    ForEach(HermesServiceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .onChange(of: serviceMode) {
                    // Update legacy toggle for backward compatibility
                    useMockService = (serviceMode == HermesServiceMode.mock.rawValue)
                    Task {
                        await viewModel.loadAllData()
                    }
                }
                
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
    
    private func testConnection() {
        testStatus = .testing
        
        let trimmed = viewModel.apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            testStatus = .failure("Invalid URL format.")
            return
        }
        
        let testService = LiveHermesService(baseURL: url)
        Task {
            do {
                _ = try await testService.getStatus()
                testStatus = .success
            } catch {
                testStatus = .failure(error.localizedDescription)
            }
        }
    }
}
