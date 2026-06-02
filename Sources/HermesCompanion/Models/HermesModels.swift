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
    public let gatewayPID: String?
    
    // Phase 4: CLI status enrichment
    public let activeProvider: String?
    public let activeModel: String?
    
    // Phase 5: CLI availability summary
    public let cliStatus: String?
    public let cliLastChecked: Date?
    
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
        gatewayLogPath: String? = nil,
        gatewayPID: String? = nil,
        activeProvider: String? = nil,
        activeModel: String? = nil,
        cliStatus: String? = nil,
        cliLastChecked: Date? = nil
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
        self.gatewayPID = gatewayPID
        self.activeProvider = activeProvider
        self.activeModel = activeModel
        self.cliStatus = cliStatus
        self.cliLastChecked = cliLastChecked
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

public struct HermesCLIStatusSnapshot: Sendable, Codable {
    public var activeProvider: String?
    public var activeModel: String?
    public var messagingGatewayState: String?
    public var dashboardState: String?
    public var gatewayServiceStatus: String?
    public var gatewayProcessID: String?
    public var platformListeners: String?
    public var activeProfile: String?
    public var configVersion: String?
    public var recentGatewayEvents: [String]
    public var collectedAt: Date
    public var errors: [String]
    
    public init(
        activeProvider: String? = nil,
        activeModel: String? = nil,
        messagingGatewayState: String? = nil,
        dashboardState: String? = nil,
        gatewayServiceStatus: String? = nil,
        gatewayProcessID: String? = nil,
        platformListeners: String? = nil,
        activeProfile: String? = nil,
        configVersion: String? = nil,
        recentGatewayEvents: [String] = [],
        collectedAt: Date = Date(),
        errors: [String] = []
    ) {
        self.activeProvider = activeProvider
        self.activeModel = activeModel
        self.messagingGatewayState = messagingGatewayState
        self.dashboardState = dashboardState
        self.gatewayServiceStatus = gatewayServiceStatus
        self.gatewayProcessID = gatewayProcessID
        self.platformListeners = platformListeners
        self.activeProfile = activeProfile
        self.configVersion = configVersion
        self.recentGatewayEvents = recentGatewayEvents
        self.collectedAt = collectedAt
        self.errors = errors
    }
}

public enum DiagnosticsRefreshInterval: String, CaseIterable, Identifiable, Codable {
    case manual = "manual"
    case thirtySeconds = "thirtySeconds"
    case oneMinute = "oneMinute"
    case fiveMinutes = "fiveMinutes"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .thirtySeconds: return "30 sec"
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        }
    }
    
    public var timeInterval: TimeInterval? {
        switch self {
        case .manual: return nil
        case .thirtySeconds: return 30.0
        case .oneMinute: return 60.0
        case .fiveMinutes: return 300.0
        }
    }
}

