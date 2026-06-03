import Foundation

public protocol RemoteCommandRunning: Sendable {
    func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?,
        tunnelRequest: RemoteTunnelRequest?
    ) async -> RemoteSSHResult

    func executeStreaming(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?,
        tunnelRequest: RemoteTunnelRequest?
    ) -> AsyncStream<RemoteSSHStreamEvent>
}

public extension RemoteCommandRunning {
    func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval = 8,
        stdinData: Data? = nil,
        tunnelRequest: RemoteTunnelRequest? = nil
    ) async -> RemoteSSHResult {
        await execute(command: command, settings: settings, timeout: timeout, stdinData: stdinData, tunnelRequest: tunnelRequest)
    }

    func executeStreaming(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval = 30,
        stdinData: Data? = nil,
        tunnelRequest: RemoteTunnelRequest? = nil
    ) -> AsyncStream<RemoteSSHStreamEvent> {
        executeStreaming(command: command, settings: settings, timeout: timeout, stdinData: stdinData, tunnelRequest: tunnelRequest)
    }
}
