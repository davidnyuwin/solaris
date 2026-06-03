import Foundation

public final class MockRemoteCommandRunner: RemoteCommandRunning, @unchecked Sendable {
    public var shouldFail = false
    public var shouldTimeout = false
    public var exitCode: Int32 = 0
    public var customStdout: String? = nil
    public var customStderr: String? = nil
    
    public init() {}
    
    public func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?
    ) async -> RemoteSSHResult {
        let duration: TimeInterval = 0.05
        
        if shouldTimeout {
            return RemoteSSHResult(
                command: command,
                exitCode: -1,
                stdout: "",
                stderr: "Mock command timed out",
                duration: duration,
                timedOut: true
            )
        }
        
        if shouldFail {
            return RemoteSSHResult(
                command: command,
                exitCode: exitCode != 0 ? exitCode : 1,
                stdout: "",
                stderr: customStderr ?? "Mock connection failed or command error",
                duration: duration,
                timedOut: false
            )
        }
        
        let stdout: String
        if let custom = customStdout {
            stdout = custom
        } else {
            switch command {
            case .whichHermes:
                stdout = "/usr/local/bin/hermes"
            case .hermesVersion:
                stdout = "hermes-agent 1.2.3"
            case .hermesStatus:
                stdout = "Status: OK"
            case .hermesChat:
                stdout = "Mock Chat Response"
            }
        }
        
        return RemoteSSHResult(
            command: command,
            exitCode: 0,
            stdout: stdout,
            stderr: "",
            duration: duration,
            timedOut: false
        )
    }
    
    public func executeStreaming(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?
    ) -> AsyncStream<RemoteSSHStreamEvent> {
        return AsyncStream { continuation in
            if shouldTimeout {
                continuation.yield(.timedOut)
                continuation.finish()
                return
            }
            if shouldFail {
                continuation.yield(.failed(customStderr ?? "Mock connection failed or command error"))
                continuation.finish()
                return
            }
            
            let stdout: String
            if let custom = customStdout {
                stdout = custom
            } else {
                switch command {
                case .whichHermes:
                    stdout = "/usr/local/bin/hermes\n"
                case .hermesVersion:
                    stdout = "hermes-agent 1.2.3\n"
                case .hermesStatus:
                    stdout = "Status: OK\n"
                case .hermesChat:
                    stdout = "Mock Chat Streaming Response\n"
                }
            }
            
            continuation.yield(.stdout(stdout))
            continuation.yield(.completed(exitCode: 0))
            continuation.finish()
        }
    }
}
