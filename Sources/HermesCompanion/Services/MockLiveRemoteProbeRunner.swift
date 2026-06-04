import Foundation

// MARK: - Live Remote Probe Running Protocol

/// Protocol for running read-only probes against a remote host.
/// The mock implementation is used in this batch; a live implementation
/// may be added in a future batch after all safety gates are verified.
public protocol LiveRemoteProbeRunning: Sendable {
    /// Run a read-only probe against the remote host specified in the request.
    /// - Parameter request: The probe request with host and probe type.
    /// - Returns: A sanitized probe result.
    func run(_ request: LiveRemoteProbeRequest) async -> LiveRemoteProbeResult
}

// MARK: - Mock Probe Runner

/// Mock implementation of `LiveRemoteProbeRunning` for testing and UI development.
/// Simulates various probe outcomes without any real SSH or network activity.
public final class MockLiveRemoteProbeRunner: LiveRemoteProbeRunning, @unchecked Sendable {

    /// Configuration for controlling mock behaviour.
    public var mockHermesFound: Bool = true
    public var mockVersion: String = "hermes 0.9.0"
    public var mockStatus: String = "hermes is running (uptime: 2h30m)"
    public var mockTunnelStatus: String = "No active tunnels"
    public var shouldFail: Bool = false
    public var shouldTimeout: Bool = false
    public var customErrorMessage: String?

    public init() {}

    public func run(_ request: LiveRemoteProbeRequest) async -> LiveRemoteProbeResult {
        // Simulate a small delay to mimic real probe latency
        let delay: UInt64 = shouldTimeout ? 8_000_000_000 : 100_000_000
        try? await Task.sleep(nanoseconds: delay)

        if shouldTimeout {
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .failed,
                sanitizedSummary: "Probe timed out. The host may be slow or unreachable.",
                exitCode: nil
            )
        }

        if shouldFail {
            let msg = customErrorMessage ?? "Remote probe failed."
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .failed,
                sanitizedSummary: msg,
                exitCode: 1
            )
        }

        switch request.probe {
        case .findHermesBinary:
            if mockHermesFound {
                return LiveRemoteProbeResult(
                    probe: .findHermesBinary,
                    status: .succeeded,
                    sanitizedSummary: "Hermes binary found",
                    exitCode: 0
                )
            } else {
                return LiveRemoteProbeResult(
                    probe: .findHermesBinary,
                    status: .failed,
                    sanitizedSummary: "Hermes was not found on the remote host. Install Hermes or update the command path.",
                    exitCode: 1
                )
            }

        case .hermesVersion:
            return LiveRemoteProbeResult(
                probe: .hermesVersion,
                status: .succeeded,
                sanitizedSummary: mockVersion,
                exitCode: 0
            )

        case .hermesStatus:
            return LiveRemoteProbeResult(
                probe: .hermesStatus,
                status: .succeeded,
                sanitizedSummary: mockStatus,
                exitCode: 0
            )

        case .tunnelStatus:
            return LiveRemoteProbeResult(
                probe: .tunnelStatus,
                status: .succeeded,
                sanitizedSummary: mockTunnelStatus,
                exitCode: 0
            )
        }
    }
}
