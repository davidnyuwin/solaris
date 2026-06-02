import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

/// Marks whether a diagnostics refresh was triggered interactively or by the
/// auto-refresh scheduler.  Used to decide whether to post an accessibility
/// announcement (manual → announce; scheduled → stay quiet on success).
public enum DiagnosticsRefreshSource: Sendable, Equatable {
    case manual
    case scheduled
}

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

    // Batch 4 Diagnostics controls
    @Published public var exportFeedbackText: String? = nil

    // Batch 5 Accessibility announcement state (anti-spam)
    private var lastAccessibilityAnnouncement: String?
    private var lastAccessibilityAnnouncementAt: Date?
    private let antiSpamCooldown: TimeInterval = 60

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
                    await refreshDiagnostics(source: .scheduled)
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
    
    public func refreshDiagnostics(source: DiagnosticsRefreshSource = .manual) async {
        isRefreshingDiagnostics = true
        diagnosticsRefreshError = nil
        
        let succeeded: Bool
        do {
            async let statusFetch = service.getStatus()
            async let providersFetch = service.getProviderHealth()
            async let logsFetch = service.getRecentLogs()
            
            self.status = try await statusFetch
            self.providers = try await providersFetch
            self.logs = try await logsFetch
            
            self.lastDiagnosticsRefreshAt = Date()
            succeeded = true
        } catch {
            diagnosticsRefreshError = "Diagnostics refresh failed: \(error.localizedDescription)"
            succeeded = false
        }
        
        isRefreshingDiagnostics = false
        
        announceRefreshOutcome(source: source, succeeded: succeeded)
    }
    
    private func announceRefreshOutcome(source: DiagnosticsRefreshSource, succeeded: Bool) {
        let message: String
        switch (source, succeeded) {
        case (.manual, true):
            message = "Diagnostics refreshed."
        case (.manual, false):
            message = "Diagnostics refresh failed."
        case (.scheduled, true):
            // Scheduled success is intentionally silent.
            return
        case (.scheduled, false):
            message = "Scheduled diagnostics refresh failed."
        }
        
        guard shouldAnnounce(message) else { return }
        AccessibilityAnnouncer.announce(message)
        lastAccessibilityAnnouncement = message
        lastAccessibilityAnnouncementAt = Date()
    }
    
    /// Returns `false` if the same message was announced within the anti-spam
    /// cooldown window.  Prevents repeated identical failure noise.
    private func shouldAnnounce(_ message: String) -> Bool {
        guard let lastMsg = lastAccessibilityAnnouncement,
              let lastAt = lastAccessibilityAnnouncementAt else {
            return true
        }
        // Allow repeats of different messages immediately.
        guard lastMsg == message else { return true }
        // Throttle identical repeats.
        return Date().timeIntervalSince(lastAt) >= antiSpamCooldown
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
    
    /// Returns a fully redacted diagnostics summary safe for clipboard or file export.
    /// Always applies DiagnosticsRedactor to redact local paths, PIDs, and token-like strings.
    public func makeRedactedDiagnosticsSummary() -> String {
        var summary = "=== Solaris Diagnostics Summary ===\n"
        summary += "Solaris Version: 0.8.0-dev\n"
        
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
        let summary = makeRedactedDiagnosticsSummary()
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        let success = pasteboard.setString(summary, forType: .string)
        
        if success {
            copyFeedbackText = "Copied"
            AccessibilityAnnouncer.announce("Diagnostics summary copied.")
        } else {
            copyFeedbackText = "Copy failed"
        }
        
        resetCopyFeedbackAfterDelay()
    }

    /// Export a redacted diagnostics summary to a user-selected file via NSSavePanel.
    /// Never writes automatically — requires explicit user save-panel confirmation.
    public func exportRedactedDiagnosticsSummary() {
        let summary = makeRedactedDiagnosticsSummary()

        let savePanel = NSSavePanel()
        savePanel.title = "Export Redacted Diagnostics"
        savePanel.message = "Export a redacted diagnostics summary."
        savePanel.prompt = "Export"
        savePanel.allowedContentTypes = [.plainText]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        savePanel.nameFieldStringValue = "Solaris-Diagnostics-\(formatter.string(from: Date())).txt"

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            exportFeedbackText = "Export cancelled"
            resetExportFeedbackAfterDelay()
            return
        }

        do {
            try summary.write(to: url, atomically: true, encoding: .utf8)
            exportFeedbackText = "Exported"
            AccessibilityAnnouncer.announce("Diagnostics summary exported.")
        } catch {
            exportFeedbackText = "Export failed"
        }

        resetExportFeedbackAfterDelay()
    }

    private func resetCopyFeedbackAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.copyFeedbackText == "Copied" || self.copyFeedbackText == "Copy failed" {
                self.copyFeedbackText = nil
            }
        }
    }

    private func resetExportFeedbackAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let text = self.exportFeedbackText, text == "Exported" || text == "Export cancelled" || text == "Export failed" {
                self.exportFeedbackText = nil
            }
        }
    }
}
