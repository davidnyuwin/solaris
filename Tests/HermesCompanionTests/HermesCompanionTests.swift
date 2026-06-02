import XCTest
@testable import HermesCompanion

@MainActor
final class HermesCompanionTests: XCTestCase {
    
    func testMockServiceLoad() async throws {
        let service = MockHermesService()
        let status = try await service.getStatus()
        XCTAssertEqual(status.state, .idle)
        XCTAssertTrue(status.relayConnected)
    }
    
    func testSendCommandFlow() async throws {
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        XCTAssertEqual(viewModel.runs.count, 3)
        
        viewModel.currentInput = "Check relay health"
        await viewModel.sendCommand()
        
        XCTAssertEqual(viewModel.runs.count, 4)
        XCTAssertEqual(viewModel.runs[0].prompt, "Check relay health")
        XCTAssertTrue(viewModel.runs[0].isSuccess)
    }
    
    func testQuickActionCommand() async throws {
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        await viewModel.executeQuickAction("test providers")
        
        XCTAssertEqual(viewModel.runs.count, 4)
        XCTAssertEqual(viewModel.runs[0].prompt, "test providers")
        XCTAssertTrue(viewModel.runs[0].response.contains("Tested 4 providers"))
    }
    
    func testCLIParsers() {
        let parsers = HermesCLIParsers()
        
        // 1. Test hermes status parser with running fixture
        let statusRunningStdout = """
        ☄️ Hermes Agent Component Status

        Inference Configuration:
          Active Provider: ollama (local)
          Active Model: nous-hermes-2

        Background Daemons:
          Messaging Gateway: Running (PID: 12345)
          Vite Dashboard: Running (PID: 12346)

        Local Environment:
          Hermes Home: /Users/username/.hermes
          Active Profile: default
          Config Version: 2

        Diagnostic check passed!
        """
        let parsedStatus = parsers.parseStatus(statusRunningStdout)
        XCTAssertEqual(parsedStatus.activeProvider, "ollama (local)")
        XCTAssertEqual(parsedStatus.activeModel, "nous-hermes-2")
        XCTAssertEqual(parsedStatus.messagingGatewayState, "Running (PID: 12345)")
        XCTAssertEqual(parsedStatus.dashboardState, "Running (PID: 12346)")
        XCTAssertEqual(parsedStatus.hermesHome, "~/.hermes")
        XCTAssertEqual(parsedStatus.activeProfile, "default")
        XCTAssertEqual(parsedStatus.configVersion, "2")
        
        // 2. Test status parser with missing fields
        let statusMissingStdout = """
        ☄️ Hermes Agent Component Status

        Inference Configuration:

        Background Daemons:

        Local Environment:
        """
        let parsedStatusMissing = parsers.parseStatus(statusMissingStdout)
        XCTAssertNil(parsedStatusMissing.activeProvider)
        XCTAssertNil(parsedStatusMissing.activeModel)
        XCTAssertNil(parsedStatusMissing.messagingGatewayState)
        XCTAssertNil(parsedStatusMissing.dashboardState)
        XCTAssertNil(parsedStatusMissing.hermesHome)
        XCTAssertNil(parsedStatusMissing.activeProfile)
        XCTAssertNil(parsedStatusMissing.configVersion)

        // 3. Test gateway status parser with running fixture
        let gatewayRunningStdout = """
        Gateway Daemon Status:
          Service Status: Running (Active)
          Process ID: 12345
          Platform Listeners: telegram, discord
          Active Log File: /Users/username/.hermes/logs/gateway.log
          Log Size: 4.5 KB
          Recent Events (Last 3):
            [2026-06-02 12:45:00] Gateway startup completed.
            [2026-06-02 12:44:50] Gateway process spawned (PID: 12345).
            [2026-06-02 12:44:45] Gateway initialized.
        """
        let parsedGateway = parsers.parseGatewayStatus(gatewayRunningStdout)
        XCTAssertEqual(parsedGateway.serviceStatus, "Running (Active)")
        XCTAssertEqual(parsedGateway.processID, "12345")
        XCTAssertEqual(parsedGateway.platformListeners, "telegram, discord")
        XCTAssertEqual(parsedGateway.activeLogFile, "~/.hermes/logs/gateway.log")
        XCTAssertEqual(parsedGateway.logSize, "4.5 KB")
        XCTAssertEqual(parsedGateway.recentEvents.count, 3)
        XCTAssertEqual(parsedGateway.recentEvents[0], "[2026-06-02 12:45:00] Gateway startup completed.")
        XCTAssertEqual(parsedGateway.recentEvents[1], "[2026-06-02 12:44:50] Gateway process spawned (PID: 12345).")
        XCTAssertEqual(parsedGateway.recentEvents[2], "[2026-06-02 12:44:45] Gateway initialized.")
    }
    
