import Foundation

public enum DiagnosticLogSource: String, Codable, Equatable, CaseIterable {
    case app
    case mock
    case localDiagnostics
    case sshPreflight
    case liveProbe
    case redaction
    case privacy
}

public enum DiagnosticLogSeverity: String, Codable, Equatable, CaseIterable {
    case info
    case warning
    case error
}

public struct DiagnosticLogEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let source: DiagnosticLogSource
    public let severity: DiagnosticLogSeverity
    public let message: String
    public let redacted: Bool
    public let truncated: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: DiagnosticLogSource,
        severity: DiagnosticLogSeverity,
        message: String,
        redacted: Bool,
        truncated: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.severity = severity
        self.message = message
        self.redacted = redacted
        self.truncated = truncated
    }
}
