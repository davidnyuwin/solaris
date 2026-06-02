import Foundation

public final class DynamicHermesService: HermesService, @unchecked Sendable {
    private let mockService: MockHermesService
    private let liveService: LiveHermesService
    
    public init() {
        self.mockService = MockHermesService()
        self.liveService = LiveHermesService(baseURL: URL(string: "http://127.0.0.1:9119")!)
    }
    
    private var useMock: Bool {
        // Toggle on Mock by default if not set
        if UserDefaults.standard.object(forKey: "UseMockService") == nil {
            UserDefaults.standard.set(true, forKey: "UseMockService")
        }
        return UserDefaults.standard.bool(forKey: "UseMockService")
    }
    
    public func getStatus() async throws -> HermesStatus {
        if useMock {
            return try await mockService.getStatus()
        } else {
            return try await liveService.getStatus()
        }
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        if useMock {
            return try await mockService.getRecentRuns()
        } else {
            return try await liveService.getRecentRuns()
        }
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        if useMock {
            return try await mockService.getProviderHealth()
        } else {
            return try await liveService.getProviderHealth()
        }
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        if useMock {
            return try await mockService.getRecentLogs()
        } else {
            return try await liveService.getRecentLogs()
        }
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        if useMock {
            return try await mockService.sendCommand(command)
        } else {
            return try await liveService.sendCommand(command)
        }
    }
}