    func testDiagnosticsRedactor() {
        let rawMessage = "User folder is /Users/someuser/documents and PID: 12345 or Process ID: 9876 with hex_hash 3a7f8c9b2d1e0f3a or bearer: secret-token-xyz"
        let redacted = DiagnosticsRedactor.redact(rawMessage)
        XCTAssertTrue(redacted.contains("User folder is ~/documents"))
        XCTAssertTrue(redacted.contains("PID: [PID]"))
        XCTAssertTrue(redacted.contains("Process ID: [PID]"))
        XCTAssertTrue(redacted.contains("hex_hash [REDACTED_TOKEN]"))
        XCTAssertTrue(redacted.contains("bearer: [REDACTED]"))
    }
    
    func testRefreshIntervalDefaults() {
        // Default interval is manual
        let defaultInterval = DiagnosticsRefreshInterval.manual
        XCTAssertEqual(defaultInterval.rawValue, "manual")
        XCTAssertNil(defaultInterval.timeInterval)
        XCTAssertEqual(defaultInterval.displayName, "Manual")
        
        // All cases are present
        let allCases = DiagnosticsRefreshInterval.allCases
        XCTAssertTrue(allCases.contains(.manual))
        XCTAssertTrue(allCases.contains(.thirtySeconds))
        XCTAssertTrue(allCases.contains(.oneMinute))
        XCTAssertTrue(allCases.contains(.fiveMinutes))
        
        // Display labels
        XCTAssertEqual(DiagnosticsRefreshInterval.thirtySeconds.displayName, "30 sec")
        XCTAssertEqual(DiagnosticsRefreshInterval.oneMinute.displayName, "1 min")
        XCTAssertEqual(DiagnosticsRefreshInterval.fiveMinutes.displayName, "5 min")
        
        // Time intervals
        XCTAssertEqual(DiagnosticsRefreshInterval.thirtySeconds.timeInterval, 30.0)
        XCTAssertEqual(DiagnosticsRefreshInterval.oneMinute.timeInterval, 60.0)
        XCTAssertEqual(DiagnosticsRefreshInterval.fiveMinutes.timeInterval, 300.0)
    }
    
    func testSchedulerDoesNotStartForManualInterval() async {
        let viewModel = HermesViewModel(service: MockHermesService())
        XCTAssertEqual(viewModel.refreshInterval, .manual)
        
        // Starting scheduler with Manual interval should be a no-op
        viewModel.startScheduler()
        
        // No refresh should have been triggered — isRefreshingDiagnostics stays false
        XCTAssertFalse(viewModel.isRefreshingDiagnostics)
        
        // Cleanup
        viewModel.stopScheduler()
    }
    
    func testMakeRedactedDiagnosticsSummaryRedactionSafety() async {
        let viewModel = HermesViewModel(service: MockHermesService())
        
        // Load mock data that includes paths, PIDs, and tokens
        await viewModel.loadAllData()
        
        let summary = viewModel.makeRedactedDiagnosticsSummary()
        
        // Must include safe metadata
        XCTAssertTrue(summary.contains("Solaris Diagnostics Summary"))
        XCTAssertTrue(summary.contains("Solaris Version:"))
        XCTAssertTrue(summary.contains("Last Checked:"))
        
        // Must NOT contain raw absolute paths
        XCTAssertFalse(summary.contains("/Users/"))
        
        // Must NOT contain raw PID patterns from mock data
        XCTAssertFalse(summary.contains("PID: 12345"))
        XCTAssertFalse(summary.contains("PID: 12346"))
        
        // Must NOT contain raw token-like strings
        XCTAssertFalse(summary.contains("secret-token"))
        XCTAssertFalse(summary.contains("sk-"))
        
        // Must include safe provider metadata
        XCTAssertTrue(summary.contains("Active Providers / Relays:"))
    }
    
