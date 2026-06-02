import Foundation
import Combine
import AppKit

@MainActor
public class HermesViewModel: ObservableObject {
    private let service: any HermesService
    
    @Published public var status: HermesStatus?
    @Published public var runs: [HermesRun] = []
    @Published public var providers: [ProviderHealth] = []
    @Published public var logs: [LogLine] = []
    
    @Published public var currentInput: String = ""
    @Published public var isPendingResponse: Bool = false
    @Published public var errorMessage: String? = nil
    
    @Published public var apiEndpoint: String = "http://127.0.0.1:9119"
    
    // Batch 1 Diagnostics controls
    @Published public var isRefreshingDiagnostics: Bool = false
    @Published public var lastDiagnosticsRefreshAt: Date?
    @Published public var diagnosticsRefreshError: String?
    
    // Batch 2 Diagnostics controls
    @Published public var isDiagnosticsLogPaused: Bool = false
    @Published public var pausedLogs: [LogLine] = []
    @Published public var copyFeedbackText: String? = nil
    
    public func toggleDiagnosticsLogPause() {
        isDiagnosticsLogPaused.toggle()
        if isDiagnosticsLogPaused {
            pausedLogs = logs
        }
    }

    // Batch 3 Diagnostics controls
    @Published public var refreshInterval: DiagnosticsRefreshInterval = .manual {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "DiagnosticsRefreshInterval")
            restartScheduler()
        }
    }
    
    private var schedulerTask: Task<Void, Never>? = nil
    
    public func startScheduler() {
        stopScheduler()
        
        guard let interval = refreshInterval.timeInterval else {
            return
        }
        
        schedulerTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
                
                guard !Task.isCancelled else { break }
                
                if !isRefreshingDiagnostics {
                    await refreshDiagnostics()
                }
            }
        }
    }
    
    public func stopScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }
    
    public func restartScheduler() {
        startScheduler()
    }
    
    public init(service: any HermesService) {
        self.service = service
        
        let savedRaw = UserDefaults.standard.string(forKey: "DiagnosticsRefreshInterval") ?? "manual"
        self.refreshInterval = DiagnosticsRefreshInterval(rawValue: savedRaw) ?? .manual
    }
    
    public func loadAllData() async {
        do {
            errorMessage = nil
            // Fetch concurrently
            async let statusFetch = service.getStatus()
            async let runsFetch = service.getRecentRuns()
            async let providersFetch = service.getProviderHealth()
            async let logsFetch = service.getRecentLogs()
            
            self.status = try await statusFetch
            self.runs = try await runsFetch
            self.providers = try await providersFetch
            self.logs = try await logsFetch
            
            self.lastDiagnosticsRefreshAt = Date()
        } catch {
            errorMessage = "Failed to synchronize status with Hermes Agent: \(error.localizedDescription)"
        }
    }
    
    public func refreshDiagnostics() async {
        isRefreshingDiagnostics = true
        diagnosticsRefreshError = nil
        
        do {
            async let statusFetch = service.getStatus()
            async let providersFetch = service.getProviderHealth()
            async let logsFetch = service.getRecentLogs()
            
            self.status = try await statusFetch
            self.providers = try await providersFetch
            self.logs = try await logsFetch
            
            self.lastDiagnosticsRefreshAt = Date()
        } catch {
            diagnosticsRefreshError = "Diagnostics refresh failed: \(error.localizedDescription)"
        }
        
        isRefreshingDiagnostics = false
    }
    
    public func sendCommand() async {
        let command = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        currentInput = ""
        isPendingResponse = true
        errorMessage = nil
        
        // Simulating immediate transition of visual state orb
        if let currentStatus = status {
            status = HermesStatus(
                state: .processing,
                uptimeSeconds: currentStatus.uptimeSeconds,
                relayConnected: currentStatus.relayConnected,
                activeJobsCount: currentStatus.activeJobsCount + 1
            )
        }
        
        do {
            _ = try await service.sendCommand(command)
            
            // Reload all lists and update states
            async let runsFetch = service.getRecentRuns()
            async let logsFetch = service.getRecentLogs()
            self.runs = try await runsFetch
            self.logs = try await logsFetch
            
            status = try await service.getStatus()
        } catch {
            errorMessage = "Execution failed: \(error.localizedDescription)"
            if let currentStatus = status {
                status = HermesStatus(
                    state: .error,
                    uptimeSeconds: currentStatus.uptimeSeconds,
                    relayConnected: currentStatus.relayConnected,
                    activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                )
            }
        }
        
        isPendingResponse = false
    }
    
    public func executeQuickAction(_ actionName: String) async {
        currentInput = actionName
        await sendCommand()
    }
    
    public func generateDiagnosticsSummary() -> String {
        var summary = "=== Solaris Diagnostics Summary ===\n"
        summary += "Solaris Version: 0.7.0-dev\n"
        
        let savedMode = UserDefaults.standard.string(forKey: "HermesServiceMode") ?? "mock"
        let modeName: String
        if savedMode == "diagnostics" {
            modeName = "Local Diagnostics Mode"
        } else if savedMode == "rest" {
            modeName = "Experimental REST Mode"
        } else {
            modeName = "Mock Mode"
        }
        summary += "Active Mode: \(modeName)\n"
        
        if let lastChecked = lastDiagnosticsRefreshAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            summary += "Last Checked: \(formatter.string(from: lastChecked))\n"
        } else {
            summary += "Last Checked: Never\n"
        }
        
        if let status = status {
            summary += "Gateway State: \(status.gatewayRunning ?? false ? "Active" : "Offline")\n"
            summary += "Dashboard API: \(status.dashboardAvailable ?? false ? "Active (Port 9119)" : "Offline")\n"
            
            let rawCLIStatus = status.cliStatus ?? "Unavailable"
            summary += "Hermes CLI Status: \(DiagnosticsRedactor.redact(rawCLIStatus, redactPIDs: true, redactTokens: true))\n"
            
            if let provider = status.activeProvider {
                summary += "Active Provider: \(provider)\n"
            }
            if let model = status.activeModel {
                summary += "Active Model: \(model)\n"
            }
        } else {
            summary += "Gateway State: Unknown\n"
            summary += "Dashboard API: Unknown\n"
            summary += "Hermes CLI Status: Unknown\n"
        }
        
        if !providers.isEmpty {
            summary += "Active Providers / Relays:\n"
            for provider in providers {
                summary += "  - \(provider.name): \(provider.isOnline ? "Online (\(provider.latencyMs)ms)" : "Offline")\n"
            }
        }
        
        summary += "Diagnostics Log Count: \(logs.count)\n"
        
        // Grab recent log entries, max 5, and sanitize
        let recentLogs = logs.suffix(5)
        if !recentLogs.isEmpty {
            summary += "Recent Event Summaries (max 5):\n"
            for log in recentLogs {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss.SSS"
                let timestampStr = formatter.string(from: log.timestamp)
                let sanitizedMsg = DiagnosticsRedactor.redact(log.message, redactPIDs: true, redactTokens: true)
                summary += "  [\(timestampStr)] [\(log.level)] \(sanitizedMsg)\n"
            }
        }
        
        summary += "===================================\n"
        return summary
    }
    
    public func copyDiagnosticsSummaryToClipboard() {
        let summary = generateDiagnosticsSummary()
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        let success = pasteboard.setString(summary, forType: .string)
        
        if success {
            copyFeedbackText = "Copied"
        } else {
            copyFeedbackText = "Copy failed"
        }
        
        // Reset feedback after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.copyFeedbackText == "Copied" || self.copyFeedbackText == "Copy failed" {
                self.copyFeedbackText = nil
            }
        }
    }
}
