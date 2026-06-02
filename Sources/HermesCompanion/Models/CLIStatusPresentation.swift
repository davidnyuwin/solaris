import Foundation

/// Categorises the raw Hermes CLI status string into a presentation-friendly type.
/// Used by Local Diagnostics UI to pick badge color, label, and explanation text.
public enum CLIStatusKind: String, Sendable, Equatable, CaseIterable {
    case available
    case timedOut
    case pythonMissing
    case nonZeroExit
    case emptyStdout
    case noFieldsParsed
    case unknown

    /// Short badge label (e.g. "Available", "Timed out", "Parse warning").
    public var label: String {
        switch self {
        case .available:      return "Available"
        case .timedOut:       return "Timed out"
        case .pythonMissing:  return "Unavailable"
        case .nonZeroExit:    return "Unavailable"
        case .emptyStdout:    return "Parse warning"
        case .noFieldsParsed: return "Parse warning"
        case .unknown:        return "Unavailable"
        }
    }

    /// Concise user-facing explanation for the current state.
    public var explanation: String {
        switch self {
        case .available:      return "Hermes CLI status checks are working."
        case .timedOut:       return "The read-only CLI check did not finish in time."
        case .pythonMissing:  return "Hermes Studio bundled Python was not found."
        case .nonZeroExit:    return "Hermes CLI returned an error."
        case .emptyStdout:    return "Hermes CLI returned no output."
        case .noFieldsParsed: return "Hermes CLI output changed or could not be parsed."
        case .unknown:        return "Read-only CLI status is not available."
        }
    }
}

/// Parses a raw CLI status string (as produced by LocalHermesDiagnosticsService)
/// into a CLIStatusKind.
public func classifyCLIStatus(_ raw: String?) -> CLIStatusKind {
    guard let status = raw else { return .unknown }

    if status.starts(with: "Available") { return .available }
    if status == "Timed out" { return .timedOut }
    if status.contains("Python missing") { return .pythonMissing }
    if status.contains("Exit code:") { return .nonZeroExit }
    if status.contains("Empty stdout") { return .emptyStdout }
    if status.contains("No fields parsed") || status.contains("Parse warning") { return .noFieldsParsed }

    return .unknown
}
