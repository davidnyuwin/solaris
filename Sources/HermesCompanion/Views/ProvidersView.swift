import SwiftUI

public struct ProvidersView: View {
    @ObservedObject var viewModel: HermesViewModel
    @AppStorage("DiagnosticsPrivacyModeEnabled") private var isPrivacyModeActive = true
    
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
                        
                        HStack(spacing: 8) {
                            Text(formatTimestamp(viewModel.lastDiagnosticsRefreshAt))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                                .accessibilityLabel("Last diagnostics refresh time")
                                .accessibilityValue(formatTimestamp(viewModel.lastDiagnosticsRefreshAt))
                            
                            if viewModel.isRefreshingDiagnostics {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                                    .colorInvert()
                            }
                            
                            if let error = viewModel.diagnosticsRefreshError {
                                Text("⚠️ \(error)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.rose.opacity(0.8))
                                    .accessibilityLabel("Refresh error: \(error)")
                            }
                        }
                        .padding(.top, 2)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("Auto-refresh:")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Picker("", selection: $viewModel.refreshInterval) {
                                    ForEach(DiagnosticsRefreshInterval.allCases) { interval in
                                        Text(interval.displayName).tag(interval)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(height: 18)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(4)
                                .accessibilityLabel("Diagnostics auto-refresh interval")
                                .accessibilityValue(viewModel.refreshInterval.displayName)
                                .accessibilityHint("Choose how often Solaris refreshes local diagnostics")
                            }
                            
                            let stateLabelText: String = {
                                switch viewModel.refreshInterval {
                                case .manual:
                                    return "Auto-refresh: Manual"
                                default:
                                    return "Auto-refresh: Every \(viewModel.refreshInterval.displayName)"
                                }
                            }()
                            
                            Text(stateLabelText)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                                .accessibilityLabel("Current diagnostics auto-refresh state")
                                .accessibilityValue(stateLabelText)
                            
                            if viewModel.isDiagnosticsLogPaused && viewModel.refreshInterval != .manual {
                                Text("Logs paused. Status cards may continue refreshing.")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.amber.opacity(0.8))
                                    .accessibilityLabel("Logs paused warning")
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.refreshDiagnostics()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text(viewModel.isRefreshingDiagnostics ? "Refreshing..." : "Refresh")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(viewModel.isRefreshingDiagnostics ? 0.03 : 0.08))
                        .foregroundColor(viewModel.isRefreshingDiagnostics ? .white.opacity(0.4) : .white)
                        .cornerRadius(6)
                        .overlay(
                           RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .disabled(viewModel.isRefreshingDiagnostics)
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                    .padding(.top, 4)
                    .accessibilityLabel("Refresh local diagnostics")
                    .accessibilityHint("Runs read-only diagnostics checks now")
                    
                    Toggle(isOn: $isPrivacyModeActive) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Privacy Mode")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Default-on")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.top, 4)
                    .accessibilityLabel("Diagnostics privacy mode")
                    .accessibilityValue(isPrivacyModeActive ? "On" : "Off")
                    .accessibilityHint("Redacts local paths, process IDs, and token-like strings")
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
        .onAppear {
            viewModel.startScheduler()
        }
        .onDisappear {
            viewModel.stopScheduler()
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
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                let cliStatusText = status?.cliStatus ?? "Unavailable"
                let cliLastCheckedText: String = {
                    if let date = status?.cliLastChecked {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm:ss"
                        return "Checked: \(formatter.string(from: date))"
                    } else {
                        return "Never checked"
                    }
                }()
                
                ProcessStatusRow(
                    name: "Hermes CLI Status",
                    status: cliStatusText.starts(with: "Available") ? .stable : (cliStatusText.contains("Warning") ? .idle : .unavailable),
                    detailText: "Source: Read-only CLI • \(cliStatusText) • \(cliLastCheckedText)",
                    pidText: nil,
                    iconName: "terminal",
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.toggleDiagnosticsLogPause()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isDiagnosticsLogPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 9))
                            Text(viewModel.isDiagnosticsLogPaused ? "Resume Logs" : "Pause Logs")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isDiagnosticsLogPaused ? "Resume diagnostics log updates" : "Pause diagnostics log updates")
                    .accessibilityHint("Freezes or resumes the visible diagnostics log display")
                    
                    Button(action: {
                        viewModel.copyDiagnosticsSummaryToClipboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                            Text(viewModel.copyFeedbackText ?? "Copy Summary")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(viewModel.copyFeedbackText != nil ? .emerald : .white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy redacted diagnostics summary")
                    .accessibilityHint("Copies a privacy-safe diagnostics summary to the clipboard")
                    
                    Spacer()
                    
                    if viewModel.isDiagnosticsLogPaused {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.amber)
                                .frame(width: 6, height: 6)
                            Text("Logs paused")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.amber.opacity(0.9))
                        }
                        .accessibilityLabel("Log updates are currently paused")
                    }
                }
                
                DiagnosticsLogConsole(
                    logs: viewModel.isDiagnosticsLogPaused ? viewModel.pausedLogs : viewModel.logs,
                    isPrivacyActive: isPrivacyModeActive
                )
            }
        }
    }
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let date = date else { return "Last checked: Never" }
        let interval = Date().timeIntervalSince(date)
        
        if interval < 5 {
            return "Last checked: Just now"
        } else if interval < 60 {
            return "Last checked: <1 min ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Last checked: \(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Last checked: \(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "Last checked: \(formatter.string(from: date))"
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
