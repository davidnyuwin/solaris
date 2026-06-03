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
        stdinData: Data?,
        tunnelRequest: RemoteTunnelRequest?
    ) async -> RemoteSSHResult {
        let duration: TimeInterval = 0.05
        
        let localTimeout = shouldTimeout || 
                           (command == .hermesStatus && settings.host == "daemon-timeout.local") ||
                           (command == .tunnelStart && settings.host == "tunnel-timeout.local") ||
                           (command == .tunnelStatus && settings.host == "tunnel-timeout.local")
        if localTimeout {
            return RemoteSSHResult(
                command: command,
                exitCode: -1,
                stdout: "",
                stderr: "Mock command timed out",
                duration: duration,
                timedOut: true
            )
        }
        
        let localFail = shouldFail || 
                        (command == .hermesStatus && settings.host == "daemon-unavailable.local") ||
                        (command == .hermesRestart && settings.host == "restart-fail.local") ||
                        (command == .tunnelStart && settings.host == "tunnel-fail.local") ||
                        (command == .tunnelStop && settings.host == "tunnel-stop-fail.local")
        if localFail {
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
                if settings.host == "daemon-stopped.local" {
                    stdout = "Status: STOPPED"
                } else if settings.host == "daemon-unhealthy.local" {
                    stdout = "Status: UNHEALTHY"
                } else {
                    stdout = "Status: OK"
                }
            case .hermesChat:
                stdout = "Mock Chat Response"
            case .hermesRestart:
                stdout = "Status: OK"
            case .tunnelStart:
                if settings.host == "tunnel-active.local" {
                    stdout = "Tunnel already active"
                } else {
                    stdout = "Tunnel started successfully"
                }
            case .tunnelStop:
                stdout = "Tunnel stopped successfully"
            case .tunnelStatus:
                if settings.host == "tunnel-degraded.local" {
                    stdout = "Status: Degraded"
                } else {
                    stdout = "Status: Active"
                }
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
        stdinData: Data?,
        tunnelRequest: RemoteTunnelRequest?
    ) -> AsyncStream<RemoteSSHStreamEvent> {
        return AsyncStream { continuation in
            let localTimeout = shouldTimeout || 
                               (command == .hermesStatus && settings.host == "daemon-timeout.local") ||
                               (command == .tunnelStart && settings.host == "tunnel-timeout.local") ||
                               (command == .tunnelStatus && settings.host == "tunnel-timeout.local")
            if localTimeout {
                continuation.yield(.timedOut)
                continuation.finish()
                return
            }
            
            let localFail = shouldFail || 
                            (command == .hermesStatus && settings.host == "daemon-unavailable.local") ||
                            (command == .hermesRestart && settings.host == "restart-fail.local") ||
                            (command == .tunnelStart && settings.host == "tunnel-fail.local") ||
                            (command == .tunnelStop && settings.host == "tunnel-stop-fail.local")
            if localFail {
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
                    if settings.host == "daemon-stopped.local" {
                        stdout = "Status: STOPPED\n"
                    } else if settings.host == "daemon-unhealthy.local" {
                        stdout = "Status: UNHEALTHY\n"
                    } else {
                        stdout = "Status: OK\n"
                    }
                case .hermesChat:
                    stdout = "Mock Chat Streaming Response\n"
                case .hermesRestart:
                    stdout = "Status: OK\n"
                case .tunnelStart:
                    if settings.host == "tunnel-active.local" {
                        stdout = "Tunnel already active\n"
                    } else {
                        stdout = "Tunnel started successfully\n"
                    }
                case .tunnelStop:
                    stdout = "Tunnel stopped successfully\n"
                case .tunnelStatus:
                    if settings.host == "tunnel-degraded.local" {
                        stdout = "Status: Degraded\n"
                    } else {
                        stdout = "Status: Active\n"
                    }
                }
            }
            
            continuation.yield(.stdout(stdout))
            continuation.yield(.completed(exitCode: 0))
            continuation.finish()
        }
    }
}
