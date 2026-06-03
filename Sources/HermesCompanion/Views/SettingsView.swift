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
        GeometryReader { geometry in
            let isWide = geometry.size.width > 760
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Configure how Solaris connects to Hermes Agent.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding([.top, .horizontal])
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Section 1: Remote Host Mode
                        remoteHostSection
                        
                        // Section 2: Connection Mode
                        connectionModeSection(isWide: isWide)
                        
                        // Section 3: Cards details
                        if isWide {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 16) {
                                    endpointSection
                                    systemPreferencesSection
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(spacing: 16) {
                                    privacySection
                                    developerNotesSection
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 16) {
                                endpointSection
                                systemPreferencesSection
                                privacySection
                                developerNotesSection
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.clear)
        .alert("Settings Updated", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Endpoint updated to \(viewModel.apiEndpoint). Services will sync using this pathway in the future.")
        }
        .onAppear {
            remoteTestStatus = viewModel.remoteHostStatus.state
        }
    }
    
    // MARK: - Sections
    
    // MARK: - Remote Host Section

    @AppStorage("RemoteHost") private var remoteHost = ""
    @AppStorage("RemoteUsername") private var remoteUsername = ""
    @AppStorage("RemotePort") private var remotePort = RemoteHostSettings.defaultPort
    @AppStorage("RemoteHermesCommand") private var remoteHermesCommand = RemoteHostSettings.defaultHermesCommand
    @AppStorage("RemoteIdentityFilePath") private var remoteIdentityFilePath = ""
    #if DEBUG
    @AppStorage("EnableDeveloperRemoteChat") private var enableDeveloperRemoteChat = false
    #endif

    @State private var remoteTestStatus: RemoteHermesStatusSnapshot.ConnectionState = .notConfigured

    private var remoteHostSection: some View {
        SettingsCard(
            title: "Remote Host Mode",
            subtitle: "Connect to a remote Hermes host over SSH for read-only status checks.",
            iconName: "terminal"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Host / SSH alias
                HStack(spacing: 10) {
                    Text("Host")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 70, alignment: .leading)
                    TextField("hermes-host.local", text: $remoteHost)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onChange(of: remoteHost) { _ in
                            viewModel.clearRemoteStatus()
                            remoteTestStatus = .notConfigured
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Username
                HStack(spacing: 10) {
                    Text("User")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 70, alignment: .leading)
                    TextField("Optional", text: $remoteUsername)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onChange(of: remoteUsername) { _ in
                            viewModel.clearRemoteStatus()
                            remoteTestStatus = .notConfigured
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Port
                HStack(spacing: 10) {
                    Text("Port")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 70, alignment: .leading)
                    TextField("22", value: $remotePort, formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .onChange(of: remotePort) { _ in
                            viewModel.clearRemoteStatus()
                            remoteTestStatus = .notConfigured
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Identity File
                HStack(spacing: 10) {
                    Text("Key File")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 70, alignment: .leading)
                    
                    if remoteIdentityFilePath.isEmpty {
                        Text("Default SSH Key (ssh-agent)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text(URL(fileURLWithPath: remoteIdentityFilePath).lastPathComponent)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .help(remoteIdentityFilePath)
                    }
                    
                    Spacer()
                    
                    if !remoteIdentityFilePath.isEmpty {
                        Button(action: {
                            remoteIdentityFilePath = ""
                            viewModel.clearRemoteStatus()
                            remoteTestStatus = .notConfigured
                        }) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.rose)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                            .frame(width: 8)
                    }
                    
                    Button("Browse...") {
                        selectIdentityFile()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.hermesTeal)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Hermes command
                HStack(spacing: 10) {
                    Text("Command")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 70, alignment: .leading)
                    TextField("hermes", text: $remoteHermesCommand)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onChange(of: remoteHermesCommand) { _ in
                            viewModel.clearRemoteStatus()
                            remoteTestStatus = .notConfigured
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                if let diagnostic = viewModel.remoteHostStatus.preflightDiagnostic {
                    SSHPreflightDiagnosticView(diagnostic: diagnostic)
                        .padding(.vertical, 4)
                }

                // Test button + status
                HStack {
                    Button(action: testRemoteConnection) {
                        HStack(spacing: 6) {
                            if viewModel.isTestingRemoteConnection {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 10))
                            }
                            Text(viewModel.isTestingRemoteConnection ? "Testing..." : "Test Remote Connection")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(remoteHost.isEmpty || viewModel.isTestingRemoteConnection
                            ? Color.white.opacity(0.04)
                            : Color.hermesTeal.opacity(0.12))
                        .foregroundColor(remoteHost.isEmpty || viewModel.isTestingRemoteConnection
                            ? .white.opacity(0.3)
                            : .hermesTeal)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(remoteHost.isEmpty || viewModel.isTestingRemoteConnection
                                    ? Color.clear
                                    : Color.hermesTeal.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(remoteHost.isEmpty || viewModel.isTestingRemoteConnection)

                    Spacer()

                    Text(remoteStatusText)
                        .font(.system(size: 10))
                        .foregroundColor(remoteStatusColor)
                        .lineLimit(2)
                }

                // Info text
                Text("Uses your macOS SSH agent for authentication. No passwords or keys are stored in Solaris.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.4))
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                // Agent Forwarding policy statement
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 1)
                    Text("Agent forwarding is not implemented. It is intentionally deferred pending a separate security review.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }

    private var remoteStatusText: String {
        switch remoteTestStatus {
        case .notConfigured:
            return "Configure a host to test the SSH connection."
        case .testing:
            return "Running allowlisted checks on remote host..."
        case .connected:
            return "Connected. Remote Hermes is reachable."
        case .failed(let reason):
            return reason
        }
    }

    private var remoteStatusColor: Color {
        switch remoteTestStatus {
        case .notConfigured: return .white.opacity(0.45)
        case .testing: return .amber
        case .connected: return .emerald
        case .failed: return .rose
        }
    }

    private func selectIdentityFile() {
        #if os(macOS)
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Identity File"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        
        let sshPath = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh")
        openPanel.directoryURL = URL(fileURLWithPath: sshPath)
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                remoteIdentityFilePath = url.path
                viewModel.clearRemoteStatus()
                remoteTestStatus = .notConfigured
            }
        }
        #endif
    }

    private func testRemoteConnection() {
        let settings = RemoteHostSettings(
            host: remoteHost,
            username: remoteUsername,
            port: remotePort,
            hermesCommand: remoteHermesCommand,
            identityFilePath: remoteIdentityFilePath
        )
        remoteTestStatus = .testing
        Task {
            await viewModel.testRemoteConnection(settings: settings)
            remoteTestStatus = viewModel.remoteHostStatus.state
        }
    }

    private func connectionModeSection(isWide: Bool) -> some View {
        SettingsCard(
            title: "Connection Mode",
            subtitle: "Select how Solaris interfaces with background services. Mock Mode is recommended for demos.",
            iconName: "network"
        ) {
            let cards = [
                AnyView(ModeOptionCard(
                    mode: .mock,
                    isSelected: serviceMode == HermesServiceMode.mock.rawValue,
                    statusText: "Recommended",
                    statusColor: .emerald,
                    iconName: "bolt.horizontal.fill",
                    description: "Offline demo data for UI development, screenshots, and safe public demos.",
                    action: { selectMode(.mock) }
                )),
                AnyView(ModeOptionCard(
                    mode: .diagnostics,
                    isSelected: serviceMode == HermesServiceMode.diagnostics.rawValue,
                    statusText: "Useful Today",
                    statusColor: .hermesTeal,
                    iconName: "waveform.path.ecg",
                    description: "Reads local Hermes process and log state without requiring the dashboard API.",
                    action: { selectMode(.diagnostics) }
                )),
                AnyView(ModeOptionCard(
                    mode: .rest,
                    isSelected: serviceMode == HermesServiceMode.rest.rawValue,
                    statusText: "Experimental",
                    statusColor: .amber,
                    iconName: "network",
                    description: "Attempts read-only dashboard API calls when a Hermes REST server is available.",
                    action: { selectMode(.rest) }
                ))
            ]
            
            Group {
                if isWide {
                    HStack(spacing: 12) {
                        ForEach(0..<cards.count, id: \.self) { idx in
                            cards[idx]
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(0..<cards.count, id: \.self) { idx in
                            cards[idx]
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var endpointSection: some View {
        SettingsCard(
            title: "Hermes API Endpoint",
            subtitle: "REST interface URL configuration for live environments.",
            iconName: "link"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("http://127.0.0.1:9119", text: $viewModel.apiEndpoint)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .onChange(of: viewModel.apiEndpoint) {
                                testStatus = .idle
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    
                    Button(action: testConnection) {
                        HStack(spacing: 6) {
                            if testStatus == .testing {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 10))
                            }
                            Text(testStatus == .testing ? "Testing..." : "Test")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(viewModel.apiEndpoint.isEmpty || testStatus == .testing ? Color.white.opacity(0.04) : Color.hermesTeal.opacity(0.12))
                        .foregroundColor(viewModel.apiEndpoint.isEmpty || testStatus == .testing ? .white.opacity(0.3) : .hermesTeal)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.apiEndpoint.isEmpty || testStatus == .testing ? Color.clear : Color.hermesTeal.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.apiEndpoint.isEmpty || testStatus == .testing)
                }
                
                // Diagnostics outputs
                switch testStatus {
                case .idle:
                    Text("Specify the URL of your local Hermes Agent API gateway daemon. Default is port 9119.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                case .testing:
                    Text("Probing local daemon on port \(URL(string: viewModel.apiEndpoint)?.port ?? 9119)...")
                        .font(.system(size: 10))
                        .foregroundColor(.amber)
                case .success:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.emerald)
                        Text("Connection established successfully! Hermes is online.")
                            .foregroundColor(.emerald)
                    }
                    .font(.system(size: 10))
                case .failure(let err):
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.rose)
                        Text(err)
                            .foregroundColor(.rose)
                            .lineLimit(2)
                    }
                    .font(.system(size: 10))
                }
                
                Button("Save and Sync Services") {
                    showingSaveAlert = true
                    Task {
                        await viewModel.loadAllData()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.hermesTeal)
                .cornerRadius(6)
            }
            .padding(.top, 4)
        }
    }
    
    private var systemPreferencesSection: some View {
        SettingsCard(
            title: "System Preferences",
            subtitle: "Integrations for windowing and startup.",
            iconName: "gearshape.fill"
        ) {
            VStack(spacing: 12) {
                Toggle(isOn: .constant(true)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text("Launch daemon agent along with macOS startup.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                Toggle(isOn: .constant(false)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Window Floating on Top")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text("Pins the main Solaris control window on top.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
    
    private var privacySection: some View {
        SettingsCard(
            title: "Privacy & Security",
            subtitle: "Data containment boundaries.",
            iconName: "lock.shield"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                BulletPointRow(
                    icon: "checkmark.shield.fill",
                    color: .emerald,
                    text: "No credentials or third-party API keys are stored, requested, or required today."
                )
                BulletPointRow(
                    icon: "eye.slash.fill",
                    color: .hermesTeal,
                    text: "Privacy Mode in Diagnostics redacts PIDs, absolute paths, and user details in logs."
                )
                BulletPointRow(
                    icon: "key.fill",
                    color: .amber,
                    text: "Future authorization params will use safe macOS Keychain Services API containment."
                )
            }
            .padding(.vertical, 2)
        }
    }
    
    private var developerNotesSection: some View {
        SettingsCard(
            title: "Developer Console",
            subtitle: "Solaris integration phase milestones.",
            iconName: "cpu"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                #if DEBUG
                Toggle(isOn: $enableDeveloperRemoteChat) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Developer Remote Chat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Send console prompts via SSH stdin to remote host.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .emerald))
                .padding(.bottom, 4)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 4)
                #endif

                VStack(spacing: 8) {
                    PhaseStatusRow(name: "Mock Mode", status: "Operational", color: .emerald)
                    PhaseStatusRow(name: "Local Diagnostics", status: "Operational", color: .emerald)
                    PhaseStatusRow(name: "Remote Host Mode", status: "Read-Only", color: .amber)
                    PhaseStatusRow(name: "Experimental REST", status: "Read-Only", color: .amber)
                    PhaseStatusRow(name: "WebSocket Command Channel", status: "Not Implemented", color: .rose)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Actions
    
    private func selectMode(_ mode: HermesServiceMode) {
        serviceMode = mode.rawValue
        useMockService = (serviceMode == HermesServiceMode.mock.rawValue)
        Task {
            await viewModel.loadAllData()
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

// MARK: - Supporting Row Layouts

struct BulletPointRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(2)
        }
    }
}

struct PhaseStatusRow: View {
    let name: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
            
            Spacer()
            
            Text(status)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

struct SSHPreflightDiagnosticView: View {
    let diagnostic: SSHPreflightDiagnostic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: diagnostic.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(diagnostic.color)
                
                Text(diagnostic.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(diagnostic.color)
                
                Spacer()
                
                Text(diagnostic.status.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(diagnostic.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(diagnostic.color.opacity(0.12))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(diagnostic.color.opacity(0.2), lineWidth: 0.5)
                    )
            }
            
            Text(diagnostic.message)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(nil)
            
            if let guide = diagnostic.actionGuide, !guide.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Suggestion:")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(guide)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(diagnostic.color.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(diagnostic.color.opacity(0.15), lineWidth: 1)
        )
    }
}
