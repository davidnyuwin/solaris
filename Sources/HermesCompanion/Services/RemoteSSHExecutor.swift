import Foundation

// MARK: - Allowlisted Remote Commands

/// Read-only Hermes commands that Solaris is allowed to run on the remote host.
/// Every command is explicitly enumerated — no free-form shell access.
public enum RemoteHermesCommand: String, Sendable, CaseIterable {
    case whichHermes = "which"
    case hermesVersion = "version"
    case hermesStatus = "status"

    /// The actual argument array sent over SSH for this command.
    /// `hermesCommandBase` is the verified base command (default: "hermes").
    public func remoteArguments(hermesCommandBase: String) -> [String] {
        switch self {
        case .whichHermes:
            return ["which", hermesCommandBase]
        case .hermesVersion:
            return [hermesCommandBase, "--version"]
        case .hermesStatus:
            return [hermesCommandBase, "status"]
        }
    }
}

// MARK: - SSH Command Result

public struct RemoteSSHResult: Sendable {
    public let command: RemoteHermesCommand
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let duration: TimeInterval
    public let timedOut: Bool
}

// MARK: - SSH Executor

/// Executes allowlisted read-only Hermes commands on a remote host via
/// system SSH (`/usr/bin/ssh`).  Never uses shell interpretation.
///
/// Safety properties:
/// - Fixed executable path `/usr/bin/ssh` — never a shell.
/// - Command allowlist enforced at the enum level.
/// - Custom `hermesCommandBase` is sanitised for shell metacharacters.
/// - `BatchMode=yes` prevents password prompting (relies on ssh-agent).
public final class RemoteSSHExecutor: Sendable {

    public enum ExecutorError: Error, LocalizedError, Equatable {
        case invalidSettings
        case commandNotAllowed
        case executionFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case .invalidSettings:
                return "Remote host is not configured."
            case .commandNotAllowed:
                return "Command is not in the allowed list."
            case .executionFailed(let reason):
                return reason
            case .timedOut:
                return "SSH command timed out."
            }
        }
    }

    private let sshPath = "/usr/bin/ssh"
    private let defaultTimeout: TimeInterval = 8

    public init() {}

    /// Run an allowlisted command on the remote host.
    /// - Parameters:
    ///   - command: The `RemoteHermesCommand` to execute.
    ///   - settings: Connection settings (host, username, port, hermesCommand).
    ///   - timeout: Per-command timeout in seconds (default 8).
    /// - Returns: A `RemoteSSHResult` with stdout, stderr, exit code, and timing.
    public func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval = 8
    ) async -> RemoteSSHResult {
        let startTime = Date()

        guard settings.isValid else {
            return RemoteSSHResult(
                command: command,
                exitCode: -1,
                stdout: "",
                stderr: "",
                duration: 0,
                timedOut: false
            )
        }

        let hermesBase = sanitiseHermesCommand(settings.hermesCommand)
        let remoteArgs = command.remoteArguments(hermesCommandBase: hermesBase)

        // Build the SSH argument list.
        var sshArgs: [String] = []
        sshArgs.append("-p")
        sshArgs.append("\(settings.port)")
        sshArgs.append("-o")
        sshArgs.append("BatchMode=yes")
        sshArgs.append("-o")
        sshArgs.append("ConnectTimeout=5")
        sshArgs.append("-o")
        sshArgs.append("StrictHostKeyChecking=accept-new")
        sshArgs.append(settings.userAtHost)
        sshArgs.append(contentsOf: remoteArgs)

        return await runProcess(arguments: sshArgs, command: command, timeout: timeout, startTime: startTime)
    }

    // MARK: - Private

    /// Validates that the custom hermes command base contains no shell
    /// metacharacters.  Rejects spaces, semicolons, pipes, etc.
    private func sanitiseHermesCommand(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "hermes" }

        let forbidden = CharacterSet(charactersIn: " ;|&`$<>()[]{}#'\"!\\")
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else {
            return "hermes"
        }
        return trimmed
    }

    private func runProcess(
        arguments: [String],
        command: RemoteHermesCommand,
        timeout: TimeInterval,
        startTime: Date
    ) async -> RemoteSSHResult {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()

                let duration = Date().timeIntervalSince(startTime)
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                let result = RemoteSSHResult(
                    command: command,
                    exitCode: proc.terminationStatus,
                    stdout: stdout,
                    stderr: stderr,
                    duration: duration,
                    timedOut: !timeoutTask.isCancelled
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(returning: RemoteSSHResult(
                    command: command,
                    exitCode: -1,
                    stdout: "",
                    stderr: error.localizedDescription,
                    duration: Date().timeIntervalSince(startTime),
                    timedOut: false
                ))
            }
        }
    }
}
