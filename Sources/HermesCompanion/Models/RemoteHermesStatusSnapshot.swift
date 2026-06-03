import Foundation

/// Immutable snapshot of a remote Hermes host connection test result.
/// Separate from local diagnostics — the remote host is the source of truth.
public struct RemoteHermesStatusSnapshot: Sendable, Equatable {
    /// The display label for the configured remote host.
    public let hostLabel: String

    /// Whether `which hermes` found the Hermes binary on the remote host.
    public let hermesFound: Bool

    /// Parsed `hermes --version` output (first line only).
    public let hermesVersion: String?

    /// Parsed `hermes status` output (first meaningful line or nil for error).
    public let statusSummary: String?

    /// When the check was run.
    public let lastCheckedAt: Date

    /// Short, sanitised error message if any command failed.  Never contains
    /// raw hostnames, usernames, paths, or token-like strings.
    public let errorMessage: String?

    /// Structured SSH diagnostic details if preflight checks detect local
    /// setup warnings or failures.
    public let preflightDiagnostic: SSHPreflightDiagnostic?

    /// Structured remote readiness/connection state machine state.
    public let connectionState: RemoteConnectionState

    /// Structured remote background daemon state.
    public let daemonState: RemoteDaemonState

    public init(
        hostLabel: String,
        hermesFound: Bool,
        hermesVersion: String?,
        statusSummary: String?,
        lastCheckedAt: Date,
        errorMessage: String?,
        preflightDiagnostic: SSHPreflightDiagnostic? = nil,
        connectionState: RemoteConnectionState = .notConfigured,
        daemonState: RemoteDaemonState = .notChecked
    ) {
        self.hostLabel = hostLabel
        self.hermesFound = hermesFound
        self.hermesVersion = hermesVersion
        self.statusSummary = statusSummary
        self.lastCheckedAt = lastCheckedAt
        self.errorMessage = errorMessage
        self.preflightDiagnostic = preflightDiagnostic
        self.connectionState = connectionState
        self.daemonState = daemonState
    }

    // MARK: - Connection states

    public enum ConnectionState: Sendable, Equatable {
        case notConfigured
        case testing
        case connected
        case failed(String)
    }

    /// Derives the high-level connection state.
    public var state: ConnectionState {
        if hostLabel == "Not configured" || hostLabel.isEmpty {
            return .notConfigured
        }
        if let error = errorMessage {
            return .failed(error)
        }
        return .connected
    }

    // MARK: - Factory

    public static let notConfigured = RemoteHermesStatusSnapshot(
        hostLabel: "Not configured",
        hermesFound: false,
        hermesVersion: nil,
        statusSummary: nil,
        lastCheckedAt: Date(),
        errorMessage: nil,
        preflightDiagnostic: nil,
        connectionState: .notConfigured,
        daemonState: .notChecked
    )
}

public enum RemoteConnectionState: String, Sendable, Equatable, Codable {
    case notConfigured
    case localValidationFailed
    case sshPreflightFailed
    case readyToVerify
    case verifying
    case heartbeatPassed
    case heartbeatFailed
    case liveChecksDisabled
}

public enum RemoteDaemonState: String, Sendable, Equatable, Codable {
    case unknown
    case notChecked
    case checking
    case running
    case stopped
    case unhealthy
    case unavailable
    case restartAvailable
    case restartBlocked
    case restartInProgress
    case restartSucceeded
    case restartFailed
}
