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
        
        // Check if command is a chat prompt query
        if command.lowercased().hasPrefix("/chat") {
            let prompt = command.hasPrefix("/chat ")
                ? String(command.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            
            let currentMode = UserDefaults.standard.string(forKey: "HermesServiceMode") ?? "mock"
            if currentMode == "mock" {
                // Mock execution flow
                let mockOpenAIKey = "sk-" + "abcdefghijklmnopqrstuvwxyz123456"
                let rawMockResponse = """
                Hello! This is a mock chat response for your prompt: "\(prompt)".
                \u{001B}[31mThis text had ANSI colors\u{001B}[0m and a hidden link \u{001B}]8;;http://malicious.url\u{0007}Click Here\u{001B}]8;;\u{0007}.
                System user directory: /Users/sysadmin/hermes-agent
                Secret OpenAI key: \(mockOpenAIKey)
                API_SECRET = 'my-super-secret-credentials'
                Commit hash 8220c964ecedcc55ffceb7ce4aaeba5f038cc25c.
                """

                // Pass mock response through OutputSanitiser
                let sanitisedResult = OutputSanitiser.sanitise(rawMockResponse)
                
                // Simulate network latency delay (800ms)
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                let newRun = HermesRun(
                    id: "run-chat-\(UUID().uuidString.prefix(6).lowercased())",
                    timestamp: Date(),
                    prompt: "/chat \(prompt)",
                    response: sanitisedResult.text,
                    isSuccess: true,
                    durationMs: 800
                )
                self.runs.insert(newRun, at: 0)
                
                // Add log entry
                self.logs.append(LogLine(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    level: "INFO",
                    message: "Mock Chat simulation complete. Output sanitised."
                ))
                
                // Update state to idle
                if let currentStatus = status {
                    status = HermesStatus(
                        state: .idle,
                        uptimeSeconds: currentStatus.uptimeSeconds,
                        relayConnected: currentStatus.relayConnected,
                        activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                    )
                }
            } else {
                // Live execution block
                #if DEBUG
                let isDeveloperRemoteChatEnabled = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
                #else
                let isDeveloperRemoteChatEnabled = false
                #endif

                if !isDeveloperRemoteChatEnabled {
                    errorMessage = "Remote chat is disabled. Enable the developer remote chat gate to test stdin-based Hermes chat execution."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                // Prompt Validation
                let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPrompt.isEmpty else {
                    errorMessage = "Chat prompt cannot be empty."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                guard let promptData = trimmedPrompt.data(using: .utf8) else {
                    errorMessage = "Invalid prompt encoding."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                guard promptData.count <= 16384 else {
                    errorMessage = "Chat prompt exceeds maximum allowed size of 16KB."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                let settings = RemoteHostSettings(
                    host: UserDefaults.standard.string(forKey: "RemoteHost") ?? "",
                    username: UserDefaults.standard.string(forKey: "RemoteUsername") ?? "",
                    port: UserDefaults.standard.integer(forKey: "RemotePort") == 0 ? RemoteHostSettings.defaultPort : UserDefaults.standard.integer(forKey: "RemotePort"),
                    hermesCommand: UserDefaults.standard.string(forKey: "RemoteHermesCommand") ?? RemoteHostSettings.defaultHermesCommand
                )

                guard settings.isValid else {
                    errorMessage = "Remote host is not configured."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                // Append developer warning log before execution (do not log prompt text)
                self.logs.append(LogLine(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    level: "WARNING",
                    message: "Developer remote chat is enabled. Prompts are sent to the configured remote Hermes host via SSH stdin. Prompt text is not logged."
                ))

                let startTime = Date()
                let result = await remoteSSHExecutor.execute(
                    command: .hermesChat,
                    settings: settings,
                    timeout: 30,
                    stdinData: promptData
                )

                let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

                if result.timedOut {
                    errorMessage = "The connection timed out after 30 seconds. Verify remote host performance."
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                // Sanitise stdout and stderr
                let sanitisedStdout = OutputSanitiser.sanitise(result.stdout)
                let sanitisedStderr = OutputSanitiser.sanitise(result.stderr)

                if result.exitCode != 0 {
                    let safeStderr = sanitisedStderr.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = "SSH command failed (exit code: \(result.exitCode)).\(safeStderr.isEmpty ? "" : " Detail: \(safeStderr)")"
                    if let currentStatus = status {
                        status = HermesStatus(
                            state: .error,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    isPendingResponse = false
                    return
                }

                // Add log entry for stderr if any
                if !sanitisedStderr.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.logs.append(LogLine(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        level: "ERROR",
                        message: "Remote chat stderr: \(sanitisedStderr.text)"
                    ))
                }

                let newRun = HermesRun(
                    id: "run-chat-\(UUID().uuidString.prefix(6).lowercased())",
                    timestamp: Date(),
                    prompt: "/chat \(trimmedPrompt)",
                    response: sanitisedStdout.text,
                    isSuccess: true,
                    durationMs: durationMs
                )
                self.runs.insert(newRun, at: 0)

                // Add completion log entry
                self.logs.append(LogLine(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    level: "INFO",
                    message: "Remote Chat execution complete. Output sanitised."
                ))

                // Update state to idle
                if let currentStatus = status {
                    status = HermesStatus(
                        state: .idle,
                        uptimeSeconds: currentStatus.uptimeSeconds,
                        relayConnected: currentStatus.relayConnected,
                        activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                    )
                }
            }
            
            isPendingResponse = false
            return
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

    // MARK: - Remote Host Mode (v0.9 Batch 1)

    /// Current remote host status — populated after a connection test.
    @Published public var remoteHostStatus: RemoteHermesStatusSnapshot = .notConfigured

    /// True while a remote connection test is in progress.
    @Published public var isTestingRemoteConnection: Bool = false

    #if DEBUG
    internal var remoteSSHExecutor = RemoteSSHExecutor()
    #else
    private let remoteSSHExecutor = RemoteSSHExecutor()
    #endif

    /// Reset remote status (e.g. when settings change).
    public func clearRemoteStatus() {
        remoteHostStatus = .notConfigured
    }

    /// Run all three allowlisted remote checks sequentially and update
    /// `remoteHostStatus` with the result.
    @MainActor
    public func testRemoteConnection(settings: RemoteHostSettings) async {
        isTestingRemoteConnection = true
        remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settings.displayLabel,
            hermesFound: false,
            hermesVersion: nil,
            statusSummary: nil,
            lastCheckedAt: Date(),
            errorMessage: nil
        )

        // 1. which hermes
        let whichResult = await remoteSSHExecutor.execute(
            command: .whichHermes, settings: settings
        )

        // Early-exit if the SSH transport itself failed (exit 255) or timed out.
        // This avoids 2 redundant failing SSH attempts against an unreachable host.
        let sshTransportFailed = whichResult.exitCode == 255 || whichResult.timedOut
        if sshTransportFailed {
            let reason = whichResult.timedOut
                ? "Timed out"
                : sanitiseSSHError(whichResult.stderr)
            remoteHostStatus = RemoteHermesStatusSnapshot(
                hostLabel: settings.displayLabel,
                hermesFound: false,
                hermesVersion: nil,
                statusSummary: nil,
                lastCheckedAt: Date(),
                errorMessage: reason
            )
            isTestingRemoteConnection = false
            return
        }

        let hermesFound = whichResult.exitCode == 0
            && !whichResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // 2. hermes --version
        let versionResult = await remoteSSHExecutor.execute(
            command: .hermesVersion, settings: settings
        )
        let versionLine = versionResult.exitCode == 0
            ? versionResult.stdout
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        // 3. hermes status
        let statusResult = await remoteSSHExecutor.execute(
            command: .hermesStatus, settings: settings
        )
        let statusSummary = statusResult.exitCode == 0
            ? statusResult.stdout
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        // Collect errors from any step
        var errors: [String] = []
        if versionResult.timedOut || statusResult.timedOut {
            errors.append("Timed out")
        }
        if !hermesFound {
            errors.append("Hermes not found")
        }
        if whichResult.exitCode != 0 && !whichResult.timedOut {
            errors.append(sanitiseSSHError(whichResult.stderr))
        }
        if versionResult.exitCode != 0 && !versionResult.timedOut && versionResult.exitCode != 127 {
            errors.append("Version check failed")
        }
        if statusResult.exitCode != 0 && !statusResult.timedOut && statusResult.exitCode != 127 {
            errors.append("Status check failed")
        }

        let errorMessage = errors.isEmpty ? nil : errors.joined(separator: "; ")

        remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settings.displayLabel,
            hermesFound: hermesFound,
            hermesVersion: versionLine,
            statusSummary: statusSummary,
            lastCheckedAt: Date(),
            errorMessage: errorMessage
        )

        isTestingRemoteConnection = false
    }

    /// Redact common SSH error patterns so we never show raw hostnames,
    /// usernames, or paths in the UI.
    private func sanitiseSSHError(_ stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "SSH connection failed" }
        // Short common patterns
        if trimmed.contains("Connection refused") { return "Connection refused" }
        if trimmed.contains("Connection timed out") { return "Connection timed out" }
        if trimmed.contains("Permission denied") { return "Permission denied" }
        if trimmed.contains("Host key verification") { return "Host key verification failed" }
        if trimmed.contains("No route to host") { return "No route to host" }
        if trimmed.contains("Name or service not known") { return "Host not found" }
        // Fallback: just the first line, redact anything that looks like a path
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
        let redacted = firstLine
            .replacingOccurrences(of: #"/[^\s:]+"#, with: "[path]", options: .regularExpression)
        return redacted.isEmpty ? "SSH command failed" : redacted
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
