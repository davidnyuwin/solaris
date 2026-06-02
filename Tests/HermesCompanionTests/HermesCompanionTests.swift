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
}

