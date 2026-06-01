import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: HermesViewModel
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HermesOrbView(state: viewModel.status?.state ?? .idle)
                    .padding(.top, 20)
                
                Text(viewModel.isPendingResponse ? "Hermes is processing..." : "Hermes is listening")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                if let status = viewModel.status {
                    StatusCard(status: status)
                        .padding(.horizontal)
                        .frame(maxWidth: 500)
                }
            }
            
            // Quick action chips
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
                .padding(.horizontal)
            }
            .frame(height: 36)
            
            // Diagnostic Timeline / Mini-Runs
            VStack(alignment: .leading, spacing: 10) {
                Text("DIAGNOSTIC TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            ErrorCard(message: error)
                        }
                        
                        if viewModel.runs.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bolt.horizontal")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No recent timeline records")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.runs.prefix(2)) { run in
                                CommandResultCard(run: run)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Float command box
            CommandBar(text: $viewModel.currentInput, isPending: viewModel.isPendingResponse) {
                Task { await viewModel.sendCommand() }
            }
            .padding([.horizontal, .bottom])
            .frame(maxWidth: 700)
        }
        .background(Color.hermesObsidian.ignoresSafeArea())
    }
}
