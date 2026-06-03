import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: HermesViewModel
    @AppStorage("HermesServiceMode") private var serviceMode = HermesServiceMode.mock.rawValue
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 1000
            
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    Group {
                        if isWide {
                            HStack(alignment: .top, spacing: 20) {
                                // Left/Center: Hero Area
                                heroColumn
                                    .frame(maxWidth: .infinity)
                                
                                // Right: Context Rail
                                contextRailColumn
                                    .frame(width: 300)
                            }
                        } else {
                            VStack(spacing: 24) {
                                heroColumn
                                contextRailColumn
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.clear)
        .task {
            await viewModel.loadAllData()
        }
    }
    
    // MARK: - Subviews
    
    private var heroColumn: some View {
        VStack(spacing: 24) {
            // Solaris Orb and Heading
            VStack(spacing: 10) {
                HermesOrbView(state: viewModel.status?.state ?? .idle)
                    .frame(height: 150)
                    .padding(.top, 10)
                
                Text(viewModel.isPendingResponse ? "Solaris is processing..." : "Solaris is listening")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(calmingSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Error panel if active
            if let error = viewModel.errorMessage {
                ErrorCard(message: error)
                    .frame(maxWidth: 480)
            }
            
            // Quick action chips
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ACTION TELEMETRY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickActionChip(label: "Check relay health", icon: "bolt.fill") {
                            Task { await viewModel.executeQuickAction("Check relay health") }
                        }
                        QuickActionChip(label: "Summarize logs", icon: "list.bullet.rectangle") {
                            Task { await viewModel.executeQuickAction("Summarize latest logs") }
                        }
                        QuickActionChip(label: "Restart watchdog", icon: "arrow.clockwise") {
                            Task { await viewModel.executeQuickAction("Restart watchdog") }
                        }
                        QuickActionChip(label: "Test providers", icon: "network") {
                            Task { await viewModel.executeQuickAction("Test providers") }
                        }
                    }
                }
            }
            .frame(maxWidth: 480)
            
            // Last Context Execution mini card
            if let lastRun = viewModel.runs.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LAST CONTEXT EXECUTION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.horizontal, 4)
                        
                        Spacer()
                        
                        if viewModel.chatState == .connecting || viewModel.chatState == .streaming {
                            Button(action: {
                                viewModel.cancelActiveChat()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "stop.circle.fill")
                                    Text("Cancel")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.rose)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    CommandResultCard(run: lastRun)
                }
                .frame(maxWidth: 480)
            }
            
            Spacer(minLength: 20)
            
            // Floating Command input capsule
            CommandBar(
                text: $viewModel.currentInput,
                isPending: viewModel.isPendingResponse,
                onSend: {
                    Task { await viewModel.sendCommand() }
                },
                onCancel: {
                    viewModel.cancelActiveChat()
                }
            )
            .frame(maxWidth: 480)
            .padding(.bottom, 10)
        }
    }
    
    private var contextRailColumn: some View {
        let mode = HermesServiceMode(rawValue: serviceMode) ?? .mock
        return DashboardContextRail(
            mode: mode,
            status: viewModel.status,
            runs: viewModel.runs,
            logs: viewModel.logs,
            onQuickAction: { action in
                Task { await viewModel.executeQuickAction(action) }
            },
            onSwapMode: { newMode in
                serviceMode = newMode.rawValue
                UserDefaults.standard.set(newMode.rawValue, forKey: "HermesServiceMode")
                UserDefaults.standard.set(newMode == .mock, forKey: "UseMockService")
                Task {
                    await viewModel.loadAllData()
                }
            }
        )
    }
    
    private var calmingSubtitle: String {
        let mode = HermesServiceMode(rawValue: serviceMode) ?? .mock
        switch mode {
        case .mock:
            return "Solaris is running in Mock Mode. All visual telemetry is sandboxed."
        case .diagnostics:
            return "Solaris is monitoring local process logs and PID states."
        case .rest:
            return "Solaris is polling REST API telemetry from live gateway."
        }
    }
}