    func testDiagnosticsLogPauseToggle() async {
        let viewModel = HermesViewModel(service: MockHermesService())
        
        // Initially not paused
        XCTAssertFalse(viewModel.isDiagnosticsLogPaused)
        XCTAssertTrue(viewModel.pausedLogs.isEmpty)
        
        await viewModel.loadAllData()
        let initialLogCount = viewModel.logs.count
        XCTAssertGreaterThan(initialLogCount, 0)
        
        // Toggle pause on
        viewModel.toggleDiagnosticsLogPause()
        XCTAssertTrue(viewModel.isDiagnosticsLogPaused)
        XCTAssertEqual(viewModel.pausedLogs.count, initialLogCount)
        
        // Adding new logs while paused should not affect paused snapshot
        let extraLog = LogLine(id: "extra-1", timestamp: Date(), level: "INFO", message: "New log while paused")
        viewModel.logs.append(extraLog)
        XCTAssertEqual(viewModel.pausedLogs.count, initialLogCount)
        XCTAssertGreaterThan(viewModel.logs.count, initialLogCount)
        
        // Toggle pause off — snapshot retained (display switches back to live logs)
        viewModel.toggleDiagnosticsLogPause()
        XCTAssertFalse(viewModel.isDiagnosticsLogPaused)
        XCTAssertEqual(viewModel.pausedLogs.count, initialLogCount)
    }
    
    func testClassifyCLIStatusAvailable() {
        let kind = classifyCLIStatus("Available")
        XCTAssertEqual(kind, .available)
        XCTAssertEqual(kind.label, "Available")
        XCTAssertEqual(kind.explanation, "Hermes CLI status checks are working.")
    }
    
    func testClassifyCLIStatusTimedOut() {
        let kind = classifyCLIStatus("Timed out")
        XCTAssertEqual(kind, .timedOut)
        XCTAssertEqual(kind.label, "Timed out")
        XCTAssertEqual(kind.explanation, "The read-only CLI check did not finish in time.")
    }
    
    func testClassifyCLIStatusPythonMissing() {
        let kind = classifyCLIStatus("Unavailable (Python missing)")
        XCTAssertEqual(kind, .pythonMissing)
        XCTAssertEqual(kind.label, "Unavailable")
        XCTAssertEqual(kind.explanation, "Hermes Studio bundled Python was not found.")
    }
    
    func testClassifyCLIStatusNonZeroExit() {
        let kind = classifyCLIStatus("Unavailable (Exit code: 1)")
        XCTAssertEqual(kind, .nonZeroExit)
        XCTAssertEqual(kind.label, "Unavailable")
        XCTAssertEqual(kind.explanation, "Hermes CLI returned an error.")
    }
    
    func testClassifyCLIStatusEmptyStdout() {
        let kind = classifyCLIStatus("Parse warning (Empty stdout)")
        XCTAssertEqual(kind, .emptyStdout)
        XCTAssertEqual(kind.label, "Parse warning")
        XCTAssertEqual(kind.explanation, "Hermes CLI returned no output.")
    }
    
    func testClassifyCLIStatusNoFieldsParsed() {
        let kind = classifyCLIStatus("Parse warning (No fields parsed)")
        XCTAssertEqual(kind, .noFieldsParsed)
        XCTAssertEqual(kind.label, "Parse warning")
        XCTAssertEqual(kind.explanation, "Hermes CLI output changed or could not be parsed.")
    }
    
    func testClassifyCLIStatusNil() {
        let kind = classifyCLIStatus(nil)
        XCTAssertEqual(kind, .unknown)
        XCTAssertEqual(kind.label, "Unavailable")
        XCTAssertEqual(kind.explanation, "Read-only CLI status is not available.")
    }
    
    func testClassifyCLIStatusArbitraryString() {
        let kind = classifyCLIStatus("Something unexpected")
        XCTAssertEqual(kind, .unknown)
    }
    
