import Foundation

public protocol RemoteCommandRunning: Sendable {
    func execute(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?
    ) async -> RemoteSSHResult

    func executeStreaming(
        command: RemoteHermesCommand,
        settings: RemoteHostSettings,
        timeout: TimeInterval,
        stdinData: Data?
    ) -> AsyncStream<RemoteSSHStreamEvent>
}
