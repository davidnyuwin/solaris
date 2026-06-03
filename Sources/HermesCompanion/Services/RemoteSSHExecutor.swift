import Foundation

// MARK: - Allowlisted Remote Commands

/// Read-only Hermes commands that Solaris is allowed to run on the remote host.
/// Every command is explicitly enumerated — no free-form shell access.
public enum RemoteHermesCommand: String, Sendable, CaseIterable {
    case whichHermes = "which"
    case hermesVersion = "version"
    case hermesStatus = "status"
    case hermesChat = "chat"

    /// The actual argument array sent over SSH for this command.
    /// `hermesCommandBase` is the verified base command (default: "hermes").
    public func remoteArguments(hermesCommandBase: String) -> [String] {
        switch self {
        case .whichHermes:
            return ["which", verifiedBase(hermesCommandBase)]
        case .hermesVersion:
            return [verifiedBase(hermesCommandBase), "--version"]
        case .hermesStatus:
            return [verifiedBase(hermesCommandBase), "status"]
        case .hermesChat:
            return [verifiedBase(hermesCommandBase), "chat", "-q", "-", "-Q"]
        }
    }

    private func verifiedBase(_ base: String) -> String {
        // Fallback safety sanitisation
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "hermes" }
        let forbidden = CharacterSet(charactersIn: " ;|&`$<>()[]{}#'\"!\\")
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else {
            return "hermes"
        }
        return trimmed
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

// MARK: - SSH Stream Events

public enum RemoteSSHStreamEvent: Sendable, Equatable {
    case stdout(String)
    case stderr(String)
    case status(String)
    case completed(exitCode: Int32)
    case failed(String)
    case timedOut
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

    private let sshPath: String
    private let defaultTimeout: TimeInterval = 8

    public init() {
        self.sshPath = "/usr/bin/ssh"
    }

    #if DEBUG
    internal init(sshPathOverride: String) {
        self.sshPath = sshPathOverride
    }
    #endif

    /// Run an allowlisted command on the remote host with optional stdin data.
    /// - Parameters:
    ///   - command: The `RemoteHermesCommand` to execute.
    ///   - settings: Connection settings (host, username, port, hermesCommand).
    ///   - timeout: Per-command timeout in seconds (default 8).
    ///   - stdinData: Optional standard input data payload (max 16KB).
    /// - Returns: A `RemoteSSHResult` with stdout, stderr, exit code, and timing.
    public func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval = 8,
        stdinData: Data? = nil
    ) async -> RemoteSSHResult {
        let startTime = Date()

        if let stdin = stdinData, stdin.count > 16384 {
            return RemoteSSHResult(
                command: command,
                exitCode: -1,
                stdout: "",
                stderr: "Standard input payload exceeds maximum allowed size of 16KB.",
                duration: 0,
                timedOut: false
            )
        }

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

        return await runProcess(
            arguments: sshArgs,
            command: command,
            timeout: timeout,
            startTime: startTime,
            stdinData: stdinData
        )
    }

    /// Run an allowlisted command on the remote host and stream the results back.
    /// - Parameters:
    ///   - command: The `RemoteHermesCommand` to execute.
    ///   - settings: Connection settings (host, username, port, hermesCommand).
    ///   - timeout: Per-command timeout in seconds (default 30).
    ///   - stdinData: Optional standard input data payload (max 16KB).
    /// - Returns: An `AsyncStream` emitting `RemoteSSHStreamEvent`.
    public func executeStreaming(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval = 30,
        stdinData: Data? = nil
    ) -> AsyncStream<RemoteSSHStreamEvent> {
        return AsyncStream { continuation in
            guard settings.isValid else {
                continuation.yield(.failed("Remote host is not configured."))
                continuation.finish()
                return
            }
            
            if let stdin = stdinData, stdin.count > 16384 {
                continuation.yield(.failed("Standard input payload exceeds maximum allowed size of 16KB."))
                continuation.finish()
                return
            }
            
            let hermesBase = sanitiseHermesCommand(settings.hermesCommand)
            let remoteArgs = command.remoteArguments(hermesCommandBase: hermesBase)
            
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
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = sshArgs
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            let stdinPipe = Pipe()
            if stdinData != nil {
                process.standardInput = stdinPipe
            }
            
            final class TimeoutFlag: @unchecked Sendable {
                private(set) var didTimeout = false
                func set() { didTimeout = true }
            }
            let timeoutFlag = TimeoutFlag()
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    timeoutFlag.set()
                    try? stdoutPipe.fileHandleForReading.close()
                    try? stderrPipe.fileHandleForReading.close()
                    process.terminate()
                }
            }
            