    // MARK: - Remote Host Mode Tests
    
    func testRemoteCommandEnumCases() {
        // All three allowlisted commands must be present
        let allCommands = RemoteHermesCommand.allCases
        XCTAssertTrue(allCommands.contains(.whichHermes))
        XCTAssertTrue(allCommands.contains(.hermesVersion))
        XCTAssertTrue(allCommands.contains(.hermesStatus))
        XCTAssertEqual(allCommands.count, 3)
    }
    
    func testRemoteCommandWhichArguments() {
        let args = RemoteHermesCommand.whichHermes.remoteArguments(hermesCommandBase: "hermes")
        XCTAssertEqual(args, ["which", "hermes"])
    }
    
    func testRemoteCommandVersionArguments() {
        let args = RemoteHermesCommand.hermesVersion.remoteArguments(hermesCommandBase: "hermes")
        XCTAssertEqual(args, ["hermes", "--version"])
    }
    
    func testRemoteCommandStatusArguments() {
        let args = RemoteHermesCommand.hermesStatus.remoteArguments(hermesCommandBase: "hermes")
        XCTAssertEqual(args, ["hermes", "status"])
    }
    
    func testRemoteCommandCustomBase() {
        let args = RemoteHermesCommand.hermesStatus.remoteArguments(hermesCommandBase: "/custom/path/hermes")
        XCTAssertEqual(args, ["/custom/path/hermes", "status"])
    }
    
    func testRemoteCommandEnumDoesNotContainUnsafeCommands() {
        let rawValues = RemoteHermesCommand.allCases.map(\.rawValue)
        XCTAssertFalse(rawValues.contains { $0.contains("send") })
        XCTAssertFalse(rawValues.contains { $0.contains("model") })
        XCTAssertFalse(rawValues.contains { $0.contains("gateway") })
        XCTAssertFalse(rawValues.contains { $0.contains("config") })
    }
    
    func testRemoteHostSettingsValidation() {
        let empty = RemoteHostSettings()
        XCTAssertFalse(empty.isValid)
        XCTAssertEqual(empty.displayLabel, "Not configured")
        
        let valid = RemoteHostSettings(host: "hermes-host.local")
        XCTAssertTrue(valid.isValid)
        XCTAssertEqual(valid.displayLabel, "hermes-host.local")
        XCTAssertEqual(valid.userAtHost, "hermes-host.local")
        
        let withUser = RemoteHostSettings(host: "hermes-host.local", username: "admin")
        XCTAssertEqual(withUser.userAtHost, "admin@hermes-host.local")
    }
    
    func testRemoteHostSettingsDefaults() {
        let settings = RemoteHostSettings()
        XCTAssertEqual(settings.port, 22)
        XCTAssertEqual(settings.hermesCommand, "hermes")
        XCTAssertEqual(settings.host, "")
        XCTAssertEqual(settings.username, "")
    }
    
    func testRemoteHermesStatusSnapshotConnected() {
        let snap = RemoteHermesStatusSnapshot(
            hostLabel: "my-host",
            hermesFound: true,
            hermesVersion: "Hermes v1.0",
            statusSummary: "Status: OK",
            lastCheckedAt: Date(),
            errorMessage: nil
        )
        XCTAssertEqual(snap.state, .connected)
        XCTAssertTrue(snap.hermesFound)
        XCTAssertEqual(snap.hermesVersion, "Hermes v1.0")
        XCTAssertEqual(snap.statusSummary, "Status: OK")
    }
    
    func testRemoteHermesStatusSnapshotFailed() {
        let snap = RemoteHermesStatusSnapshot(
            hostLabel: "my-host",
            hermesFound: false,
            hermesVersion: nil,
            statusSummary: nil,
            lastCheckedAt: Date(),
            errorMessage: "Connection refused"
        )
        XCTAssertEqual(snap.state, .failed("Connection refused"))
        XCTAssertFalse(snap.hermesFound)
    }
    
    func testRemoteHermesStatusSnapshotNotConfigured() {
        let snap = RemoteHermesStatusSnapshot.notConfigured
        XCTAssertEqual(snap.state, .notConfigured)
        XCTAssertEqual(snap.hostLabel, "Not configured")
    }
}


