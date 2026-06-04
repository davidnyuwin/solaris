import Foundation

// MARK: - Live Remote Probe Types

/// A read-only probe that can be run against a remote Hermes host.
/// Each case maps to a fixed argument array — no free-form commands.
public enum LiveRemoteProbe: String, Codable, Equatable, Sendable, CaseIterable {
    /// Check if the Hermes binary exists on the remote host (`which hermes`).
    /// Output is summarized to a boolean — the full path is never stored or displayed.
    case findHermesBinary

    /// Read the Hermes version string (`hermes --version`).
    /// Only the first line of stdout is captured.
    case hermesVersion

    /// Read the Hermes daemon status summary (`hermes status`).
    /// Only the first line of stdout is captured.
    case hermesStatus

    /// Read the tunnel status (`hermes tunnel-status`).
    /// This is a query-only subcommand — it cannot start or stop tunnels.
    case tunnelStatus

    /// The `RemoteHermesCommand` equivalent for this probe (for argument mapping).
    public var remoteCommand: RemoteHermesCommand {
        switch self {
        case .findHermesBinary: return .whichHermes
        case .hermesVersion: return .hermesVersion
        case .hermesStatus: return .hermesStatus
        case .tunnelStatus: return .tunnelStatus
        }
    }
}

// MARK: - Probe Request

/// A request to run a read-only probe against a remote host.
/// Stores only connection metadata — no secrets, no credentials, no private keys.
public struct LiveRemoteProbeRequest: Codable, Equatable, Sendable {
    /// Remote host label (display only, not used for SSH connection).
    public let host: String

    /// SSH username for the remote host.
    public let username: String

    /// Optional path to the SSH identity file (not the key content).
    public let identityPath: String?

    /// The probe to run.
    public let probe: LiveRemoteProbe

    public init(host: String, username: String, identityPath: String?, probe: LiveRemoteProbe) {
        self.host = host
        self.username = username
        self.identityPath = identityPath
        self.probe = probe
    }
}

// MARK: - Probe Result Status

/// The status of a completed (or attempted) read-only probe.
public enum LiveRemoteProbeStatus: String, Codable, Equatable, Sendable {
    /// Probe has not been run yet.
    case notRun
    /// Probe was permitted by policy and user approval.
    case allowed
    /// Probe was blocked by policy or validation.
    case blocked
    /// Probe is currently executing.
    case running
    /// Probe completed successfully.
    case succeeded
    /// Probe failed (SSH error, timeout, Hermes not found, etc.).
    case failed
}

// MARK: - Probe Result

/// The result of a read-only probe execution.
/// Stores sanitized summaries only — no raw stdout/stderr, no secrets.
public struct LiveRemoteProbeResult: Codable, Equatable, Sendable {
    /// Which probe was run.
    public let probe: LiveRemoteProbe

    /// The outcome status.
    public let status: LiveRemoteProbeStatus

    /// A sanitized, human-readable summary of the result.
    /// For `findHermesBinary`: "Hermes binary found" or "Hermes binary not found".
    /// For `hermesVersion`: The version string (first line, sanitized).
    /// For `hermesStatus`: The status summary (first line, sanitized).
    /// For `tunnelStatus`: The tunnel status text (first line, sanitized).
    /// Always passes through `OutputSanitiser` before storage.
    public let sanitizedSummary: String

    /// The exit code from the remote command, if the probe was executed.
    public let exitCode: Int32?

    /// Duration of the probe execution, if the probe was executed.
    public let duration: TimeInterval?

    public init(
        probe: LiveRemoteProbe,
        status: LiveRemoteProbeStatus,
        sanitizedSummary: String,
        exitCode: Int32? = nil,
        duration: TimeInterval? = nil
    ) {
        self.probe = probe
        self.status = status
        self.sanitizedSummary = OutputSanitiser.sanitise(sanitizedSummary, isStreaming: false).text
        self.exitCode = exitCode
        self.duration = duration
    }
}
