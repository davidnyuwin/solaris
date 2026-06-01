import Foundation

public protocol HermesService: Sendable {
    func getStatus() async throws -> HermesStatus
    func getRecentRuns() async throws -> [HermesRun]
    func getProviderHealth() async throws -> [ProviderHealth]
    func getRecentLogs() async throws -> [LogLine]
    func sendCommand(_ command: String) async throws -> HermesResponse
}
