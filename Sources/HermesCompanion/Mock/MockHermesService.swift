import Foundation

public actor MockHermesService: HermesService {
    private var mockRuns: [HermesRun] = [
        HermesRun(
            id: "run-001",
            timestamp: Date().addingTimeInterval(-3600 * 2),
            prompt: "Summarize top tech news from RSS feeds",
            response: "Fetched 12 feeds. Found 3 key topics: 1. Apple WWDC updates. 2. AI chip market expansion. 3. New open-source LLM releases. Compiled summary into obsidian notes.",
            isSuccess: true,
            durationMs: 4200
        ),
        HermesRun(
            id: "run-002",
            timestamp: Date().addingTimeInterval(-1800),
            prompt: "Monitor GPU temperatures and restart worker if over 85C",
            response: "Checked temperature: 76C. Health check passed. Watchdog logs updated.",
            isSuccess: true,
            durationMs: 1250
        ),
        HermesRun(
            id: "run-003",
            timestamp: Date().addingTimeInterval(-600),
            prompt: "Deploy system metrics cron jobs",
            response: "CRITICAL ERROR: Failed to install cron handler. Insufficient permissions on task schedule.",
            isSuccess: false,
            durationMs: 450
        )
    ]
    
    private var mockProviders: [ProviderHealth] = [
        ProviderHealth(name: "OpenAI API", isOnline: true, latencyMs: 280, successRate: 0.99),
        ProviderHealth(name: "Anthropic API", isOnline: true, latencyMs: 320, successRate: 0.985),
        ProviderHealth(name: "Local Llama3 (Ollama)", isOnline: true, latencyMs: 45, successRate: 1.0),
        ProviderHealth(name: "Groq Cloud Relay", isOnline: false, latencyMs: 0, successRate: 0.0)
    ]
    
    private var mockLogs: [LogLine] = [
        LogLine(id: "log-1", timestamp: Date().addingTimeInterval(-600), level: "INFO", message: "Hermes Core v1.4.2 initialized successfully."),
        LogLine(id: "log-2", timestamp: Date().addingTimeInterval(-480), level: "INFO", message: "Listening for local triggers on port 5080..."),
        LogLine(id: "log-3", timestamp: Date().addingTimeInterval(-300), level: "WARN", message: "Provider Groq Cloud Relay is currently unreachable. Swapping to backup Anthropic API."),
        LogLine(id: "log-4", timestamp: Date().addingTimeInterval(-120), level: "ERROR", message: "Cron deployment script exited with code 1.")
    ]
    
    public init() {}
    
    public func getStatus() async throws -> HermesStatus {
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms simulated network latency
        return HermesStatus(
            state: .idle,
            uptimeSeconds: 86420,
            relayConnected: true,
            activeJobsCount: 0
        )
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return mockRuns
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        try await Task.sleep(nanoseconds: 250_000_000)
        return mockProviders
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return mockLogs
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s execution
        
        let newRun = HermesRun(
            id: "run-\(UUID().uuidString.prefix(6).lowercased())",
            timestamp: Date(),
            prompt: command,
            response: generateMockResponse(for: command),
            isSuccess: !command.contains("fail"),
            durationMs: Int.random(in: 300...1500)
        )
        
        mockRuns.insert(newRun, at: 0)
        
        // Append execution logs
        mockLogs.append(LogLine(id: UUID().uuidString, timestamp: Date(), level: newRun.isSuccess ? "INFO" : "ERROR", message: "Executed command: '\(command)' - Success: \(newRun.isSuccess)"))
        
        return HermesResponse(
            responseText: newRun.response,
            executionTimeMs: newRun.durationMs,
            success: newRun.isSuccess,
            createdRun: newRun
        )
    }
    
    private func generateMockResponse(for command: String) -> String {
        let cmd = command.lowercased()
        if cmd.contains("health") || cmd.contains("relay") {
            return "All local relays are functioning normally. Relay latency: 12ms. Core API version: 1.4.2."
        } else if cmd.contains("log") {
            return "Parsed latest 50 logs: 2 WARNINGs, 1 ERROR. Top warning: 'Rate limit threshold hit on third-party provider'. System continues operation safely."
        } else if cmd.contains("restart") {
            return "Watchdog triggered a graceful reset on Hermes daemon process. Main server back online in 142ms. Health check OK."
        } else if cmd.contains("test") {
            return "Tested 4 providers. Local Llama: 100% OK. OpenAI: 100% OK. Anthropic: 100% OK. Groq: OFFLINE."
        } else if cmd.contains("fail") {
            return "CRITICAL FAILURE: Operation aborted by host constraints. Code 403: Execution Forbidden."
        }
        return "Command received and processed by Hermes. Task executed successfully in background."
    }
}
