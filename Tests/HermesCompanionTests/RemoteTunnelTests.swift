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
        vm.remoteHostStatus = RemoteHermesStatusSnapshot(
            hostLabel: settings.displayLabel,
            hermesFound: false,
            hermesVersion: nil,
            statusSummary: nil,
            lastCheckedAt: Date(),
            errorMessage: nil,
            connectionState: .notConfigured,
            tunnelState: .notStarted
        )
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
        XCTAssertEqual(vm.retryCount, 0)
        
        // 2. First retry
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryAvailable)
        XCTAssertEqual(vm.retryCount, 1)
        
        // 3. Second retry
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryAvailable)
        XCTAssertEqual(vm.retryCount, 2)
        
        // 4. Third retry (exhausts retries)
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryExhausted)
        XCTAssertEqual(vm.retryCount, 3)
        
        // 5. Fourth attempt blocked/exhausted
        await vm.retryRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.robustnessState, .retryExhausted)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Maximum retry attempts exhausted.")
        XCTAssertEqual(vm.retryCount, 3)
        
        // 6. Successful retry resets counter
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

    // MARK: - Phase 6B N5: RemoteTunnelRequest host and port validation

    func testRemoteTunnelRequestValidPort() {
        XCTAssertTrue(RemoteTunnelRequest.isValidPort(1))
        XCTAssertTrue(RemoteTunnelRequest.isValidPort(22))
        XCTAssertTrue(RemoteTunnelRequest.isValidPort(9119))
        XCTAssertTrue(RemoteTunnelRequest.isValidPort(65535))
        XCTAssertFalse(RemoteTunnelRequest.isValidPort(0))
        XCTAssertFalse(RemoteTunnelRequest.isValidPort(-1))
        XCTAssertFalse(RemoteTunnelRequest.isValidPort(65536))
        XCTAssertFalse(RemoteTunnelRequest.isValidPort(99999))
    }

    func testRemoteTunnelRequestValidRemoteHost_acceptsDNSNames() {
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("127.0.0.1"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("localhost"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("hermes.internal"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("my-server.example.com"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("server_01.lab"))
    }

    func testRemoteTunnelRequestValidRemoteHost_rejectsEmpty() {
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost(""))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("   "))
    }

    func testRemoteTunnelRequestValidRemoteHost_rejectsColon() {
        // A colon would corrupt the SSH -L localPort:remoteHost:remotePort argument
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("127.0.0.1:9119"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("::1"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host:extra"))
    }

    func testRemoteTunnelRequestValidRemoteHost_rejectsWhitespace() {
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("my host"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host\twith\ttabs"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host\nnewline"))
    }

    func testRemoteTunnelRequestValidRemoteHost_rejectsShellMetachars() {
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host;rm -rf /"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host|cat /etc/passwd"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host&&command"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host`whoami`"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("$(evil)"))
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("host -o ProxyCommand=evil"))
    }

    func testRemoteTunnelRequestIsValid() {
        let good = RemoteTunnelRequest(localPort: 9119, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        XCTAssertTrue(good.isValid)

        let badHost = RemoteTunnelRequest(localPort: 9119, remoteHost: "host:evil", remotePort: 9119, purpose: .runtimeAccess)
        XCTAssertFalse(badHost.isValid)

        let badLocalPort = RemoteTunnelRequest(localPort: 0, remoteHost: "127.0.0.1", remotePort: 9119, purpose: .runtimeAccess)
        XCTAssertFalse(badLocalPort.isValid)

        let badRemotePort = RemoteTunnelRequest(localPort: 9119, remoteHost: "127.0.0.1", remotePort: 99999, purpose: .runtimeAccess)
        XCTAssertFalse(badRemotePort.isValid)
    }

    @MainActor
    func testTunnelStartBlockedForInvalidRemoteHost() async throws {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }

        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)

        let mockPath = try createMockSSHAdd(exitCode: 0, stdout: "2048 SHA256:abc /Users/developer/.ssh/id_rsa (RSA)", stderr: "")
        vm.sshPreflightService = SSHPreflightService(sshAddPath: mockPath)

        let settings = RemoteHostSettings(host: "success.local")
        await vm.testRemoteConnection(settings: settings)
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)

        // An invalid remoteHost containing a colon must be blocked before SSH args are built
        let maliciousRequest = RemoteTunnelRequest(
            localPort: 9119,
            remoteHost: "127.0.0.1:evil-injection",
            remotePort: 9119,
            purpose: .runtimeAccess
        )
        await vm.startRemoteTunnel(settings: settings, request: maliciousRequest)
        XCTAssertEqual(vm.remoteHostStatus.tunnelState, .failed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Invalid tunnel port configuration.")
    }

    // MARK: - v0.11 Phase 1: IPv6 Bracket Support
    //
    // v0.11 adds bracketed IPv6 tunnel host support.
    //
    // Unbracketed IPv6 (e.g. "::1") is still rejected — colons would corrupt the
    // SSH -L localPort:remoteHost:remotePort forwarding argument.
    //
    // Bracketed IPv6 (e.g. "[::1]", "[2001:db8::1]") is now accepted.
    // The brackets disambiguate colons in the SSH -L argument:
    //   9119:[::1]:9119 — valid SSH syntax.
    // Inner content is validated: hex digits, colons, dots only, with at least one colon.
    // Brackets outside the IPv6 path are still rejected as shell metacharacters.

    func testIPv6UnbracketedStillRejected() {
        // Unbracketed IPv6 contains colons — always rejected
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("::1"),
                       "Unbracketed IPv6 loopback must be rejected (colon in argument)")
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("2001:db8::1"),
                       "Unbracketed global IPv6 must be rejected")
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("fe80::1%eth0"),
                       "Link-local IPv6 with zone ID must be rejected (percent sign)")
    }

    func testIPv6BracketedAcceptedAsRemoteHost() {
        // v0.11: bracketed IPv6 is now accepted
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("[::1]"),
                       "Bracketed IPv6 loopback must be accepted in v0.11")
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("[2001:db8::1]"),
                       "Bracketed global IPv6 must be accepted")
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("[::ffff:192.0.2.1]"),
                       "IPv4-mapped IPv6 must be accepted")
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("[fd00::1]"),
                       "Unique local IPv6 must be accepted")
    }

    func testIPv6MalformedBracketsRejected() {
        // Missing closing bracket
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[::1"),
                       "Missing closing bracket must be rejected")
        // Missing opening bracket
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("::1]"),
                       "Missing opening bracket (treated as non-bracketed, colon rejected)")
        // Empty brackets
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[]"),
                       "Empty brackets must be rejected")
        // Non-IPv6 in brackets
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[not-an-address]"),
                       "Non-IPv6 content in brackets must be rejected (hyphens forbidden)")
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[localhost]"),
                       "DNS name in brackets must be rejected (no colon)")
        // Brackets with shell metacharacters
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[::1];rm -rf /"),
                       "Bracketed host followed by shell injection must be rejected")
        XCTAssertFalse(RemoteTunnelRequest.isValidRemoteHost("[::1]$(evil)"),
                       "Bracketed host followed by command substitution must be rejected")
    }

    func testSSHArgumentConstructionWithBracketedIPv6() {
        // Verify SSH -L argument preserves brackets correctly
        let req = RemoteTunnelRequest(localPort: 9119, remoteHost: "[::1]", remotePort: 9119,
                                     purpose: .runtimeAccess)
        XCTAssertTrue(req.isValid, "Bracketed IPv6 request must be valid")
        let cmd = RemoteHermesCommand.tunnelStart
        let args = cmd.remoteArguments(hermesCommandBase: "hermes", tunnelRequest: req)
        let sshArg = args.first { $0.starts(with: "-L") }
        XCTAssertNotNil(sshArg, "SSH -L argument must be present")
        // The argument should be the full -L localPort:remoteHost:remotePort
        let tunnelArg = args[args.index(of: "-L")! + 1]
        XCTAssertEqual(tunnelArg, "9119:[::1]:9119",
                       "SSH -L argument must preserve brackets for IPv6")
    }

    func testIPv4AndDNSStillAcceptedAfterIPv6Support() {
        // Confirm IPv4 and DNS names are unaffected by IPv6 support
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("127.0.0.1"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("192.168.1.100"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("hermes.internal"))
        XCTAssertTrue(RemoteTunnelRequest.isValidRemoteHost("my-server.example.com"))
    }
}
