import Foundation

public enum HermesServiceMode: String, CaseIterable, Identifiable {
    case mock = "mock"
    case rest = "rest"
    case diagnostics = "diagnostics"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .mock: return "Mock Mode"
        case .rest: return "Experimental REST Mode"
        case .diagnostics: return "Local Diagnostics Mode"
        }
    }
}

public final class DynamicHermesService: HermesService, @unchecked Sendable {
    private let mockService: MockHermesService
    private let liveService: LiveHermesService
    private let diagnosticsService: LocalHermesDiagnosticsService
    
    public init() {
        self.mockService = MockHermesService()
        self.liveService = LiveHermesService(baseURL: URL(string: "http://127.0.0.1:9119")!)
        self.diagnosticsService = LocalHermesDiagnosticsService()
    }
    
    public var currentMode: HermesServiceMode {
        if let savedMode = UserDefaults.standard.string(forKey: "HermesServiceMode"),
           let mode = HermesServiceMode(rawValue: savedMode) {
            return mode
        }
        
        // Legacy compatibility
        if UserDefaults.standard.object(forKey: "UseMockService") != nil {
            let useMock = UserDefaults.standard.bool(forKey: "UseMockService")
            return useMock ? .mock : .rest
        }
        
        // Default is Mock
        return .mock
    }
    
    private var activeService: any HermesService {
        switch currentMode {
        case .mock:
            return mockService
        case .rest:
            return liveService
        case .diagnostics:
            return diagnosticsService
        }
    }
    
    public func getStatus() async throws -> HermesStatus {
        return try await activeService.getStatus()
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        return try await activeService.getRecentRuns()
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        return try await activeService.getProviderHealth()
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        return try await activeService.getRecentLogs()
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        return try await activeService.sendCommand(command)
    }
}
