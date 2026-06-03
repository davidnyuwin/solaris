import XCTest
@testable import HermesCompanion

final class RemoteDaemonTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    private func createMockSSHAdd(exitCode: Int, stdout: String, stderr: String) throws -> String {
        let scriptURL = tempDir.appendingPathComponent("mock_ssh_add.sh")
        let content = """
        #!/bin/sh
        if [ -n "\(stdout)" ]; then
            echo "\(stdout)"
        fi
        if [ -n "\(stderr)" ]; then
            echo "\(stderr)" >&2
        fi
        exit \(exitCode)
        """
        try content.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", scriptURL.path]
        try process.run()
        process.waitUntilExit()
        
        return scriptURL.path
    }
    
    @MainActor
    func testDaemonStateTransitionsOnTestConnection() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Mock a passing preflight
        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        // 1. Running daemon
        let runningSettings = RemoteHostSettings(host: "success.local")
        await vm.testRemoteConnection(settings: runningSettings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .running)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        
        // 2. Stopped daemon
        let stoppedSettings = RemoteHostSettings(host: "daemon-stopped.local")
        await vm.testRemoteConnection(settings: stoppedSettings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .stopped)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        
        // 3. Unhealthy daemon
        let unhealthySettings = RemoteHostSettings(host: "daemon-unhealthy.local")
        await vm.testRemoteConnection(settings: unhealthySettings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .unhealthy)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        
        // 4. Unavailable daemon
        let unavailableSettings = RemoteHostSettings(host: "daemon-unavailable.local")
        await vm.testRemoteConnection(settings: unavailableSettings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .unavailable)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        
        // 5. Timeout daemon
        let timeoutSettings = RemoteHostSettings(host: "daemon-timeout.local")
        await vm.testRemoteConnection(settings: timeoutSettings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .unavailable)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
    }
    
    @MainActor
    func testDaemonRestartFlowSuccess() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Mock a passing preflight
        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        let settings = RemoteHostSettings(host: "success.local")
        
        // Prime the state to healthy/stopped first
        await vm.testRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .running)
        
        // Execute restart
        await vm.restartRemoteDaemon(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .restartSucceeded)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        XCTAssertNil(vm.remoteHostStatus.errorMessage)
    }
    
    @MainActor
    func testDaemonRestartFlowFailure() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Mock a passing preflight
        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        let settings = RemoteHostSettings(host: "restart-fail.local")
        
        // Prime the connection
        await vm.testRemoteConnection(settings: settings)
        
        // Execute restart
        await vm.restartRemoteDaemon(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.daemonState, .restartFailed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Remote daemon restart failed.")
    }
    
    @MainActor
    func testDaemonRestartFlowSafetyPreconditions() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // 1. Preflight failure: missing key file path should block restart
        let mockPath = try createMockSSHAdd(exitCode: 1, stdout: "", stderr: "ssh-agent unreachable")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        let settings = RemoteHostSettings(host: "success.local", identityFilePath: "/nonexistent/key")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .sshPreflightFailed)
        
        // Attempt restart — should be blocked (no state change to restartInProgress)
        await vm.restartRemoteDaemon(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .sshPreflightFailed)
        XCTAssertNotEqual(vm.remoteHostStatus.daemonState, .restartInProgress)
    }
    
    func testDaemonStateCodable() throws {
        let states: [RemoteDaemonState] = [
            .unknown, .notChecked, .checking, .running, .stopped,
            .unhealthy, .unavailable, .restartAvailable, .restartBlocked,
            .restartInProgress, .restartSucceeded, .restartFailed
        ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RemoteDaemonState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
    }
}
