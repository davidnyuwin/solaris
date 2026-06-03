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
    #if DEBUG
    internal var historyStore: any ChatHistoryStoring
    #else
    private let historyStore: any ChatHistoryStoring
    #endif
    
    @Published public var status: HermesStatus?
    @Published public var runs: [HermesRun] = []
    @Published public var providers: [ProviderHealth] = []
    @Published public var logs: [LogLine] = []
    
    @Published public var currentInput: String = ""
    @Published public var isPendingResponse: Bool = false
    @Published public var errorMessage: String? = nil
    
    @Published public var apiEndpoint: String = "http://127.0.0.1:9119"
    
    // Batch 2G Chat UX / Stream State Hardening
    @Published public var chatState: ChatExecutionState = .idle
    #if DEBUG
    internal var activeChatTask: Task<Void, Never>? = nil
    internal var chatTimeout: TimeInterval = 30
    #else
    private var activeChatTask: Task<Void, Never>? = nil
    private let chatTimeout: TimeInterval = 30
    #endif
    private var activeChatRunID: String? = nil
    private var fetchedServiceRuns: [HermesRun] = []
    
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
    
    public init(service: any HermesService, historyStore: any ChatHistoryStoring = ChatHistoryStore()) {
        self.service = service
        self.historyStore = historyStore
        
        let savedRaw = UserDefaults.standard.string(forKey: "DiagnosticsRefreshInterval") ?? "manual"
        self.refreshInterval = DiagnosticsRefreshInterval(rawValue: savedRaw) ?? .manual
    }
    
    public func loadAllData() async {
        await loadChatHistory()
        do {
            errorMessage = nil
            // Fetch concurrently
            async let statusFetch = service.getStatus()
            async let runsFetch = service.getRecentRuns()
            async let providersFetch = service.getProviderHealth()
            async let logsFetch = service.getRecentLogs()
            
            self.status = try await statusFetch
            
            let fetchedRuns = try await runsFetch
            self.fetchedServiceRuns = fetchedRuns
            self.runs = fetchedRuns
            self.mergePersistedRunsIntoUI()
            
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
        errorMessage = nil
        
        // Handle cancel command typed in console
        if command.lowercased() == "/cancel" {
            if chatState == .connecting || chatState == .streaming {
                await cancelActiveChat()
            } else {
                errorMessage = "No active remote chat stream to cancel."
            }
            return
        }
        
        isPendingResponse = true
        
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
            guard !chatState.isActive else {
                errorMessage = "Another remote chat stream is already active."
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
            
            chatState = .validating
            
            let prompt = command.hasPrefix("/chat ")
                ? String(command.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            
            // Prompt Validation
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPrompt.isEmpty else {
                errorMessage = "Chat prompt cannot be empty."
                chatState = .failed("Chat prompt cannot be empty.")
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
                chatState = .failed("Invalid prompt encoding.")
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
                chatState = .failed("Chat prompt exceeds maximum allowed size of 16KB.")
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
            
            let currentMode = UserDefaults.standard.string(forKey: "HermesServiceMode") ?? "mock"
            if currentMode == "mock" {
                // Mock execution flow
                let runID = UUID().uuidString
                self.activeChatRunID = runID
                
                let placeholderRun = HermesRun(
                    id: runID,
                    timestamp: Date(),
                    prompt: "/chat \(prompt)",
                    response: "",
                    isSuccess: false,
                    durationMs: 0
                )
                self.runs.insert(placeholderRun, at: 0)
                
                self.activeChatTask = Task {
                    self.chatState = .connecting
                    do {
                        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    } catch {
                        return
                    }
                    
                    self.chatState = .streaming
                    
                    let mockOpenAIKey = "sk-" + "abcdefghijklmnopqrstuvwxyz123456"
                    let mockChunks = [
                        "Hello! This is a mock chat response for your prompt: \"\(prompt)\".\n",
                        "\u{001B}[31mThis text had ANSI colors\u{001B}[0m and a hidden link \u{001B}]8;;http://malicious.url\u{0007}Click Here\u{001B}]8;;\u{0007}.\n",
                        "System user directory: /Users/sysadmin/hermes-agent\n",
                        "Secret OpenAI key: \(mockOpenAIKey)\n",
                        "API_SECRET = 'my-super-secret-credentials'\n",
                        "Commit hash 8220c964ecedcc55ffceb7ce4aaeba5f038cc25c."
                    ]
                    
                    var rawMockAccumulated = ""
                    let startTime = Date()
                    
                    for chunk in mockChunks {
                        guard !Task.isCancelled else { break }
                        
                        rawMockAccumulated += chunk
                        
                        let sanitisedResult = OutputSanitiser.sanitise(rawMockAccumulated, isStreaming: true)
                        
                        if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                            self.runs[index] = HermesRun(
                                id: runID,
                                timestamp: placeholderRun.timestamp,
                                prompt: placeholderRun.prompt,
                                response: sanitisedResult.text,
                                isSuccess: false,
                                durationMs: Int(Date().timeIntervalSince(startTime) * 1000)
                            )
                        }
                        
                        do {
                            try await Task.sleep(nanoseconds: 150_000_000)
                        } catch {
                            break
                        }
                    }
                    
                    guard !Task.isCancelled else {
                        return
                    }
                    
                    let finalSanitised = OutputSanitiser.sanitise(rawMockAccumulated, isStreaming: false)
                    if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                        let finalRun = HermesRun(
                            id: runID,
                            timestamp: placeholderRun.timestamp,
                            prompt: placeholderRun.prompt,
                            response: finalSanitised.text,
                            isSuccess: true,
                            durationMs: Int(Date().timeIntervalSince(startTime) * 1000)
                        )
                        self.runs[index] = finalRun
                        await self.saveActiveChatRun(finalRun)
                    }
                    
                    self.logs.append(LogLine(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        level: "INFO",
                        message: "Mock Chat simulation complete. Output sanitised."
                    ))
                    
                    self.chatState = .completed
                    self.activeChatTask = nil
                    self.activeChatRunID = nil
                    
                    if let currentStatus = self.status {
                        self.status = HermesStatus(
                            state: .idle,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    self.isPendingResponse = false
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
                    chatState = .failed("Remote chat is disabled.")
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
                    hermesCommand: UserDefaults.standard.string(forKey: "RemoteHermesCommand") ?? RemoteHostSettings.defaultHermesCommand,
                    identityFilePath: UserDefaults.standard.string(forKey: "RemoteIdentityFilePath") ?? ""
                )

                guard settings.isValid else {
                    errorMessage = "Remote host is not configured."
                    chatState = .failed("Remote host is not configured.")
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
                let runID = UUID().uuidString
                self.activeChatRunID = runID
                
                // Insert a placeholder run card so we can update it in real-time!
                let placeholderRun = HermesRun(
                    id: runID,
                    timestamp: Date(),
                    prompt: "/chat \(trimmedPrompt)",
                    response: "",
                    isSuccess: false,
                    durationMs: 0
                )
                self.runs.insert(placeholderRun, at: 0)

                self.chatState = .connecting

                self.activeChatTask = Task {
                    var rawStdout = ""
                    var rawStderr = ""
                    var executionStatus = -1
                    var didTimeOut = false
                    var failedReason: String? = nil

                    let stream = self.remoteSSHExecutor.executeStreaming(
                        command: .hermesChat,
                        settings: settings,
                        timeout: self.chatTimeout,
                        stdinData: promptData
                    )

                    for await event in stream {
                        guard !Task.isCancelled else {
                            break
                        }
                        
                        switch event {
                        case .stdout(let text):
                            if self.chatState == .connecting {
                                self.chatState = .streaming
                            }
                            rawStdout += text
                            let sanitisedResult = OutputSanitiser.sanitise(rawStdout, isStreaming: true)
                            if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                                self.runs[index] = HermesRun(
                                    id: runID,
                                    timestamp: placeholderRun.timestamp,
                                    prompt: placeholderRun.prompt,
                                    response: sanitisedResult.text,
                                    isSuccess: false,
                                    durationMs: Int(Date().timeIntervalSince(startTime) * 1000)
                                )
                            }
                            
                        case .stderr(let text):
                            rawStderr += text
                            let sanitisedText = OutputSanitiser.sanitise(text).text
                            if !sanitisedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                self.logs.append(LogLine(
                                    id: UUID().uuidString,
                                    timestamp: Date(),
                                    level: "INFO",
                                    message: "Remote chat stderr: \(sanitisedText)"
                                ))
                            }
                            
                        case .status(let text):
                            if self.chatState == .connecting {
                                self.chatState = .streaming
                            }
                            self.logs.append(LogLine(
                                id: UUID().uuidString,
                                timestamp: Date(),
                                level: "INFO",
                                message: "Remote status: \(text)"
                            ))
                            
                        case .completed(let exitCode):
                            executionStatus = Int(exitCode)
                            
                        case .failed(let reason):
                            failedReason = reason
                            
                        case .timedOut:
                            didTimeOut = true
                        }
                    }

                    guard !Task.isCancelled else {
                        return
                    }

                    let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

                    if didTimeOut {
                        self.chatState = .timedOut
                        self.errorMessage = "The connection timed out after 30 seconds. Verify remote host performance."
                        if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                            let timedOutRun = HermesRun(
                                id: runID,
                                timestamp: placeholderRun.timestamp,
                                prompt: placeholderRun.prompt,
                                response: "[Timeout] The connection timed out after 30 seconds.",
                                isSuccess: false,
                                durationMs: durationMs
                            )
                            self.runs[index] = timedOutRun
                            await self.saveActiveChatRun(timedOutRun)
                        }
                        if let currentStatus = self.status {
                            self.status = HermesStatus(
                                state: .error,
                                uptimeSeconds: currentStatus.uptimeSeconds,
                                relayConnected: currentStatus.relayConnected,
                                activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                            )
                        }
                        self.activeChatTask = nil
                        self.activeChatRunID = nil
                        self.isPendingResponse = false
                        return
                    }

                    if let reason = failedReason {
                        self.chatState = .failed(reason)
                        self.errorMessage = "SSH command execution failed: \(reason)"
                        if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                            let failedRun = HermesRun(
                                id: runID,
                                timestamp: placeholderRun.timestamp,
                                prompt: placeholderRun.prompt,
                                response: "[Failed] SSH command execution failed: \(reason)",
                                isSuccess: false,
                                durationMs: durationMs
                            )
                            self.runs[index] = failedRun
                            await self.saveActiveChatRun(failedRun)
                        }
                        if let currentStatus = self.status {
                            self.status = HermesStatus(
                                state: .error,
                                uptimeSeconds: currentStatus.uptimeSeconds,
                                relayConnected: currentStatus.relayConnected,
                                activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                            )
                        }
                        self.activeChatTask = nil
                        self.activeChatRunID = nil
                        self.isPendingResponse = false
                        return
                    }

                    let sanitisedStdout = OutputSanitiser.sanitise(rawStdout, isStreaming: false)
                    let sanitisedStderr = OutputSanitiser.sanitise(rawStderr)

                    if executionStatus != 0 {
                        let safeStderr = sanitisedStderr.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        let errMsg = "SSH command failed (exit code: \(executionStatus)).\(safeStderr.isEmpty ? "" : " Detail: \(safeStderr)")"
                        self.chatState = .failed(errMsg)
                        self.errorMessage = errMsg
                        if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                            let failedExitRun = HermesRun(
                                id: runID,
                                timestamp: placeholderRun.timestamp,
                                prompt: placeholderRun.prompt,
                                response: "[Failed] \(errMsg)",
                                isSuccess: false,
                                durationMs: durationMs
                            )
                            self.runs[index] = failedExitRun
                            await self.saveActiveChatRun(failedExitRun)
                        }
                        if let currentStatus = self.status {
                            self.status = HermesStatus(
                                state: .error,
                                uptimeSeconds: currentStatus.uptimeSeconds,
                                relayConnected: currentStatus.relayConnected,
                                activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                            )
                        }
                        self.activeChatTask = nil
                        self.activeChatRunID = nil
                        self.isPendingResponse = false
                        return
                    }

                    // Successful execution complete!
                    self.chatState = .completed
                    if let index = self.runs.firstIndex(where: { $0.id == runID }) {
                        let completedRun = HermesRun(
                            id: runID,
                            timestamp: placeholderRun.timestamp,
                            prompt: placeholderRun.prompt,
                            response: sanitisedStdout.text,
                            isSuccess: true,
                            durationMs: durationMs
                        )
                        self.runs[index] = completedRun
                        await self.saveActiveChatRun(completedRun)
                    }

                    // Add completion log entry
                    self.logs.append(LogLine(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        level: "INFO",
                        message: "Remote Chat execution complete. Output sanitised."
                    ))

                    // Update state to idle
                    if let currentStatus = self.status {
                        self.status = HermesStatus(
                            state: .idle,
                            uptimeSeconds: currentStatus.uptimeSeconds,
                            relayConnected: currentStatus.relayConnected,
                            activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
                        )
                    }
                    self.activeChatTask = nil
                    self.activeChatRunID = nil
                    self.isPendingResponse = false
                }
            }
            
            return
        }

        do {
            _ = try await service.sendCommand(command)
            
            // Reload all lists and update states
            async let runsFetch = service.getRecentRuns()
            async let logsFetch = service.getRecentLogs()
            let fetchedRuns = try await runsFetch
            self.fetchedServiceRuns = fetchedRuns
            self.runs = fetchedRuns
            self.logs = try await logsFetch
            self.mergePersistedRunsIntoUI()
            
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
    
    public func cancelActiveChat() async {
        guard chatState == .connecting || chatState == .streaming else { return }
        
        self.logs.append(LogLine(
            id: UUID().uuidString,
            timestamp: Date(),
            level: "INFO",
            message: "Remote chat cancelled by user."
        ))
        
        activeChatTask?.cancel()
        activeChatTask = nil
        
        chatState = .cancelled
        isPendingResponse = false
        
        if let runID = activeChatRunID, let index = self.runs.firstIndex(where: { $0.id == runID }) {
            let existing = self.runs[index]
            let cancelledRun = HermesRun(
                id: runID,
                timestamp: existing.timestamp,
                prompt: existing.prompt,
                response: existing.response.isEmpty ? "[Cancelled]" : existing.response + "\n[Cancelled]",
                isSuccess: false,
                durationMs: existing.durationMs
            )
            self.runs[index] = cancelledRun
            await self.saveActiveChatRun(cancelledRun)
        }
        activeChatRunID = nil
        
        if let currentStatus = status {
            status = HermesStatus(
                state: .idle,
                uptimeSeconds: currentStatus.uptimeSeconds,
                relayConnected: currentStatus.relayConnected,
                activeJobsCount: max(0, currentStatus.activeJobsCount - 1)
            )
        }
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
    internal var sshPreflightService = SSHPreflightService()
    #else
    private let remoteSSHExecutor = RemoteSSHExecutor()
    private let sshPreflightService = SSHPreflightService()
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
        
        // 0. Preflight validation
        guard RemoteHostSettings.isValidHost(settings.host) else {
            remoteHostStatus = RemoteHermesStatusSnapshot(
                hostLabel: settings.displayLabel,
                hermesFound: false,
                hermesVersion: nil,
                statusSummary: nil,
                lastCheckedAt: Date(),
                errorMessage: "Host cannot contain metacharacters or whitespace."
            )
            isTestingRemoteConnection = false
            return
        }
        
        guard RemoteHostSettings.isValidUsername(settings.username) else {
            remoteHostStatus = RemoteHermesStatusSnapshot(
                hostLabel: settings.displayLabel,
                hermesFound: false,
                hermesVersion: nil,
                statusSummary: nil,
                lastCheckedAt: Date(),
                errorMessage: "Username cannot contain spaces, '@', or metacharacters."
            )
            isTestingRemoteConnection = false
            return
        }
        
        guard RemoteHostSettings.isValidPort(settings.port) else {
            remoteHostStatus = RemoteHermesStatusSnapshot(
                hostLabel: settings.displayLabel,
                hermesFound: false,
                hermesVersion: nil,
                statusSummary: nil,
                lastCheckedAt: Date(),
                errorMessage: "Port must be between 1 and 65535."
            )
            isTestingRemoteConnection = false
            return
        }
        
        // 1. Run local preflight diagnostic checks
        let preflightDiag = await sshPreflightService.performPreflightChecks(settings: settings)
        if let diagnostic = preflightDiag, (diagnostic.status == .fail || diagnostic.status == .warning) {
            remoteHostStatus = RemoteHermesStatusSnapshot(
                hostLabel: settings.displayLabel,
                hermesFound: false,
                hermesVersion: nil,
                statusSummary: nil,
                lastCheckedAt: Date(),
                errorMessage: diagnostic.message,
                preflightDiagnostic: diagnostic
            )
            isTestingRemoteConnection = false
            return
        }

        let passDiag = SSHPreflightDiagnostic(
            status: .pass,
            title: "Preflight Passed",
            message: "Your local SSH keys and agent are ready for connection."
        )

        remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settings.displayLabel,
            hermesFound: false,
            hermesVersion: nil,
            statusSummary: nil,
            lastCheckedAt: Date(),
            errorMessage: nil,
            preflightDiagnostic: passDiag
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
            errors.append("Command unavailable (Hermes not found)")
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
        
        let finalDiag = errorMessage == nil ? SSHPreflightDiagnostic(
            status: .pass,
            title: "Preflight Passed",
            message: "Your local SSH keys and agent are ready for connection."
        ) : nil

        remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settings.displayLabel,
            hermesFound: hermesFound,
            hermesVersion: versionLine,
            statusSummary: statusSummary,
            lastCheckedAt: Date(),
            errorMessage: errorMessage,
            preflightDiagnostic: finalDiag
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
    
    // MARK: - Chat History Persistence (Batch 2H/2I)
    
    public var sessions: [HermesChatSession] {
        chatHistory.sessions
    }
    
    public var activeSession: HermesChatSession? {
        chatHistory.sessions.first(where: { $0.id == activeSessionID })
    }
    
    public var runsForActiveSession: [HermesRun] {
        guard let session = activeSession else { return [] }
        return session.runs.map { persisted in
            HermesRun(
                id: persisted.id.uuidString,
                timestamp: persisted.createdAt,
                prompt: persisted.promptPreview ?? "",
                response: persisted.response,
                isSuccess: persisted.status == "completed",
                durationMs: persisted.completedAt.map { Int($0.timeIntervalSince(persisted.createdAt) * 1000) } ?? 0
            )
        }.sorted(by: { $0.timestamp > $1.timestamp })
    }

    @Published public var chatHistory: HermesChatHistoryDocument = HermesChatHistoryDocument(schemaVersion: 1, sessions: [])
    @Published public var activeSessionID: UUID? = nil

    public func loadChatHistory() async {
        let doc = await historyStore.load()
        self.chatHistory = doc
        
        if let latestSession = doc.sessions.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            self.activeSessionID = latestSession.id
        } else {
            let newSession = HermesChatSession(title: "New Chat")
            self.chatHistory.sessions.append(newSession)
            self.activeSessionID = newSession.id
            try? await historyStore.save(self.chatHistory)
        }
        
        self.mergePersistedRunsIntoUI()
    }

    public func createNewSession() {
        if chatState.isActive {
            errorMessage = "Finish or cancel the active chat before switching sessions."
            return
        }
        let newSession = HermesChatSession(title: "New Chat")
        self.chatHistory.sessions.append(newSession)
        self.activeSessionID = newSession.id
        
        Task {
            try? await historyStore.save(self.chatHistory)
        }
        
        self.runs = self.fetchedServiceRuns
    }

    public func selectSession(id: UUID) {
        if chatState.isActive {
            errorMessage = "Finish or cancel the active chat before switching sessions."
            return
        }
        activeSessionID = id
        mergePersistedRunsIntoUI()
    }

    public func renameSession(id: UUID, title: String) {
        if chatState.isActive {
            errorMessage = "Finish or cancel the active chat before managing sessions."
            return
        }
        guard let index = chatHistory.sessions.firstIndex(where: { $0.id == id }) else { return }
        
        let sanitised = sanitiseTitle(title)
        chatHistory.sessions[index].title = sanitised
        chatHistory.sessions[index].isManuallyRenamed = true
        chatHistory.sessions[index].updatedAt = Date()
        
        Task {
            try? await historyStore.save(chatHistory)
        }
    }
    
    public func deleteSession(id: UUID) {
        if chatState.isActive {
            errorMessage = "Finish or cancel the active chat before managing sessions."
            return
        }
        guard let index = chatHistory.sessions.firstIndex(where: { $0.id == id }) else { return }
        
        chatHistory.sessions.remove(at: index)
        
        if chatHistory.sessions.isEmpty {
            let newSession = HermesChatSession(title: "New Chat")
            chatHistory.sessions.append(newSession)
            activeSessionID = newSession.id
        } else if activeSessionID == id {
            let sortedRemaining = chatHistory.sessions.sorted(by: { $0.updatedAt > $1.updatedAt })
            activeSessionID = sortedRemaining.first?.id
        }
        
        mergePersistedRunsIntoUI()
        
        Task {
            try? await historyStore.save(chatHistory)
        }
    }
    
    public func clearChatHistory() {
        if chatState.isActive {
            errorMessage = "Finish or cancel the active chat before managing sessions."
            return
        }
        
        let defaultSession = HermesChatSession(title: "New Chat")
        self.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [defaultSession])
        self.activeSessionID = defaultSession.id
        
        self.runs = self.fetchedServiceRuns
        
        Task {
            try? await historyStore.save(self.chatHistory)
        }
    }
    
    public func sanitiseTitle(_ title: String) -> String {
        var clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return "New Chat"
        }
        
        clean = clean.components(separatedBy: .controlCharacters).joined()
        clean = DiagnosticsRedactor.redact(clean)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.count > 40 {
            return String(clean.prefix(40)) + "..."
        }
        return clean.isEmpty ? "New Chat" : clean
    }

    private func mergePersistedRunsIntoUI() {
        guard let sessionID = activeSessionID,
              let session = chatHistory.sessions.first(where: { $0.id == sessionID }) else {
            return
        }
        
        let chatRuns = session.runs.map { persisted in
            HermesRun(
                id: persisted.id.uuidString,
                timestamp: persisted.createdAt,
                prompt: persisted.promptPreview ?? "",
                response: persisted.response,
                isSuccess: persisted.status == "completed",
                durationMs: persisted.completedAt.map { Int($0.timeIntervalSince(persisted.createdAt) * 1000) } ?? 0
            )
        }
        
        var currentRuns = self.fetchedServiceRuns
        for chatRun in chatRuns {
            if !currentRuns.contains(where: { $0.id == chatRun.id }) {
                currentRuns.append(chatRun)
            }
        }
        
        self.runs = currentRuns.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private func saveActiveChatRun(_ uiRun: HermesRun) async {
        let persistedRun = makePersistedRun(from: uiRun)
        
        guard let sessionID = activeSessionID else { return }
        
        if let sessionIndex = chatHistory.sessions.firstIndex(where: { $0.id == sessionID }) {
            if let runIndex = chatHistory.sessions[sessionIndex].runs.firstIndex(where: { $0.id == persistedRun.id }) {
                chatHistory.sessions[sessionIndex].runs[runIndex] = persistedRun
            } else {
                chatHistory.sessions[sessionIndex].runs.append(persistedRun)
            }
            
            // Derive title if it's currently "New Chat" or empty/default and not manually renamed
            let isManual = chatHistory.sessions[sessionIndex].isManuallyRenamed ?? false
            let currentTitle = chatHistory.sessions[sessionIndex].title
            if !isManual && (currentTitle == "New Chat" || currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                if let preview = persistedRun.promptPreview {
                    chatHistory.sessions[sessionIndex].title = cleanAndCapTitle(preview)
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    chatHistory.sessions[sessionIndex].title = "Chat on \(formatter.string(from: Date()))"
                }
            }
            
            chatHistory.sessions[sessionIndex].updatedAt = Date()
            
            do {
                try await historyStore.save(chatHistory)
            } catch {
                // Silent error metadata capture
            }
        }
    }

    private func cleanAndCapTitle(_ preview: String) -> String {
        var clean = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("/chat ") {
            clean = String(clean.dropFirst(6))
        } else if clean.lowercased().hasPrefix("chat ") {
            clean = String(clean.dropFirst(5))
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        
        clean = clean.components(separatedBy: .controlCharacters).joined()
        
        if clean.count > 40 {
            return String(clean.prefix(40)) + "..."
        }
        return clean.isEmpty ? "New Chat" : clean
    }

    private func makePersistedRun(from uiRun: HermesRun) -> HermesPersistedRun {
        let promptPreview = cleanAndCapPrompt(uiRun.prompt)
        let sanitisedResponse = OutputSanitiser.sanitise(uiRun.response, isStreaming: false).text
        
        let statusStr: String
        let errorSummary: String?
        
        switch chatState {
        case .completed:
            statusStr = "completed"
            errorSummary = nil
        case .failed(let reason):
            statusStr = "failed"
            errorSummary = reason
        case .cancelled:
            statusStr = "cancelled"
            errorSummary = "Cancelled by user"
        case .timedOut:
            statusStr = "timedOut"
            errorSummary = "Connection timed out"
        default:
            statusStr = uiRun.isSuccess ? "completed" : "failed"
            errorSummary = nil
        }
        
        let idUUID = UUID(uuidString: uiRun.id) ?? UUID()
        let durationSeconds = Double(uiRun.durationMs) / 1000.0
        
        return HermesPersistedRun(
            id: idUUID,
            createdAt: uiRun.timestamp,
            completedAt: uiRun.timestamp.addingTimeInterval(durationSeconds),
            mode: UserDefaults.standard.string(forKey: "HermesServiceMode") ?? "mock",
            promptPreview: promptPreview,
            response: sanitisedResponse,
            status: statusStr,
            errorSummary: errorSummary
        )
    }

    private func cleanAndCapPrompt(_ prompt: String) -> String {
        let cleanPrompt = OutputSanitiser.sanitise(prompt, isStreaming: false).text
        if cleanPrompt.count > 120 {
            return String(cleanPrompt.prefix(120)) + "..."
        }
        return cleanPrompt
    }
}
