import Foundation

public struct HermesChatHistoryDocument: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var sessions: [HermesChatSession]
    
    public init(schemaVersion: Int, sessions: [HermesChatSession]) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
    }
}

public struct HermesChatSession: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var title: String
    public var runs: [HermesPersistedRun]
    public var isManuallyRenamed: Bool?
    
    public init(id: UUID = UUID(), createdAt: Date = Date(), updatedAt: Date = Date(), title: String, runs: [HermesPersistedRun] = [], isManuallyRenamed: Bool? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.runs = runs
        self.isManuallyRenamed = isManuallyRenamed
    }
}

public struct HermesPersistedRun: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var completedAt: Date?
    public var mode: String
    public var promptPreview: String?
    public var response: String
    public var status: String
    public var errorSummary: String?
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        mode: String,
        promptPreview: String? = nil,
        response: String,
        status: String,
        errorSummary: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.mode = mode
        self.promptPreview = promptPreview
        self.response = response
        self.status = status
        self.errorSummary = errorSummary
    }
}
