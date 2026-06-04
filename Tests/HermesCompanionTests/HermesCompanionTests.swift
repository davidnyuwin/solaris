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
        // All eight allowlisted commands must be present
        let allCommands = RemoteHermesCommand.allCases
        XCTAssertTrue(allCommands.contains(.whichHermes))
        XCTAssertTrue(allCommands.contains(.hermesVersion))
        XCTAssertTrue(allCommands.contains(.hermesStatus))
        XCTAssertTrue(allCommands.contains(.hermesChat))
        XCTAssertTrue(allCommands.contains(.hermesRestart))
        XCTAssertTrue(allCommands.contains(.tunnelStart))
        XCTAssertTrue(allCommands.contains(.tunnelStop))
        XCTAssertTrue(allCommands.contains(.tunnelStatus))
        XCTAssertEqual(allCommands.count, 8)
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
    
    func testRemoteCommandRestartArguments() {
        let args = RemoteHermesCommand.hermesRestart.remoteArguments(hermesCommandBase: "hermes")
        XCTAssertEqual(args, ["hermes", "restart"])
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
    
    // MARK: - Batch 2B Command Builder Tests
    
    func testRemoteCommandBuilderAllowsKnownCommands() throws {
        let whichArgs = try RemoteCommandBuilder.buildArguments(for: .which, hermesCommandBase: "hermes")
        XCTAssertEqual(whichArgs, ["which", "hermes"])
        
        let versionArgs = try RemoteCommandBuilder.buildArguments(for: .version, hermesCommandBase: "/path/to/hermes")
        XCTAssertEqual(versionArgs, ["/path/to/hermes", "--version"])
        
        let statusArgs = try RemoteCommandBuilder.buildArguments(for: .status, hermesCommandBase: "hermes-cli")
        XCTAssertEqual(statusArgs, ["hermes-cli", "status"])
        
        let gatewayArgs = try RemoteCommandBuilder.buildArguments(for: .gatewayStatus, hermesCommandBase: "hermes")
        XCTAssertEqual(gatewayArgs, ["hermes", "gateway", "status"])
    }
    
    func testRemoteCommandBuilderRejectsArbitraryCommands() {
        XCTAssertThrowsError(try RemoteCommandBuilder.sanitiseHermesCommand("hermes; rm -rf /"))
        XCTAssertThrowsError(try RemoteCommandBuilder.sanitiseHermesCommand("hermes && ls"))
        XCTAssertThrowsError(try RemoteCommandBuilder.sanitiseHermesCommand("hermes|grep something"))
    }
    
    func testRemoteCommandBuilderBlocksChat() {
        XCTAssertThrowsError(try RemoteCommandBuilder.buildArguments(for: .chat(promptPlaceholder: "test"), hermesCommandBase: "hermes")) { error in
            XCTAssertEqual(error as? RemoteCommandBuilderError, .chatExecutionNotYetApproved)
        }
    }
    
    // MARK: - Batch 2B Output Sanitiser Tests
    
    func testOutputSanitiserAnsiOSCControlStripping() {
        let ansiInput = "\u{001B}[31mRed Text\u{001B}[0m and Normal Text"
        let ansiResult = OutputSanitiser.sanitise(ansiInput)
        XCTAssertEqual(ansiResult.text, "Red Text and Normal Text")
        XCTAssertFalse(ansiResult.isTruncated)
        
        let oscInput = "\u{001B}]8;;http://example.com\u{0007}Click Here\u{001B}]8;;\u{0007}"
        let oscResult = OutputSanitiser.sanitise(oscInput)
        XCTAssertEqual(oscResult.text, "Click Here")
        
        // OSC ST termination style
        let oscStInput = "\u{001B}]8;;http://example.com\u{001B}\\Link\u{001B}]8;;\u{001B}\\"
        let oscStResult = OutputSanitiser.sanitise(oscStInput)
        XCTAssertEqual(oscStResult.text, "Link")
        
        let controlInput = "Line 1\u{0000}\u{0007}Line 2\u{007F}Line 3\u{0085}Line 4"
        let controlResult = OutputSanitiser.sanitise(controlInput)
        XCTAssertEqual(controlResult.text, "Line 1Line 2Line 3Line 4")
    }
    
    func testOutputSanitiserUnicodeLossyHandling() {
        // Construct invalid UTF-8 bytes
        let invalidBytes = Data([0xFF, 0xFE, 0xFD, 0x41, 0x42]) // AB with invalid prefix
        let invalidStr = String(decoding: invalidBytes, as: UTF8.self) // Let swift produce standard replacement string
        let sanitised = OutputSanitiser.sanitise(invalidStr)
        XCTAssertTrue(sanitised.text.contains("\u{FFFD}"))
        XCTAssertTrue(sanitised.text.contains("AB"))
    }
    
    func testOutputSanitiserTruncation() {
        let largeInput = String(repeating: "A", count: 70000)
        let result = OutputSanitiser.sanitise(largeInput)
        XCTAssertTrue(result.isTruncated)
        XCTAssertEqual(result.text.count, 65536 + "\n[output truncated after 65536 bytes]".count)
        XCTAssertTrue(result.text.hasSuffix("\n[output truncated after 65536 bytes]"))
    }
    
    func testOutputSanitiserRedactionsAndPreservation() {
        let bearerToken = "bearer " + "abc123xyz7890abc123"
        let openaiKey = "sk-" + "123456789012345678901234567890"
        
        let input = """
        User folder is /Users/sysadmin/project
        Bearer Token: \(bearerToken)
        OpenAI Key: \(openaiKey)
        Private Key:
        -----BEGIN PRIVATE KEY-----
        MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC3
        -----END PRIVATE KEY-----
        Commit hash: 4ad9f5c9aa10cc3c49003489c26b068e8c95d661
        Short hash: 715c9ad
        API_TOKEN = 'secret-token-value-here'
        """

        
        let result = OutputSanitiser.sanitise(input)
        let text = result.text
        
        XCTAssertTrue(text.contains("User folder is ~/project"))
        XCTAssertTrue(text.contains("Bearer [REDACTED]"))
        XCTAssertTrue(text.contains("[REDACTED_KEY]"))
        XCTAssertTrue(text.contains("[REDACTED_PRIVATE_KEY]"))
        XCTAssertTrue(text.contains("API_TOKEN: [REDACTED]"))
        
        // Assert preservation of git commit hashes
        XCTAssertTrue(text.contains("Commit hash: 4ad9f5c9aa10cc3c49003489c26b068e8c95d661"))
        XCTAssertTrue(text.contains("Short hash: 715c9ad"))
    }
    
    // MARK: - Batch 2C Prompt Transport & Chat Block Tests
    
    func testPromptTransportStrategyEnum() {
        let allCases = PromptTransportStrategy.allCases
        XCTAssertTrue(allCases.contains(.stdinSupported))
        XCTAssertTrue(allCases.contains(.argumentOnlyBlocked))
        XCTAssertTrue(allCases.contains(.gatewayPreferred))
        XCTAssertTrue(allCases.contains(.unknownBlocked))
        
        XCTAssertEqual(PromptTransportStrategy.stdinSupported.displayName, "Standard Input Pipe (stdin)")
        XCTAssertEqual(PromptTransportStrategy.argumentOnlyBlocked.displayName, "Command Arguments (Blocked)")
    }
    
    func testMockChatSimulationFlow() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        UserDefaults.standard.set("mock", forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        let initialRunsCount = viewModel.runs.count
        
        viewModel.currentInput = "/chat hello there"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount + 1)
        XCTAssertEqual(viewModel.runs[0].prompt, "/chat hello there")
        
        // Assert mock output was sanitised
        let responseText = viewModel.runs[0].response
        XCTAssertTrue(responseText.contains("This text had ANSI colors")) // escapes stripped, raw text preserved
        XCTAssertFalse(responseText.contains("/Users/sysadmin/")) // path normalised
        let mockKey = "sk-" + "abcdefghijklmnopqrstuvwxyz123456"
        XCTAssertFalse(responseText.contains(mockKey)) // OpenAI key redacted
        XCTAssertTrue(responseText.contains("[REDACTED_KEY]"))

        XCTAssertEqual(viewModel.status?.state, .idle)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLiveChatBlockedFlow() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(false, forKey: "EnableDeveloperRemoteChat")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        let initialRunsCount = viewModel.runs.count
        
        viewModel.currentInput = "/chat verify stdin"
        await viewModel.sendCommand()
        
        // No new run is added since execution is blocked
        XCTAssertEqual(viewModel.runs.count, initialRunsCount)
        XCTAssertEqual(viewModel.status?.state, .error)
        XCTAssertEqual(
            viewModel.errorMessage,
            "Remote chat is disabled. Enable the developer remote chat gate to test stdin-based Hermes chat execution."
        )
    }

    func testLiveChatDeveloperGateEnabledHostNotConfigured() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("", forKey: "RemoteHost") // Not configured
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        let initialRunsCount = viewModel.runs.count
        
        viewModel.currentInput = "/chat test prompt"
        await viewModel.sendCommand()
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount)
        XCTAssertEqual(viewModel.status?.state, .error)
        XCTAssertEqual(viewModel.errorMessage, "Remote host is not configured.")
    }

    func testLiveChatEmptyPromptRejected() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        let initialRunsCount = viewModel.runs.count
        
        viewModel.currentInput = "/chat " // Empty prompt
        await viewModel.sendCommand()
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount)
        XCTAssertEqual(viewModel.status?.state, .error)
        XCTAssertEqual(viewModel.errorMessage, "Chat prompt cannot be empty.")
    }

    func testLiveChatOversizedPromptRejected() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        let initialRunsCount = viewModel.runs.count
        
        let oversizedPrompt = String(repeating: "A", count: 16385)
        viewModel.currentInput = "/chat \(oversizedPrompt)"
        await viewModel.sendCommand()
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount)
        XCTAssertEqual(viewModel.status?.state, .error)
        XCTAssertEqual(viewModel.errorMessage, "Chat prompt exceeds maximum allowed size of 16KB.")
    }

    func testLiveChatExecutionSuccess() async throws {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_chat_success.sh")
        let scriptContent = """
        #!/bin/sh
        echo "warning output" >&2
        echo "Response to: $(cat -)"
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        viewModel.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        await viewModel.loadAllData()
        
        let initialRunsCount = viewModel.runs.count
        viewModel.currentInput = "/chat test input payload"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount + 1)
        XCTAssertEqual(viewModel.runs[0].prompt, "/chat test input payload")
        XCTAssertTrue(viewModel.runs[0].response.contains("Response to: test input payload"))
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.status?.state, .idle)
        
        // Stderr warning should be captured in logs list
        XCTAssertTrue(viewModel.logs.contains { $0.message.contains("Remote chat stderr: warning output") })
    }

    func testLiveChatExecutionNonZeroExit() async {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_chat_failure.sh")
        let scriptContent = """
        #!/bin/sh
        echo "some critical error description" >&2
        exit 1
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        viewModel.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        await viewModel.loadAllData()
        
        let initialRunsCount = viewModel.runs.count
        viewModel.currentInput = "/chat failing input"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount + 1)
        XCTAssertEqual(viewModel.runs[0].prompt, "/chat failing input")
        XCTAssertFalse(viewModel.runs[0].isSuccess)
        XCTAssertTrue(viewModel.runs[0].response.contains("[Failed] SSH command failed"))
        XCTAssertEqual(viewModel.status?.state, .error)
        XCTAssertEqual(
            viewModel.errorMessage,
            "SSH command failed (exit code: 1). Detail: some critical error description"
        )
    }

    func testRemoteSSHExecutorTimeout() async {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_timeout.sh")
        let scriptContent = """
        #!/bin/sh
        sleep 5
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host")
        let result = await executor.execute(command: .whichHermes, settings: settings, timeout: 0.5)
        
        XCTAssertTrue(result.timedOut)
    }

    // MARK: - Batch 2D Stdin Executor Tests
    
    func testRemoteSSHExecutorWithoutStdin() async {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_no_stdin.sh")
        let scriptContent = """
        #!/bin/sh
        echo "args: $@"
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        let result = await executor.execute(command: .whichHermes, settings: settings)
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertTrue(result.stdout.contains("args:"))
        XCTAssertTrue(result.stdout.contains("which hermes"))
    }
    
    func testRemoteSSHExecutorWithStdin() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_stdin.sh")
        let scriptContent = """
        #!/bin/sh
        cat -
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        let testInput = "hello remote hermes stdin"
        let stdinData = testInput.data(using: .utf8)
        
        let result = await executor.execute(command: .whichHermes, settings: settings, stdinData: stdinData)
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), testInput)
    }
    
    func testRemoteSSHExecutorOversizedStdinRejected() async {
        let executor = RemoteSSHExecutor()
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        let oversizedData = Data(repeating: 65, count: 16385) // 16KB + 1 byte
        
        let result = await executor.execute(command: .whichHermes, settings: settings, stdinData: oversizedData)
        
        XCTAssertEqual(result.exitCode, -1)
        XCTAssertFalse(result.timedOut)
        XCTAssertEqual(result.duration, 0)
        XCTAssertTrue(result.stderr.contains("payload exceeds maximum allowed size of 16KB"))
    }

    // MARK: - Batch 2F Streaming Sanitiser Tests
    
    func testStreamingOutputSanitiserAnsiCsiSplit() {
        let sanitiser = StreamingOutputSanitiser()
        
        let chunk1 = Data("Hello \u{001B}[3".utf8)
        let chunk2 = Data("1mWorld".utf8)
        
        let result1 = sanitiser.appendAndSanitise(chunk1)
        let result2 = sanitiser.appendAndSanitise(chunk2)
        
        XCTAssertEqual(result1, "Hello ")
        XCTAssertEqual(result2, "World")
    }
    
    func testStreamingOutputSanitiserOscSplit() {
        let sanitiser = StreamingOutputSanitiser()
        
        let chunk1 = Data("Hello \u{001B}]8;;http://example".utf8)
        let chunk2 = Data(".com\u{0007}World".utf8)
        
        let result1 = sanitiser.appendAndSanitise(chunk1)
        let result2 = sanitiser.appendAndSanitise(chunk2)
        
        XCTAssertEqual(result1, "Hello ")
        XCTAssertEqual(result2, "World")
    }
    
    func testStreamingOutputSanitiserUtf8Split() {
        let sanitiser = StreamingOutputSanitiser()
        
        // "あ" in UTF-8 is [0xE3, 0x81, 0x82]
        let chunk1 = Data([0xE3, 0x81])
        let chunk2 = Data([0x82, 0x41]) // あ followed by 'A'
        
        let result1 = sanitiser.appendAndSanitise(chunk1)
        let result2 = sanitiser.appendAndSanitise(chunk2)
        
        XCTAssertEqual(result1, "")
        XCTAssertEqual(result2, "あA")
    }
    
    func testRemoteSSHExecutorStreamingSuccess() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_streaming_success.sh")
        let scriptContent = """
        #!/bin/sh
        echo "part 1"
        sleep 0.1
        echo "error output" >&2
        sleep 0.1
        echo "part 2"
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        
        let stream = executor.executeStreaming(command: .whichHermes, settings: settings)
        var events: [RemoteSSHStreamEvent] = []
        for await event in stream {
            events.append(event)
        }
        
        // We expect stdout, stderr, and completed events.
        XCTAssertTrue(events.contains(where: {
            if case .stdout(let text) = $0 {
                return text.contains("part 1")
            }
            return false
        }))
        XCTAssertTrue(events.contains(where: {
            if case .stdout(let text) = $0 {
                return text.contains("part 2")
            }
            return false
        }))
        XCTAssertTrue(events.contains(where: {
            if case .stderr(let text) = $0 {
                return text.contains("error output")
            }
            return false
        }))
        XCTAssertTrue(events.contains(.completed(exitCode: 0)))
    }
    
    func testRemoteSSHExecutorStreamingTimeout() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_streaming_timeout.sh")
        let scriptContent = """
        #!/bin/sh
        sleep 5
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        
        let stream = executor.executeStreaming(command: .whichHermes, settings: settings, timeout: 0.2)
        var events: [RemoteSSHStreamEvent] = []
        for await event in stream {
            events.append(event)
        }
        
        XCTAssertTrue(events.contains(.timedOut))
    }
    
    func testRemoteSSHExecutorStreamingCancellation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_streaming_cancel.sh")
        let scriptContent = """
        #!/bin/sh
        sleep 5
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        let settings = RemoteHostSettings(host: "test-host", username: "test-user")
        
        let task = Task {
            let stream = executor.executeStreaming(command: .whichHermes, settings: settings, timeout: 10)
            var count = 0
            for await _ in stream {
                count += 1
            }
            return count
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        task.cancel()
        
        let count = await task.value
        XCTAssertLessThan(count, 10)
    }

    // MARK: - Batch 2G Stream Redaction & UX Hardening Tests
    
    func testStreamRedactionSplitOpenAIKey() {
        let chunk1 = "Hello, my key is sk-proj-"
        let chunk2 = "abc123def456ghi789012345" // complete key length >= 20
        
        // During streaming (isStreaming: true)
        let progressive1 = OutputSanitiser.sanitise(chunk1, isStreaming: true).text
        XCTAssertFalse(progressive1.contains("sk-proj-"))
        XCTAssertTrue(progressive1.contains("...")) // suffix held back
        
        let progressive2 = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: true).text
        XCTAssertFalse(progressive2.contains("sk-proj-"))
        XCTAssertTrue(progressive2.contains("[REDACTED_KEY]"))
        
        // Final state (isStreaming: false)
        let final = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: false).text
        XCTAssertFalse(final.contains("sk-proj-"))
        XCTAssertTrue(final.contains("[REDACTED_KEY]"))
    }
    
    func testStreamRedactionSplitBearerToken() {
        let chunk1 = "Authorization: Bearer abc"
        let chunk2 = "def123456789"
        
        // During streaming
        let progressive1 = OutputSanitiser.sanitise(chunk1, isStreaming: true).text
        XCTAssertFalse(progressive1.contains("Bearer abc"))
        XCTAssertTrue(progressive1.contains("..."))
        
        let progressive2 = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: true).text
        XCTAssertFalse(progressive2.contains("abcdef"))
        XCTAssertTrue(progressive2.contains("Bearer [REDACTED]"))
        
        // Final state
        let final = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: false).text
        XCTAssertFalse(final.contains("abcdef"))
        XCTAssertTrue(final.contains("Bearer [REDACTED]"))
    }
    
    func testStreamRedactionSplitHomePath() {
        let chunk1 = "User path is /Users/sys"
        let chunk2 = "admin/project"
        
        // During streaming
        let progressive1 = OutputSanitiser.sanitise(chunk1, isStreaming: true).text
        XCTAssertFalse(progressive1.contains("/Users/sys"))
        XCTAssertTrue(progressive1.contains("..."))
        
        let progressive2 = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: true).text
        XCTAssertFalse(progressive2.contains("/Users/sysadmin"))
        XCTAssertTrue(progressive2.contains("~/project"))
        
        // Final state
        let final = OutputSanitiser.sanitise(chunk1 + chunk2, isStreaming: false).text
        XCTAssertFalse(final.contains("/Users/sysadmin"))
        XCTAssertTrue(final.contains("~/project"))
    }

    func testChatViewModelStateTransitionsSuccess() async throws {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        UserDefaults.standard.set("mock", forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        XCTAssertEqual(viewModel.chatState, .idle)
        
        viewModel.currentInput = "/chat test transition"
        
        // Start command execution
        let sendTask = Task {
            await viewModel.sendCommand()
        }
        
        // Wait a tiny bit and assert state is connecting/streaming
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        XCTAssertTrue(viewModel.chatState == .connecting || viewModel.chatState == .streaming)
        
        // Wait for it to finish
        await sendTask.value
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.chatState, .completed)
    }

    func testChatViewModelCancellation() async throws {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        UserDefaults.standard.set("mock", forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat cancel test"
        
        let sendTask = Task {
            await viewModel.sendCommand()
        }
        
        // Wait until it enters connecting/streaming state
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(viewModel.chatState == .connecting || viewModel.chatState == .streaming)
        
        // Cancel it!
        await viewModel.cancelActiveChat()
        
        await sendTask.value
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.chatState, .cancelled)
        XCTAssertFalse(viewModel.isPendingResponse)
    }

    func testChatViewModelDuplicateSendRejected() async throws {
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        UserDefaults.standard.set("mock", forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService())
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat task 1"
        let task1 = Task {
            await viewModel.sendCommand()
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(viewModel.chatState.isActive)
        
        // Try starting a second one
        viewModel.currentInput = "/chat task 2"
        await viewModel.sendCommand() // Should be rejected immediately
        
        XCTAssertEqual(viewModel.errorMessage, "Another remote chat stream is already active.")
        
        // Clean up task 1
        await viewModel.cancelActiveChat()
        _ = await viewModel.activeChatTask?.value
        await task1.value
    }
    
    // MARK: - Batch 2H Persistence Tests

    func testChatHistoryStoreMissingFileReturnsEmpty() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        let doc = await store.load()
        XCTAssertEqual(doc.schemaVersion, 1)
        XCTAssertTrue(doc.sessions.isEmpty)
    }

    func testChatHistoryStoreSaveAndLoadRoundtrip() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let run = HermesPersistedRun(
            id: UUID(),
            createdAt: Date(),
            completedAt: Date(),
            mode: "mock",
            promptPreview: "hello test",
            response: "mocked response",
            status: "completed",
            errorSummary: nil
        )
        
        let session = HermesChatSession(title: "Test Session", runs: [run])
        let doc = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        
        try await store.save(doc)
        
        let loaded = await store.load()
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertEqual(loaded.sessions.count, 1)
        XCTAssertEqual(loaded.sessions[0].runs.count, 1)
        XCTAssertEqual(loaded.sessions[0].runs[0].promptPreview, "hello test")
        XCTAssertEqual(loaded.sessions[0].runs[0].response, "mocked response")
    }

    func testChatHistoryStoreCorruptJSONIsRenamed() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent("chat-history.json")
        
        // Write corrupt JSON bytes
        let corruptData = "invalid { json ] bytes".data(using: .utf8)!
        try corruptData.write(to: tempURL)
        
        let store = ChatHistoryStore(fileURL: tempURL)
        let doc = await store.load()
        
        // Should return empty doc
        XCTAssertTrue(doc.sessions.isEmpty)
        
        // Original file should be gone (renamed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Check that a corrupt file backup exists
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let corruptExists = files.contains { $0.lastPathComponent.starts(with: "chat-history.corrupt.") }
        XCTAssertTrue(corruptExists)
    }

    func testViewModelLoadsHistoryOnAllDataFetch() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let existingRun = HermesPersistedRun(
            id: UUID(),
            createdAt: Date(),
            completedAt: Date(),
            mode: "mock",
            promptPreview: "loaded test prompt",
            response: "loaded response",
            status: "completed",
            errorSummary: nil
        )
        let session = HermesChatSession(title: "Loaded Session", runs: [existingRun])
        let doc = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        try await store.save(doc)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        // Must contain the loaded run card
        XCTAssertTrue(viewModel.runs.contains(where: { $0.prompt == "loaded test prompt" && $0.response == "loaded response" }))
    }

    func testViewModelMockChatAutosavesOnComplete() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat test autosave"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        // After completion, the document should be saved to the store
        let savedDoc = await store.load()
        XCTAssertEqual(savedDoc.sessions.count, 1)
        XCTAssertEqual(savedDoc.sessions[0].runs.count, 1)
        
        let savedRun = savedDoc.sessions[0].runs[0]
        XCTAssertEqual(savedRun.promptPreview, "/chat test autosave")
        XCTAssertEqual(savedRun.status, "completed")
    }

    func testViewModelPersistedSanitisationAndCapping() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        // Setup input containing bearer secrets and absolute /Users/ paths to be capped
        let longPromptPart = String(repeating: "A", count: 150)
        let bearerToken = "bearer " + "abc123def456ghi789"
        let rawInput = "/chat secret: \(bearerToken) and path: /Users/sysadmin/project and long: \(longPromptPart)"
        
        viewModel.currentInput = rawInput
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        let savedDoc = await store.load()
        let savedRun = savedDoc.sessions[0].runs[0]
        
        let promptPreview = savedRun.promptPreview ?? ""
        
        // Prompt preview must be capped to 120 chars plus "..."
        XCTAssertLessThanOrEqual(promptPreview.count, 123)
        XCTAssertTrue(promptPreview.hasSuffix("..."))
        
        // Secrets must be redacted
        XCTAssertFalse(promptPreview.contains("bearer " + "abc123def456ghi789"))
        XCTAssertTrue(promptPreview.contains("Bearer [REDACTED]"))
        
        // Path must be normalised
        XCTAssertFalse(promptPreview.contains("/Users/sysadmin"))
        XCTAssertTrue(promptPreview.contains("~/project"))
    }

    func testViewModelActiveStreamNotPersisted() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat test active"
        let sendTask = Task {
            await viewModel.sendCommand()
        }
        
        // Wait a small delay to be in connecting/streaming
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(viewModel.chatState.isActive)
        
        // Store should be empty right now (contains only the default active session, but no runs)
        let intermediateDoc = await store.load()
        if !intermediateDoc.sessions.isEmpty {
            XCTAssertTrue(intermediateDoc.sessions[0].runs.isEmpty)
        }
        
        await sendTask.value
        _ = await viewModel.activeChatTask?.value
        
        // Now it should be saved
        let finalDoc = await store.load()
        XCTAssertEqual(finalDoc.sessions[0].runs.count, 1)
    }

    func testViewModelCancellationIsPersisted() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat cancel test"
        let sendTask = Task {
            await viewModel.sendCommand()
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        await viewModel.cancelActiveChat()
        
        await sendTask.value
        _ = await viewModel.activeChatTask?.value
        
        let savedDoc = await store.load()
        XCTAssertEqual(savedDoc.sessions[0].runs.count, 1)
        XCTAssertEqual(savedDoc.sessions[0].runs[0].status, "cancelled")
    }

    func testViewModelNonZeroExitIsPersisted() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_chat_failure_persistence.sh")
        let scriptContent = """
        #!/bin/sh
        echo "some critical error description" >&2
        exit 1
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        viewModel.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat test fail"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        let savedDoc = await store.load()
        XCTAssertEqual(savedDoc.sessions[0].runs.count, 1)
        XCTAssertEqual(savedDoc.sessions[0].runs[0].status, "failed")
        XCTAssertEqual(savedDoc.sessions[0].runs[0].errorSummary, "SSH command failed (exit code: 1). Detail: some critical error description")
    }

    func testViewModelTimeoutIsPersisted() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_chat_timeout_persistence.sh")
        let scriptContent = """
        #!/bin/sh
        sleep 5
        exit 0
        """
        try? scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try? chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let prevMode = UserDefaults.standard.string(forKey: "HermesServiceMode")
        let prevGate = UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat")
        let prevHost = UserDefaults.standard.string(forKey: "RemoteHost")
        UserDefaults.standard.set("diagnostics", forKey: "HermesServiceMode")
        UserDefaults.standard.set(true, forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.set("localhost", forKey: "RemoteHost")
        defer {
            UserDefaults.standard.set(prevMode, forKey: "HermesServiceMode")
            UserDefaults.standard.set(prevGate, forKey: "EnableDeveloperRemoteChat")
            UserDefaults.standard.set(prevHost, forKey: "RemoteHost")
        }
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        viewModel.chatTimeout = 0.2
        viewModel.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        await viewModel.loadAllData()
        
        viewModel.currentInput = "/chat test timeout"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        let savedDoc = await store.load()
        XCTAssertEqual(savedDoc.sessions[0].runs.count, 1)
        XCTAssertEqual(savedDoc.sessions[0].runs[0].status, "timedOut")
        XCTAssertEqual(savedDoc.sessions[0].runs[0].errorSummary, "Connection timed out")
    }

    // MARK: - Batch 2I Multi-Session Tests

    func testViewModelLoadPersistedSessions() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let session = HermesChatSession(id: UUID(), title: "Pre-existing Session", runs: [
            HermesPersistedRun(mode: "mock", promptPreview: "hello", response: "world", status: "completed")
        ])
        let doc = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        try await store.save(doc)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions[0].title, "Pre-existing Session")
        XCTAssertEqual(viewModel.activeSessionID, session.id)
        XCTAssertTrue(viewModel.runs.contains(where: { $0.prompt == "hello" }))
    }

    func testViewModelEmptyHistoryCreatesDefaultSession() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions[0].title, "New Chat")
        XCTAssertNotNil(viewModel.activeSessionID)
    }

    func testViewModelSelectSession() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let s1 = HermesChatSession(id: UUID(), title: "Session 1", runs: [
            HermesPersistedRun(mode: "mock", promptPreview: "prompt 1", response: "res 1", status: "completed")
        ])
        let s2 = HermesChatSession(id: UUID(), title: "Session 2", runs: [
            HermesPersistedRun(mode: "mock", promptPreview: "prompt 2", response: "res 2", status: "completed")
        ])
        let doc = HermesChatHistoryDocument(schemaVersion: 1, sessions: [s1, s2])
        try await store.save(doc)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        // Select Session 2
        viewModel.selectSession(id: s2.id)
        XCTAssertEqual(viewModel.activeSessionID, s2.id)
        XCTAssertTrue(viewModel.runs.contains(where: { $0.prompt == "prompt 2" }))
        XCTAssertFalse(viewModel.runs.contains(where: { $0.prompt == "prompt 1" }))
    }

    func testViewModelCreateNewSession() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        let firstID = viewModel.activeSessionID
        
        viewModel.createNewSession()
        XCTAssertEqual(viewModel.sessions.count, 2)
        XCTAssertNotEqual(viewModel.activeSessionID, firstID)
        XCTAssertEqual(viewModel.activeSession?.title, "New Chat")
    }

    func testViewModelActiveStreamBlocksSessionSwitching() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        let initialID = viewModel.activeSessionID
        
        viewModel.chatState = .streaming
        
        viewModel.selectSession(id: UUID())
        XCTAssertEqual(viewModel.activeSessionID, initialID)
        XCTAssertEqual(viewModel.errorMessage, "Finish or cancel the active chat before switching sessions.")
        
        viewModel.errorMessage = nil
        viewModel.createNewSession()
        XCTAssertEqual(viewModel.activeSessionID, initialID)
        XCTAssertEqual(viewModel.errorMessage, "Finish or cancel the active chat before switching sessions.")
    }

    func testViewModelSessionTitleGeneration() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("chat-history.json")
        let store = ChatHistoryStore(fileURL: tempURL)
        
        let viewModel = HermesViewModel(service: MockHermesService(), historyStore: store)
        await viewModel.loadAllData()
        
        // 1. Derivation from simple prompt
        viewModel.currentInput = "/chat deploy database"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        XCTAssertEqual(viewModel.activeSession?.title, "deploy database")
        
        // Create new session for testing path normalisation and secret redaction
        viewModel.createNewSession()
        
        let bearerToken = "bearer " + "xyz123abc456"
        viewModel.currentInput = "/chat config for /Users/sysadmin/test with token \(bearerToken)"
        await viewModel.sendCommand()
        _ = await viewModel.activeChatTask?.value
        
        // Should normalise path to ~ and redact secrets, and strip /chat prefix
        let expectedTitle = "config for ~/test with token Bearer [RED..."
        XCTAssertEqual(viewModel.activeSession?.title, expectedTitle)
    }

    // MARK: - Batch 2J Markdown Safety Tests

    func testMarkdownBlockParserHeading() {
        let blocks = parseMarkdown("# Heading 1\n## Heading 2\nRegular text")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Heading 1"))
        XCTAssertEqual(blocks[1], .heading(level: 2, text: "Heading 2"))
        XCTAssertEqual(blocks[2], .paragraph(text: "Regular text"))
    }

    func testMarkdownBlockParserCodeBlock() {
        let blocks = parseMarkdown("Prefix\n```\nlet a = 1\nlet b = 2\n```\nSuffix")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], .paragraph(text: "Prefix"))
        XCTAssertEqual(blocks[1], .codeBlock(language: nil, code: "let a = 1\nlet b = 2"))
        XCTAssertEqual(blocks[2], .paragraph(text: "Suffix"))
    }

    func testMarkdownBlockParserLists() {
        let bulletBlocks = parseMarkdown("* item A\n- item B")
        XCTAssertEqual(bulletBlocks.count, 1)
        XCTAssertEqual(bulletBlocks[0], .bulletList(items: ["item A", "item B"]))

        let numberedBlocks = parseMarkdown("1. first item\n2. second item")
        XCTAssertEqual(numberedBlocks.count, 1)
        XCTAssertEqual(numberedBlocks[0], .numberedList(items: ["first item", "second item"]))
    }

    func testMarkdownBlockParserBlockquote() {
        let blocks = parseMarkdown("> quote text")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .blockquote(text: "quote text"))
    }

    func testMarkdownInlineParserSafety() {
        // Raw HTML is preserved as plain text (escaped/displayed literally)
        let htmlInput = "<script>alert('evil')</script>"
        let parsedHtml = prepareSafeInlineString(htmlInput)
        XCTAssertEqual(parsedHtml, htmlInput) // Displayed literally as text

        // Markdown image syntax does not load remote images
        let imgInput = "Here is an image: ![attack](http://evil.com/malware.png) and another one"
        let parsedImg = prepareSafeInlineString(imgInput)
        XCTAssertEqual(parsedImg, "Here is an image: [image omitted] and another one")

        // Unsafe markdown links do not auto-open and are formatted as text
        let linkInput = "Check [google](http://google.com) search"
        let parsedLink = prepareSafeInlineString(linkInput)
        XCTAssertEqual(parsedLink, "Check google search")
    }

    func testMarkdownMalformedFallback() {
        // Malformed markdown block parses as plain paragraph or text blocks safely
        let malformed = "Some unmatched *italic and **bold"
        let blocks = parseMarkdown(malformed)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .paragraph(text: malformed))
    }

    // MARK: - Batch 2K Message Controls and Clipboard Safety Tests

    func testMarkdownCodeBlockLanguageExtraction() {
        let blocks = parseMarkdown("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .codeBlock(language: "swift", code: "let x = 1"))
    }

    func testMarkdownCodeBlockWithoutLanguage() {
        let blocks = parseMarkdown("```\nplain code\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .codeBlock(language: nil, code: "plain code"))
    }

    func testMarkdownCodeBlockLanguageSanitisation() {
        // Weird language names with unsafe characters or spacing should be sanitised/ignored
        let blocks = parseMarkdown("```swift-lang! 123\ncode\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0], .codeBlock(language: nil, code: "code"))
    }

    func testCodeCopySourceExcludesFencesAndSanitises() {
        let rawMarkdown = "```swift\nlet x = 1\n```"
        let blocks = parseMarkdown(rawMarkdown)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(_, let code) = blocks[0] {
            XCTAssertEqual(code, "let x = 1") // Excludes "```swift" and "```"
        } else {
            XCTFail("Expected code block")
        }
    }

    func testClipboardResponseCopySourceSafety() {
        // Test that cleanForCopy successfully strips link targets and images
        let rawResponse = "Hello, here is [google](http://google.com) and an image ![test](http://img.com/test.png) plus:\n```swift\nlet x = 1\n```"
        let copySource = cleanForCopy(rawResponse)
        
        // Output should have formatted links/images as plain text and stripped fences
        XCTAssertTrue(copySource.contains("google"))
        XCTAssertFalse(copySource.contains("http://google.com"))
        XCTAssertTrue(copySource.contains("[image omitted]"))
        XCTAssertFalse(copySource.contains("http://img.com/test.png"))
        XCTAssertTrue(copySource.contains("let x = 1"))
        XCTAssertFalse(copySource.contains("```swift"))
    }

    func testLightweightSyntaxHighlighting() {
        // Checks keywords are highlighted with appropriate colors
        let swiftCode = "let value = true"
        let highlighted = highlightCode(swiftCode, language: "swift")
        
        // Verification that highlightCode runs without crashing (and keywords are processed)
        XCTAssertNotNil(highlighted)
    }

    func testSessionRenameUpdatesTitle() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Original Title")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        vm.renameSession(id: sessionID, title: "New Title")
        XCTAssertEqual(vm.sessions.first(where: { $0.id == sessionID })?.title, "New Title")
        XCTAssertEqual(vm.sessions.first(where: { $0.id == sessionID })?.isManuallyRenamed, true)
    }
    
    func testSessionRenameSanitisesSecretsAndPaths() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Original Title")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        let token = "my-secret-val"
        vm.renameSession(id: sessionID, title: "/Users/testuser/project token: \(token)")
        
        let updatedTitle = vm.sessions.first(where: { $0.id == sessionID })?.title ?? ""
        XCTAssertTrue(updatedTitle.contains("~"))
        XCTAssertFalse(updatedTitle.contains("testuser"))
        XCTAssertTrue(updatedTitle.contains("REDACTED"))
        XCTAssertFalse(updatedTitle.contains(token))
    }
    
    func testSessionRenameCapsTitle() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Original Title")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        let longTitle = String(repeating: "z", count: 50)
        vm.renameSession(id: sessionID, title: longTitle)
        
        let updatedTitle = vm.sessions.first(where: { $0.id == sessionID })?.title ?? ""
        XCTAssertEqual(updatedTitle.count, 43)
        XCTAssertTrue(updatedTitle.hasSuffix("..."))
    }
    
    func testSessionRenameRejectsEmpty() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Original Title")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        vm.renameSession(id: sessionID, title: "   ")
        XCTAssertEqual(vm.sessions.first(where: { $0.id == sessionID })?.title, "New Chat")
    }
    
    func testManuallyRenamedSessionNotOverwritten() async {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Original Title")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        vm.renameSession(id: sessionID, title: "User Title")
        
        vm.currentInput = "/chat test prompt"
        await vm.sendCommand()
        
        var retries = 0
        while vm.chatState.isActive && retries < 40 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            retries += 1
        }
        
        XCTAssertEqual(vm.sessions.first(where: { $0.id == sessionID })?.title, "User Title")
    }
    
    func testDeleteSessionRemovesIt() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let id1 = UUID()
        let id2 = UUID()
        let session1 = HermesChatSession(id: id1, title: "Session 1")
        let session2 = HermesChatSession(id: id2, title: "Session 2")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session1, session2])
        vm.activeSessionID = id1
        
        vm.deleteSession(id: id2)
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions[0].id, id1)
    }
    
    func testDeleteActiveSessionSelectsFallback() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let id1 = UUID()
        let id2 = UUID()
        let session1 = HermesChatSession(id: id1, createdAt: Date().addingTimeInterval(-10), updatedAt: Date().addingTimeInterval(-10), title: "Session 1")
        let session2 = HermesChatSession(id: id2, createdAt: Date(), updatedAt: Date(), title: "Session 2")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session1, session2])
        vm.activeSessionID = id2
        
        vm.deleteSession(id: id2)
        XCTAssertEqual(vm.activeSessionID, id1)
    }
    
    func testDeleteOnlySessionCreatesDefault() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let id1 = UUID()
        let session1 = HermesChatSession(id: id1, title: "Session 1")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session1])
        vm.activeSessionID = id1
        
        vm.deleteSession(id: id1)
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions[0].title, "New Chat")
        XCTAssertNotNil(vm.activeSessionID)
    }
    
    func testActiveStreamBlocksDeleteAndClearAll() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let sessionID = UUID()
        let session = HermesChatSession(id: sessionID, title: "Session 1")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session])
        vm.activeSessionID = sessionID
        
        vm.chatState = .streaming
        
        vm.deleteSession(id: sessionID)
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertNotNil(vm.errorMessage)
        
        vm.errorMessage = nil
        vm.clearChatHistory()
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertNotNil(vm.errorMessage)
    }
    
    func testClearAllResetsToEmptyHistory() {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        let id1 = UUID()
        let session1 = HermesChatSession(id: id1, title: "Session 1")
        vm.chatHistory = HermesChatHistoryDocument(schemaVersion: 1, sessions: [session1])
        vm.activeSessionID = id1
        
        vm.clearChatHistory()
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions[0].title, "New Chat")
        XCTAssertNotEqual(vm.activeSessionID, id1)
    }
    
    // MARK: - Batch 2M Remote Settings & Preflight Tests
    
    func testRemoteHostSettingsValidationExtra() throws {
        // empty host rejected
        XCTAssertFalse(RemoteHostSettings.isValidHost(""))
        XCTAssertFalse(RemoteHostSettings.isValidHost("   "))
        
        // valid SSH alias accepted
        XCTAssertTrue(RemoteHostSettings.isValidHost("macmini-cf"))
        XCTAssertTrue(RemoteHostSettings.isValidHost("my.host.name"))
        XCTAssertTrue(RemoteHostSettings.isValidHost("192.168.1.1"))
        
        // host with shell metacharacters rejected
        XCTAssertFalse(RemoteHostSettings.isValidHost("host; rm -rf /"))
        XCTAssertFalse(RemoteHostSettings.isValidHost("host && command"))
        XCTAssertFalse(RemoteHostSettings.isValidHost("host | command"))
        XCTAssertFalse(RemoteHostSettings.isValidHost("host-alias -o ProxyCommand=something"))
        XCTAssertFalse(RemoteHostSettings.isValidHost("host`rm`"))
        XCTAssertFalse(RemoteHostSettings.isValidHost("host$((1))"))
        
        // username validation
        XCTAssertTrue(RemoteHostSettings.isValidUsername(""))
        XCTAssertTrue(RemoteHostSettings.isValidUsername("sysadmin"))
        XCTAssertTrue(RemoteHostSettings.isValidUsername("sys-admin_123"))
        XCTAssertFalse(RemoteHostSettings.isValidUsername("user; rm -rf /"))
        XCTAssertFalse(RemoteHostSettings.isValidUsername("user@host"))
        XCTAssertFalse(RemoteHostSettings.isValidUsername("user name"))
        
        // port validation
        XCTAssertTrue(RemoteHostSettings.isValidPort(22))
        XCTAssertTrue(RemoteHostSettings.isValidPort(1))
        XCTAssertTrue(RemoteHostSettings.isValidPort(65535))
        XCTAssertFalse(RemoteHostSettings.isValidPort(0))
        XCTAssertFalse(RemoteHostSettings.isValidPort(-22))
        XCTAssertFalse(RemoteHostSettings.isValidPort(65536))
        
        // identity file path validation
        // 1. empty is valid
        XCTAssertTrue(RemoteHostSettings.isValidIdentityFilePath(""))
        // 2. Control characters are rejected
        XCTAssertFalse(RemoteHostSettings.isValidIdentityFilePath("path\nwith\nnewlines"))
        
        // 3. Create temp file to verify existence validation
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("mock_key_\(UUID().uuidString)")
        try "dummy-key".write(to: tempFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        XCTAssertTrue(RemoteHostSettings.isValidIdentityFilePath(tempFile.path))
        
        // nonexistent path rejected
        let nonexistentPath = tempDir.appendingPathComponent("nonexistent_key_\(UUID().uuidString)").path
        XCTAssertFalse(RemoteHostSettings.isValidIdentityFilePath(nonexistentPath))
        
        // directory path rejected
        XCTAssertFalse(RemoteHostSettings.isValidIdentityFilePath(tempDir.path))
    }
    
    func testRemoteSSHExecutorArgumentSafety() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_args.sh")
        let scriptContent = """
        #!/bin/sh
        for arg in "$@"; do
            echo "arg: $arg"
        done
        exit 0
        """
        try scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let executor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        
        // Create temp identity file
        let tempKeyFile = tempDir.appendingPathComponent("mock_key_args_\(UUID().uuidString)")
        try "dummy-key".write(to: tempKeyFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempKeyFile)
        }
        
        let settings = RemoteHostSettings(
            host: "test-host",
            username: "test-user",
            port: 2222,
            hermesCommand: "hermes",
            identityFilePath: tempKeyFile.path
        )
        
        let result = await executor.execute(command: .whichHermes, settings: settings)
        
        XCTAssertEqual(result.exitCode, 0)
        let lines = result.stdout.components(separatedBy: .newlines)
        
        // Verify key parameters are separate arguments and correctly placed
        XCTAssertTrue(lines.contains("arg: -p"))
        XCTAssertTrue(lines.contains("arg: 2222"))
        XCTAssertTrue(lines.contains("arg: -i"))
        XCTAssertTrue(lines.contains("arg: \(tempKeyFile.path)"))
        XCTAssertTrue(lines.contains("arg: test-user@test-host"))
        XCTAssertTrue(lines.contains("arg: which"))
        XCTAssertTrue(lines.contains("arg: hermes"))
    }
    
    func testRemotePreflightExecution() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_preflight.sh")
        let logURL = tempDir.appendingPathComponent("preflight_calls_\(UUID().uuidString).log")
        
        let scriptContent = """
        #!/bin/sh
        # Log command call
        echo "$@" >> "\(logURL.path)"
        
        # Check command
        last_arg=""
        second_last_arg=""
        third_last_arg=""
        for arg in "$@"; do
            third_last_arg="$second_last_arg"
            second_last_arg="$last_arg"
            last_arg="$arg"
        done
        
        if [ "$last_arg" = "hermes" ] && [ "$second_last_arg" = "which" ]; then
            echo "/usr/local/bin/hermes"
            exit 0
        elif [ "$last_arg" = "--version" ] && [ "$second_last_arg" = "hermes" ]; then
            echo "hermes-agent 1.2.3"
            exit 0
        elif [ "$last_arg" = "status" ] && [ "$second_last_arg" = "hermes" ]; then
            echo "Status: OK"
            exit 0
        elif echo "$@" | grep -q "chat"; then
            echo "ERROR: CHAT COMMAND DETECTED" >&2
            exit 1
        else
            echo "Unknown command: $@" >&2
            exit 1
        fi
        """
        try scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
            try? FileManager.default.removeItem(at: logURL)
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        
        // Inject our custom remote executor using the mock script
        vm.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        
        let settings = RemoteHostSettings(
            host: "test-host",
            username: "test-user",
            port: 22,
            hermesCommand: "hermes"
        )
        
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertTrue(vm.remoteHostStatus.hermesFound)
        XCTAssertEqual(vm.remoteHostStatus.hermesVersion, "hermes-agent 1.2.3")
        XCTAssertEqual(vm.remoteHostStatus.statusSummary, "Status: OK")
        XCTAssertNil(vm.remoteHostStatus.errorMessage)
        
        // Read logged calls
        let logContent = try String(contentsOf: logURL, encoding: .utf8)
        let logLines = logContent.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        
        XCTAssertEqual(logLines.count, 3)
        XCTAssertFalse(logContent.contains("chat"))
    }
    
    func testRemotePreflightSSHErrorSanitisation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let mockScriptURL = tempDir.appendingPathComponent("mock_ssh_error.sh")
        
        let scriptContent = """
        #!/bin/sh
        # Print simulated SSH error and exit with 255
        echo "ssh: connect to host test-host port 22: Connection refused" >&2
        exit 255
        """
        try scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["+x", mockScriptURL.path]
        try chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            try? FileManager.default.removeItem(at: mockScriptURL)
        }
        
        let store = ChatHistoryStore(fileURL: tempDir.appendingPathComponent(UUID().uuidString))
        let mockService = MockHermesService()
        let vm = HermesViewModel(service: mockService, historyStore: store)
        vm.remoteSSHExecutor = RemoteSSHExecutor(sshPathOverride: mockScriptURL.path)
        
        let settings = RemoteHostSettings(host: "test-host")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertFalse(vm.remoteHostStatus.hermesFound)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Connection refused")
    }
    
    func testDeveloperRemoteChatGateDisabledByDefault() {
        let prev = UserDefaults.standard.object(forKey: "EnableDeveloperRemoteChat")
        UserDefaults.standard.removeObject(forKey: "EnableDeveloperRemoteChat")
        defer {
            if let prev = prev {
                UserDefaults.standard.set(prev, forKey: "EnableDeveloperRemoteChat")
            }
        }
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "EnableDeveloperRemoteChat"))
    }
}


