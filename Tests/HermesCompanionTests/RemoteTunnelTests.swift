import XCTest
@testable import HermesCompanion

final class RemoteTunnelTests: XCTestCase {
    
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
    
    func testTunnelCommandArguments() {
        // Default request arguments
        let cmd = RemoteHermesCommand.tunnelStart
        let defaultArgs = cmd.remoteArguments(hermesCommandBase: "hermes", tunnelRequest: nil)
        XCTAssertEqual(defaultArgs, ["-N", "-L", "9119:127.0.0.1:9119"])
        
        // Custom request arguments
        let req = RemoteTunnelRequest(localPort: 8080, remoteHost: "KNOWHERE.local", remotePort: 9090, purpose: .runtimeAccess)
        let customArgs = cmd.remoteArguments(hermesCommandBase: "hermes", tunnelRequest: req)
        XCTAssertEqual(customArgs, ["-N", "-L", "8080:KNOWHERE.local:9090"])
    }
    
    @MainActor
    func testTunnelSafetyPreconditions() async throws {
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
        let request = RemoteTunnelRequest(localPort: 9119, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        
        // 1. Unconnected state: starting a tunnel should be blocked (fails safety gate)
        await vm.startRemoteTunnel(settings: settings, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .notStarted) // Preserved
        
        // 2. Connected state: should allow tunnel start
        await vm.testRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        
        await vm.startRemoteTunnel(settings: settings, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .active)
    }
    
    @MainActor
    func testTunnelPortValidation() async throws {
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
        await vm.testRemoteConnection(settings: settings)
        
        // Invalid local port <= 1024 (privileged)
        let invalidLocalRequest = RemoteTunnelRequest(localPort: 80, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        await vm.startRemoteTunnel(settings: settings, request: invalidLocalRequest)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Invalid tunnel port configuration.")
        
        // Invalid local port > 65535
        let invalidLocalRequest2 = RemoteTunnelRequest(localPort: 70000, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        await vm.startRemoteTunnel(settings: settings, request: invalidLocalRequest2)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        
        // Invalid remote port > 65535
        let invalidRemoteRequest = RemoteTunnelRequest(localPort: 9119, remoteHost: "127.0.0.1", remotePort: 70000, purpose: .runtimeAccess)
        await vm.startRemoteTunnel(settings: settings, request: invalidRemoteRequest)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
    }
    
    @MainActor
    func testMockTunnelLifecycleScenarios() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Mock a passing preflight
        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        let request = RemoteTunnelRequest(localPort: 9119, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        
        // 1. Success scenario
        let settingsSuccess = RemoteHostSettings(host: "success.local")
        await vm.testRemoteConnection(settings: settingsSuccess)
        await vm.startRemoteTunnel(settings: settingsSuccess, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .active)
        XCTAssertNil(vm.remoteHostStatus.errorMessage)
        
        // Stop success
        await vm.stopRemoteTunnel(settings: settingsSuccess)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .stopped)
        
        // 2. Failure scenario
        let settingsFail = RemoteHostSettings(host: "tunnel-fail.local")
        await vm.testRemoteConnection(settings: settingsFail)
        await vm.startRemoteTunnel(settings: settingsFail, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Remote tunnel start failed.")
        
        // 3. Timeout scenario
        let settingsTimeout = RemoteHostSettings(host: "tunnel-timeout.local")
        await vm.testRemoteConnection(settings: settingsTimeout)
        await vm.startRemoteTunnel(settings: settingsTimeout, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Mock command timed out")
        
        // 4. Degraded scenario
        let settingsDegraded = RemoteHostSettings(host: "tunnel-degraded.local")
        await vm.testRemoteConnection(settings: settingsDegraded)
        await vm.startRemoteTunnel(settings: settingsDegraded, request: request)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .degraded)
        
        // Stop failure scenario
        let settingsStopFail = RemoteHostSettings(host: "tunnel-stop-fail.local")
        // Manually prime the state to active
        vm.remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settingsStopFail.displayLabel,
            hermesFound: true,
            hermesVersion: "1.0",
            statusSummary: "OK",
            lastCheckedAt: Date(),
            errorMessage: nil,
            preflightDiagnostic: nil,
            connectionState: .heartbeatPassed,
            daemonState: .running,
            tunnelState: .active
        )
        await vm.stopRemoteTunnel(settings: settingsStopFail)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Remote tunnel stop failed.")
    }
    
    @MainActor
    func testRobustnessRetryConnectionFlow() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Mock a passing preflight
        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)
        
        // 1. Initial state
        let settings = RemoteHostSettings(host: "fail.local") // This host will fail
        await vm.testRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryAvailable)
        XCTAssertEqual(vm.retryCount, 1)
        
        // 2. Second retry
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryAvailable)
        XCTAssertEqual(vm.retryCount, 2)
        
        // 3. Third retry (exhausts retries)
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryExhausted)
        XCTAssertEqual(vm.retryCount, 3)
        
        // 4. Fourth attempt blocked/exhausted
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryExhausted)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Maximum retry attempts exhausted.")
        XCTAssertEqual(vm.retryCount, 3)
        
        // 5. Successful retry resets counter
        let successSettings = RemoteHostSettings(host: "success.local")
        // Prime to failed first
        vm.remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: successSettings.displayLabel,
            hermesFound: true,
            hermesVersion: "1.0",
            statusSummary: "OK",
            lastCheckedAt: Date(),
            errorMessage: "Mock failed connection",
            preflightDiagnostic: nil,
            connectionState: .heartbeatFailed,
            daemonState: .running,
            tunnelState: .notStarted,
            robustnessState: .retryAvailable
        )
        vm.retryCount = 1
        
        await vm.retryRemoteConnection(settings: successSettings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .stable)
        XCTAssertEqual(vm.retryCount, 0)
    }
    
    func testStateCodables() throws {
        let tunnelStates: [RemoteTunnelState] = [
            .notConfigured, .notStarted, .preparing, .starting, .active,
            .degraded, .failed, .blocked, .stopping, .stopped
        ]
        for state in tunnelStates {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RemoteTunnelState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
        
        let robustnessStates: [RemoteConnectionRobustnessState] = [
            .stable, .degraded, .retryAvailable, .retrying, .retryExhausted, .blocked
        ]
        for state in robustnessStates {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RemoteConnectionRobustnessState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
        
        let purposes: [RemoteTunnelPurpose] = [
            .runtimeAccess, .diagnostics
        ]
        for p in purposes {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(RemoteTunnelPurpose.self, from: data)
            XCTAssertEqual(p, decoded)
        }
    }
}
