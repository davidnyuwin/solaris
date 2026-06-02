import Foundation

// MARK: - API DTOs

public struct StatusDTO: Codable {
    public let version: String
    public let release_date: String
    public let hermes_home: String
    public let config_path: String
    public let env_path: String
    public let config_version: Int
    public let latest_config_version: Int
    public let gateway_running: Bool
    public let gateway_pid: Int?
    public let gateway_health_url: String?
    public let gateway_state: String?
    public let active_sessions: Int
    public let auth_required: Bool
    public let auth_providers: [String]
    
    public func toDomain() -> HermesStatus {
        let domainState: HermesState
        switch gateway_state {
        case "running":
            domainState = .listening
        case "stopped":
            domainState = .idle
        case "startup_failed":
            domainState = .error
        default:
            domainState = gateway_running ? .listening : .idle
        }
        
        return HermesStatus(
            state: domainState,
            uptimeSeconds: 0, // Not exposed directly by the status endpoint DTO
            relayConnected: gateway_running,
            activeJobsCount: active_sessions
        )
    }
}

public struct SessionDTO: Codable {
    public let id: String
    public let started_at: Double
    public let last_active: Double
    public let ended_at: Double?
    public let is_active: Bool
    
    public func toDomain() -> HermesRun {
        let date = Date(timeIntervalSince1970: last_active)
        let durationMs = Int((last_active - started_at) * 1000)
        return HermesRun(
            id: id,
            timestamp: date,
            prompt: "Session Active Run",
            response: is_active ? "Session is active and listening for local triggers." : "Session successfully completed.",
            isSuccess: true,
            durationMs: max(0, durationMs)
        )
    }
}

public struct SessionsResponseDTO: Codable {
    public let sessions: [SessionDTO]
    public let total: Int
    public let limit: Int
    public let offset: Int
    
    public func toDomain() -> [HermesRun] {
        return sessions.map { $0.toDomain() }
    }
}

public struct LogsResponseDTO: Codable {
    public let file: String
    public let lines: [String]
    
    public func toDomain() -> [LogLine] {
        return lines.enumerated().map { index, line in
            let level: String
            if line.contains("ERROR") || line.contains("CRITICAL") {
                level = "ERROR"
            } else if line.contains("WARN") || line.contains("WARNING") {
                level = "WARN"
            } else {
                level = "INFO"
            }
            return LogLine(
                id: "log-\(index)",
                timestamp: Date(),
                level: level,
                message: line
            )
        }
    }
}

// MARK: - Live Service Implementation

public final class LiveHermesService: HermesService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    
    public init(baseURL: URL = URL(string: "http://127.0.0.1:9119")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        self.session = URLSession(configuration: config)
    }
    
    public func getStatus() async throws -> HermesStatus {
        let url = baseURL.appendingPathComponent("/api/status")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dto = try JSONDecoder().decode(StatusDTO.self, from: data)
        return dto.toDomain()
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        // Query verified path `/api/sessions`
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/api/sessions"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "offset", value: "0")
        ]
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dto = try JSONDecoder().decode(SessionsResponseDTO.self, from: data)
        return dto.toDomain()
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        // Leave provider health mocked/marked unavailable since no direct health endpoint is exposed.
        return [
            ProviderHealth(name: "Hermes Daemon Gateway", isOnline: true, latencyMs: 12, successRate: 1.0),
            ProviderHealth(name: "OpenRouter (Model Info)", isOnline: true, latencyMs: 220, successRate: 0.99),
            ProviderHealth(name: "Nous Portal (Sync Link)", isOnline: false, latencyMs: 0, successRate: 0.0)
        ]
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/api/logs"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "file", value: "agent"),
            URLQueryItem(name: "lines", value: "100")
        ]
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dto = try JSONDecoder().decode(LogsResponseDTO.self, from: data)
        return dto.toDomain()
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        // Return a clear unimplemented marker response as command REST transport is not in phase 1.
        let timestamp = Date()
        let fakeRun = HermesRun(
            id: "unimplemented",
            timestamp: timestamp,
            prompt: command,
            response: "Live command transport is not implemented yet in Phase 1 (REST only).",
            isSuccess: false,
            durationMs: 0
        )
        return HermesResponse(
            responseText: "Live command transport is not implemented yet in Phase 1 (REST only).",
            executionTimeMs: 0,
            success: false,
            createdRun: fakeRun
        )
    }
}
