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
        // All four allowlisted commands must be present
        let allCommands = RemoteHermesCommand.allCases
        XCTAssertTrue(allCommands.contains(.whichHermes))
        XCTAssertTrue(allCommands.contains(.hermesVersion))
        XCTAssertTrue(allCommands.contains(.hermesStatus))
        XCTAssertTrue(allCommands.contains(.hermesChat))
        XCTAssertEqual(allCommands.count, 4)
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
        
        XCTAssertEqual(viewModel.runs.count, initialRunsCount)
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
        viewModel.cancelActiveChat()
        
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
        viewModel.cancelActiveChat()
        _ = await viewModel.activeChatTask?.value
        await task1.value
    }
}


