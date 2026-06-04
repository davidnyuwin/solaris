import Foundation

/// Live implementation of `LiveRemoteProbeRunning` that executes read-only probes
/// on a remote host via system SSH under the approved safety contract.
///
/// Safety properties:
/// 1. Evaluates live remote policy and user approval before execution.
/// 2. Validates connection parameters (host, username, identity path) to prevent shell injection.
/// 3. Enforces fixed command mappings to allowlisted enum-only commands.
/// 4. Disables standard input for all probe execution paths.
/// 5. Automatically sanitizes all command output and bounds summaries to the first line only.
/// 6. Imposes a strict 8-second execution timeout.
public final class LiveRemoteProbeRunner: LiveRemoteProbeRunning, Sendable {
    private let executor: any RemoteCommandRunning
    private let preflightService: SSHPreflightService

    public init(
        executor: any RemoteCommandRunning = RemoteSSHExecutor(),
        preflightService: SSHPreflightService = SSHPreflightService()
    ) {
        self.executor = executor
        self.preflightService = preflightService
    }

    public func run(_ request: LiveRemoteProbeRequest) async -> LiveRemoteProbeResult {
        // 1. Load policy and check runtime/compile-time validation
        let policy = LiveRemotePolicy.load()
        let userApproved = UserDefaults.standard.bool(forKey: "LiveRemotePolicyUserApproved")
        
        #if DEBUG
        let isDeveloperRemoteEnabled = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        #else
        let isDeveloperRemoteEnabled = false
        #endif

        let isValidHost = RemoteHostSettings.isValidHost(request.host)
                       && RemoteHostSettings.isValidUsername(request.username)
                       && RemoteHostSettings.isValidIdentityFilePath(request.identityPath ?? "")

        let operation: LiveRemoteOperation
        switch request.probe {
        case .findHermesBinary: operation = .findHermesBinary
        case .hermesVersion: operation = .hermesVersion
        case .hermesStatus: operation = .hermesStatus
        case .tunnelStatus: operation = .tunnelStatus
        }

        // 2. Evaluate decision
        let decision = LiveRemotePolicyEvaluator.canExecute(
            operation,
            policy: policy,
            userApproved: userApproved,
            isDeveloperRemoteEnabled: isDeveloperRemoteEnabled,
            isValidHost: isValidHost
        )

        switch decision {
        case .allowed:
            break
        case .blocked(let reason):
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .blocked,
                sanitizedSummary: blockReasonMessage(reason),
                exitCode: nil
            )
        }

        // 3. Construct host settings
        let settings = RemoteHostSettings(
            host: request.host,
            username: request.username,
            port: RemoteHostSettings.defaultPort,
            hermesCommand: "hermes",
            identityFilePath: request.identityPath ?? ""
        )

        // 4. SSH Preflight check
        if let diagnostic = await preflightService.performPreflightChecks(settings: settings) {
            if diagnostic.status == .fail {
                return LiveRemoteProbeResult(
                    probe: request.probe,
                    status: .failed,
                    sanitizedSummary: "SSH preflight failed: \(diagnostic.title)",
                    exitCode: nil
                )
            }
        }

        // 5. Map probe to RemoteHermesCommand
        let sshCommand = request.probe.remoteCommand

        // 6. Execute via RemoteSSHExecutor
        // Probes enforce a strict 8-second timeout, no stdin, and no tunnel requests.
        let result = await executor.execute(
            command: sshCommand,
            settings: settings,
            timeout: 8.0,
            stdinData: nil,
            tunnelRequest: nil
        )

        // 7. Handle outcomes and sanitize results
        if result.timedOut {
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .failed,
                sanitizedSummary: "Probe timed out.",
                exitCode: result.exitCode,
                duration: result.duration
            )
        }

        if result.exitCode != 0 {
            // For findHermesBinary, a non-zero exit code specifically means not found
            if request.probe == .findHermesBinary {
                return LiveRemoteProbeResult(
                    probe: request.probe,
                    status: .failed,
                    sanitizedSummary: "Hermes binary not found.",
                    exitCode: result.exitCode,
                    duration: result.duration
                )
            }
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .failed,
                sanitizedSummary: "Probe failed.",
                exitCode: result.exitCode,
                duration: result.duration
            )
        }

        // Custom output processing for findHermesBinary: do not leak full paths
        if request.probe == .findHermesBinary {
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .succeeded,
                sanitizedSummary: "Hermes binary found.",
                exitCode: 0,
                duration: result.duration
            )
        }

        // Extract first line of stdout and sanitize it
        let cleanStdout = OutputSanitiser.sanitise(result.stdout, isStreaming: false).text
        let firstLine = cleanStdout.components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else {
            return LiveRemoteProbeResult(
                probe: request.probe,
                status: .failed,
                sanitizedSummary: "Probe failed.",
                exitCode: result.exitCode,
                duration: result.duration
            )
        }

        return LiveRemoteProbeResult(
            probe: request.probe,
            status: .succeeded,
            sanitizedSummary: firstLine,
            exitCode: 0,
            duration: result.duration
        )
    }

    private func blockReasonMessage(_ reason: LiveRemoteBlockReason) -> String {
        switch reason {
        case .policyDisabled:
            return "Live remote execution is disabled."
        case .requiresUserApproval:
            return "User approval required to run remote checks."
        case .debugOnly:
            return "This operation requires a debug build and developer console enabled."
        case .forbidden:
            return "This operation is forbidden by the safety contract."
        case .invalidInput:
            return "Invalid host configuration."
        case .releaseBuildBlocked:
            return "This operation is disabled in this build."
        }
    }
}
