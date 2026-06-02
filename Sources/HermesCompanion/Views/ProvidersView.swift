import SwiftUI

public struct ProvidersView: View {
    @ObservedObject var viewModel: HermesViewModel
    @State private var isPrivacyModeActive = false
    
    public init(viewModel: HermesViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 760
            
            VStack(alignment: .leading, spacing: 0) {
                // Header & Privacy Toggle
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Diagnostics")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Local process, log, and dashboard API visibility for Hermes Agent.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Toggle(isOn: $isPrivacyModeActive) {
                        Text("Privacy Mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .toggleStyle(.checkbox)
                    .padding(.top, 4)
                }
                .padding([.top, .horizontal])
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Top status cards (Gateway, Agent Logs, Gateway Logs, Dashboard API)
                        topCardsView(isWide: isWide)
                        
                        // Main Panels
                        if isWide {
                            HStack(alignment: .top, spacing: 16) {
                                processesPanel
                                    .frame(maxWidth: .infinity)
                                
                                logsPanel
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 16) {
                                processesPanel
                                logsPanel
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.clear)
        .task {
            await viewModel.loadAllData()
        }
    }
    
    // MARK: - Subviews
    
    private func topCardsView(isWide: Bool) -> some View {
        let status = viewModel.status
        
        let isGatewayRunning = status?.gatewayRunning ?? true
        let isAgentLogFound = status?.agentLogFound ?? true
        let isGatewayLogFound = status?.gatewayLogFound ?? true
        let isDashboardAvailable = status?.dashboardAvailable ?? true
        
        let gatewayPIDText = status?.gatewayPID
        
        let cards = [
            AnyView(QuickStatusCard(
                title: "Gateway Process",
                statusText: isGatewayRunning ? "Active" : "Missing",
                statusColor: isGatewayRunning ? .emerald : .rose,
                iconName: "cpu",
                detail: isGatewayRunning ? (gatewayPIDText != nil ? (isPrivacyModeActive ? "[PID]" : "PID: \(gatewayPIDText!)") : "Running") : "Offline"
            )),
            AnyView(QuickStatusCard(
                title: "Agent Logs",
                statusText: isAgentLogFound ? "Stable" : "Missing",
                statusColor: isAgentLogFound ? .emerald : .rose,
                iconName: "doc.text",
                detail: isAgentLogFound ? "Found" : "Not Found"
            )),
            AnyView(QuickStatusCard(
                title: "Gateway Logs",
                statusText: isGatewayLogFound ? "Stable" : "Missing",
                statusColor: isGatewayLogFound ? .emerald : .rose,
                iconName: "doc.text",
                detail: isGatewayLogFound ? "Found" : "Not Found"
            )),
            AnyView(QuickStatusCard(
                title: "Dashboard API",
                statusText: isDashboardAvailable ? "Active" : "Unavailable",
                statusColor: isDashboardAvailable ? .emerald : .amber,
                iconName: "network",
                detail: isDashboardAvailable ? "Port 9119" : "Offline"
            ))
        ]
        
        return Group {
            if isWide {
                HStack(spacing: 12) {
                    ForEach(0..<cards.count, id: \.self) { idx in
                        cards[idx]
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<cards.count, id: \.self) { idx in
                        cards[idx]
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var processesPanel: some View {
        DiagnosticPanel(
            title: "System Checks & Status",
            subtitle: "Local daemon configuration and processes.",
            iconName: "checklist"
        ) {
            VStack(spacing: 6) {
                let status = viewModel.status
                
                let isGatewayRunning = status?.gatewayRunning ?? true
                let isAgentLogFound = status?.agentLogFound ?? true
                let isGatewayLogFound = status?.gatewayLogFound ?? true
                let isDashboardAvailable = status?.dashboardAvailable ?? true
                
                let gatewayPIDText = status?.gatewayPID
                let agentLogPath = status?.agentLogPath ?? "~/.hermes/logs/agent.log"
                let gatewayLogPath = status?.gatewayLogPath ?? "~/.hermes/logs/gateway.log"
                
                ProcessStatusRow(
                    name: "Gateway Process",
                    status: isGatewayRunning ? .active : .missing,
                    detailText: isGatewayRunning ? "Main background daemon execution" : "Launch with: hermes gateway run",
                    pidText: isGatewayRunning ? gatewayPIDText : nil,
                    iconName: "cpu",
                    isPrivacyActive: isPrivacyModeActive
                )
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                ProcessStatusRow(
                    name: "Agent Log",
                    status: isAgentLogFound ? .stable : .missing,
                    detailText: agentLogPath,
                    pidText: nil,
                    iconName: "doc.text.fill",
                    isPrivacyActive: isPrivacyModeActive
                )
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                ProcessStatusRow(
                    name: "Gateway Log",
                    status: isGatewayLogFound ? .stable : .missing,
                    detailText: gatewayLogPath,
                    pidText: nil,
                    iconName: "doc.text.fill",
                    isPrivacyActive: isPrivacyModeActive
                )
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                ProcessStatusRow(
                    name: "Dashboard API",
                    status: isDashboardAvailable ? .stable : .unavailable,
                    detailText: "Experimental REST Port: 9119",
                    pidText: nil,
                    iconName: "network",
                    isPrivacyActive: isPrivacyModeActive
                )
                
                if !viewModel.providers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Providers & Relays")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 14)
                            .padding(.horizontal, 6)
                        
                        ForEach(viewModel.providers) { provider in
                            ProcessStatusRow(
                                name: provider.name,
                                status: provider.isOnline ? .stable : .unavailable,
                                detailText: provider.isOnline ? "Online • \(provider.latencyMs)ms latency • \(Int(provider.successRate * 100))% success" : "Offline / Unreachable",
                                pidText: nil,
                                iconName: "server.rack",
                                isPrivacyActive: isPrivacyModeActive
                            )
                        }
                    }
                }
                
                Text("Read-only CLI status checks are enabled in Local Diagnostics Mode.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var logsPanel: some View {
        DiagnosticPanel(
            title: "Parsed System Logs",
            subtitle: "Ingested agent and gateway diagnostics.",
            iconName: "terminal.fill"
        ) {
            DiagnosticsLogConsole(logs: viewModel.logs, isPrivacyActive: isPrivacyModeActive)
        }
    }
}

// MARK: - Supporting Component

struct QuickStatusCard: View {
    let title: String
    let statusText: String
    let statusColor: Color
    let iconName: String
    let detail: String?
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor.opacity(0.12))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let detail = detail {
                        Text(detail)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.015))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .cornerRadius(10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.01)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
