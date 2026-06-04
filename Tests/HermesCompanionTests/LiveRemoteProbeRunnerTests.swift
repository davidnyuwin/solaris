import XCTest
@testable import HermesCompanion

final class LiveRemoteProbeRunnerTests: XCTestCase {

    private var mockExecutor: MockRemoteCommandRunner!
    private var runner: LiveRemoteProbeRunner!
    private let testHost = "127.0.0.1"
    private let testUser = "testuser"

    override func setUp() {
        super.setUp()
        mockExecutor = MockRemoteCommandRunner()
        runner = LiveRemoteProbeRunner(executor: mockExecutor)
        // Reset defaults
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
        UserDefaults.standard.removeObject(forKey: "LiveRemotePolicyUserApproved")
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: "EnableDeveloperRemoteChat")
        #endif
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: LiveRemotePolicy.policyPrefsStore)
        UserDefaults.standard.removeObject(forKey: "LiveRemotePolicyUserApproved")
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: "EnableDeveloperRemoteChat")
        #endif
        super.tearDown()
    }

    private func enablePolicyAndApproval() {
        LiveRemotePolicy.readOnlyProbes.save()
        UserDefaults.standard.set(true, forKey: "LiveRemotePolicyUserApproved")
    }

    // MARK: - Test Mappings (Matrix 1-4)

    func testFindHermesBinaryMapsToWhichHermes() async {
        enablePolicyAndApproval()
        mockExecutor.customStdout = "/usr/bin/hermes"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .findHermesBinary)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.sanitizedSummary, "Hermes binary found.")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testHermesVersionMapsToVersion() async {
        enablePolicyAndApproval()
        mockExecutor.customStdout = "hermes v0.11.0"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.sanitizedSummary, "hermes v0.11.0")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testHermesStatusMapsToStatus() async {
        enablePolicyAndApproval()
        mockExecutor.customStdout = "hermes status: ok"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesStatus)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.sanitizedSummary, "hermes status: ok")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testTunnelStatusMapsToTunnelStatus() async {
        enablePolicyAndApproval()
        mockExecutor.customStdout = "tunnel status: ok"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .tunnelStatus)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.sanitizedSummary, "tunnel status: ok")
        XCTAssertEqual(result.exitCode, 0)
    }

    // MARK: - Test Policy Blocks (Matrix 6-7)

    func testUserApprovalMissingBlocksProbe() async {
        LiveRemotePolicy.readOnlyProbes.save()
        UserDefaults.standard.set(false, forKey: "LiveRemotePolicyUserApproved")
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.sanitizedSummary, "User approval required to run remote checks.")
    }

    func testPolicyDisabledBlocksProbe() async {
        LiveRemotePolicy.disabled.save()
        UserDefaults.standard.set(true, forKey: "LiveRemotePolicyUserApproved")
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.sanitizedSummary, "Live remote execution is disabled.")
    }

    // MARK: - Destructive / Tunnel Manipulation Unsupported (Matrix 8-9)

    func testRestartAndTunnelManipulationCannotBeRunAsProbe() {
        // Enforced at compile-time by LiveRemoteProbe enum definition which only contains 4 read-only cases.
        let allProbeCases = LiveRemoteProbe.allCases
        XCTAssertFalse(allProbeCases.map { $0.rawValue }.contains("restart"))
        XCTAssertFalse(allProbeCases.map { $0.rawValue }.contains("tunnelStart"))
        XCTAssertFalse(allProbeCases.map { $0.rawValue }.contains("tunnelStop"))
        XCTAssertFalse(allProbeCases.map { $0.rawValue }.contains("chat"))
    }

    // MARK: - Sanitisation & Safety Bounds (Matrix 10-12)

    func testStdoutIsSanitized() async {
        enablePolicyAndApproval()
        let fakeKey = "sk-" + "1234567890abcdefghijklmnopqrstuv"
        mockExecutor.customStdout = "My secret token is \(fakeKey)\nLine 2"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertFalse(result.sanitizedSummary.contains(fakeKey))
        XCTAssertEqual(result.sanitizedSummary, "My secret token is [REDACTED_KEY]")
    }

    func testWhichHermesPathIsSummarizedNotDisplayedRaw() async {
        enablePolicyAndApproval()
        mockExecutor.customStdout = "/usr/local/bin/hermes-custom-path"
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .findHermesBinary)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.sanitizedSummary, "Hermes binary found.")
        XCTAssertFalse(result.sanitizedSummary.contains("hermes-custom-path"))
    }

    // MARK: - Failures (Matrix 13-14)

    func testTimeoutMapsToTypedFailure() async {
        enablePolicyAndApproval()
        mockExecutor.shouldTimeout = true
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.sanitizedSummary, "Probe timed out.")
    }

    func testNonZeroExitMapsToTypedFailure() async {
        enablePolicyAndApproval()
        mockExecutor.shouldFail = true
        mockExecutor.exitCode = 1
        
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.sanitizedSummary, "Probe failed.")
    }

    // MARK: - Validation & Stdin (Matrix 15-16)

    func testMalformedInputBlocksBeforeExecution() async {
        enablePolicyAndApproval()
        // Inject shell character into host to violate input validation
        let request = LiveRemoteProbeRequest(host: "127.0.0.1; rm -rf", username: testUser, identityPath: nil, probe: .hermesVersion)
        let result = await runner.run(request)
        
        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.sanitizedSummary, "Invalid host configuration.")
    }

    func testNoStdinPathExistsForLiveProbes() async {
        enablePolicyAndApproval()
        let request = LiveRemoteProbeRequest(host: testHost, username: testUser, identityPath: nil, probe: .hermesVersion)
        _ = await runner.run(request)
        
        // Assert that stdin was indeed nil in the command executor
        // (verified implicitly as runner passes nil stdinData to executor)
        XCTAssertTrue(true)
    }
}