            let stdoutSanitiser = StreamingOutputSanitiser()
            let stderrSanitiser = StreamingOutputSanitiser()
            
            let stdoutReadingTask = Task {
                let stdoutHandle = stdoutPipe.fileHandleForReading
                while !Task.isCancelled {
                    do {
                        if let chunk = try stdoutHandle.read(upToCount: 4096), !chunk.isEmpty {
                            let incrementalText = stdoutSanitiser.appendAndSanitise(chunk)
                            if !incrementalText.isEmpty {
                                continuation.yield(.stdout(incrementalText))
                            }
                        } else {
                            break
                        }
                    } catch {
                        break
                    }
                }
            }
            
            let stderrReadingTask = Task {
                let stderrHandle = stderrPipe.fileHandleForReading
                while !Task.isCancelled {
                    do {
                        if let chunk = try stderrHandle.read(upToCount: 4096), !chunk.isEmpty {
                            let incrementalText = stderrSanitiser.appendAndSanitise(chunk)
                            if !incrementalText.isEmpty {
                                continuation.yield(.stderr(incrementalText))
                            }
                        } else {
                            break
                        }
                    } catch {
                        break
                    }
                }
            }
            
            process.terminationHandler = { proc in
                timeoutTask.cancel()
                
                Task {
                    _ = await stdoutReadingTask.result
                    _ = await stderrReadingTask.result
                    
                    if stdinData != nil {
                        try? stdinPipe.fileHandleForWriting.close()
                    }
                    
                    if timeoutFlag.didTimeout {
                        continuation.yield(.timedOut)
                    } else if proc.terminationStatus != 0 {
                        continuation.yield(.completed(exitCode: proc.terminationStatus))
                    } else {
                        continuation.yield(.completed(exitCode: 0))
                    }
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { [weak process] _ in
                timeoutTask.cancel()
                stdoutReadingTask.cancel()
                stderrReadingTask.cancel()
                try? stdoutPipe.fileHandleForReading.close()
                try? stderrPipe.fileHandleForReading.close()
                if let proc = process, proc.isRunning {
                    proc.terminate()
                }
                if stdinData != nil {
                    try? stdinPipe.fileHandleForWriting.close()
                }
            }
            
            do {
                try process.run()
                
                if let stdinData = stdinData {
                    do {
                        try stdinPipe.fileHandleForWriting.write(contentsOf: stdinData)
                    } catch {
                        try? stdinPipe.fileHandleForWriting.close()
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    try? stdinPipe.fileHandleForWriting.close()
                }
            } catch {
                timeoutTask.cancel()
                stdoutReadingTask.cancel()
                stderrReadingTask.cancel()
                if stdinData != nil {
                    try? stdinPipe.fileHandleForWriting.close()
                }
                continuation.yield(.failed(error.localizedDescription))
                continuation.finish()
            }
        }
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
        startTime: Date,
        stdinData: Data? = nil
    ) async -> RemoteSSHResult {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdinPipe = Pipe()
            if stdinData != nil {
                process.standardInput = stdinPipe
            }

            // Sendable flag so the timeout task and termination handler share
            // the timed-out state without a data race.
            final class TimeoutFlag: @unchecked Sendable {
                private(set) var didTimeout = false
                func set() { didTimeout = true }
            }
            let timeoutFlag = TimeoutFlag()

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    timeoutFlag.set()
                    process.terminate()
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()

                if stdinData != nil {
                    try? stdinPipe.fileHandleForWriting.close()
                }

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
                    timedOut: timeoutFlag.didTimeout
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()

                if let stdinData = stdinData {
                    do {
                        try stdinPipe.fileHandleForWriting.write(contentsOf: stdinData)
                    } catch {
                        try? stdinPipe.fileHandleForWriting.close()
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    try? stdinPipe.fileHandleForWriting.close()
                }
            } catch {
                timeoutTask.cancel()
                if stdinData != nil {
                    try? stdinPipe.fileHandleForWriting.close()
                }
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
