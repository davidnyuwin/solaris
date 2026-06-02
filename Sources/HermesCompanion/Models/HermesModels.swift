import Foundation

public enum HermesState: String, Codable {
    case idle = "Idle"
    case listening = "Listening"
    case processing = "Processing"
    case error = "Error"
}

public struct HermesStatus: Codable {
    public let state: HermesState
    public let uptimeSeconds: Int
    public let relayConnected: Bool
    public let activeJobsCount: Int
    
    // Phase 2: Local Diagnostics Info
    public let gatewayRunning: Bool?
    public let dashboardAvailable: Bool?
    public let agentLogFound: Bool?
    public let gatewayLogFound: Bool?
    public let agentLogPath: String?
    public let gatewayLogPath: String?
    
    public init(
        state: HermesState,
        uptimeSeconds: Int,
        relayConnected: Bool,
        activeJobsCount: Int,
        gatewayRunning: Bool? = nil,
        dashboardAvailable: Bool? = nil,
        agentLogFound: Bool? = nil,
        gatewayLogFound: Bool? = nil,
        agentLogPath: String? = nil,
        gatewayLogPath: String? = nil
    ) {
        self.state = state
        self.uptimeSeconds = uptimeSeconds
        self.relayConnected = relayConnected
        self.activeJobsCount = activeJobsCount
        self.gatewayRunning = gatewayRunning
        self.dashboardAvailable = dashboardAvailable
        self.agentLogFound = agentLogFound
        self.gatewayLogFound = gatewayLogFound
        self.agentLogPath = agentLogPath
        self.gatewayLogPath = gatewayLogPath
    }
}

public struct HermesRun: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let prompt: String
    public let response: String
    public let isSuccess: Bool
    public let durationMs: Int
    
    public init(id: String, timestamp: Date, prompt: String, response: String, isSuccess: Bool, durationMs: Int) {
        self.id = id
        self.timestamp = timestamp
        self.prompt = prompt
        self.response = response
        self.isSuccess = isSuccess
        self.durationMs = durationMs
    }
}

public struct ProviderHealth: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let isOnline: Bool
    public let latencyMs: Int
    public let successRate: Double
    
    public init(name: String, isOnline: Bool, latencyMs: Int, successRate: Double) {
        self.name = name
        self.isOnline = isOnline
        self.latencyMs = latencyMs
        self.successRate = successRate
    }
}

public struct LogLine: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let level: String // "INFO", "WARN", "ERROR"
    public let message: String
    
    public init(id: String, timestamp: Date, level: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct HermesResponse: Codable {
    public let responseText: String
    public let executionTimeMs: Int
    public let success: Bool
    public let createdRun: HermesRun
    
    public init(responseText: String, executionTimeMs: Int, success: Bool, createdRun: HermesRun) {
        self.responseText = responseText
        self.executionTimeMs = executionTimeMs
        self.success = success
        self.createdRun = createdRun
    }
}
