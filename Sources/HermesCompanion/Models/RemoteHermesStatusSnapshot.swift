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

    /// Structured remote background tunnel state.
    public let tunnelState: RemoteTunnelState

    /// Bounded robustness/retry state.
    public let robustnessState: RemoteConnectionRobustnessState

    public init(
        hostLabel: String,
        hermesFound: Bool,
        hermesVersion: String?,
        statusSummary: String?,
        lastCheckedAt: Date,
        errorMessage: String?,
        preflightDiagnostic: SSHPreflightDiagnostic? = nil,
        connectionState: RemoteConnectionState = .notConfigured,
        daemonState: RemoteDaemonState = .notChecked,
        tunnelState: RemoteTunnelState = .notStarted,
        robustnessState: RemoteConnectionRobustnessState = .stable
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
        self.tunnelState = tunnelState
        self.robustnessState = robustnessState
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
        daemonState: .notChecked,
        tunnelState: .notConfigured,
        robustnessState: .stable
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

public enum RemoteTunnelState: String, Sendable, Equatable, Codable {
    case notConfigured
    case notStarted
    case preparing
    case starting
    case active
    case degraded
    case failed
    case blocked
    case stopping
    case stopped
}

public enum RemoteConnectionRobustnessState: String, Sendable, Equatable, Codable {
    case stable
    case degraded
    case retryAvailable
    case retrying
    case retryExhausted
    case blocked
}

public enum RemoteTunnelPurpose: String, Sendable, Equatable, Codable {
    case runtimeAccess
    case diagnostics
}

public struct RemoteTunnelRequest: Sendable, Equatable, Codable {
    public let localPort: Int
    public let remoteHost: String
    public let remotePort: Int
    public let purpose: RemoteTunnelPurpose

    public init(localPort: Int, remoteHost: String, remotePort: Int, purpose: RemoteTunnelPurpose) {
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.purpose = purpose
    }
}
