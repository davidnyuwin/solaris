import XCTest
@testable import HermesCompanion

final class MockRemoteCommandRunnerTests: XCTestCase {
    
    func testMockRunnerSuccess() async {
        let runner = MockRemoteCommandRunner()
        let settings = RemoteHostSettings(host: "localhost")
        
        let whichResult = await runner.execute(command: .whichHermes, settings: settings, timeout: 8, stdinData: nil)
        XCTAssertEqual(whichResult.exitCode, 0)
        XCTAssertEqual(whichResult.stdout, "/usr/local/bin/hermes")
        
        let versionResult = await runner.execute(command: .hermesVersion, settings: settings, timeout: 8, stdinData: nil)
        XCTAssertEqual(versionResult.exitCode, 0)
        XCTAssertEqual(versionResult.stdout, "hermes-agent 1.2.3")
        
        let statusResult = await runner.execute(command: .hermesStatus, settings: settings, timeout: 8, stdinData: nil)
        XCTAssertEqual(statusResult.exitCode, 0)
        XCTAssertEqual(statusResult.stdout, "Status: OK")
    }
    
    func testMockRunnerFailure() async {
        let runner = MockRemoteCommandRunner()
        runner.shouldFail = true
        runner.customStderr = "Simulated error"
        let settings = RemoteHostSettings(host: "localhost")
        
        let result = await runner.execute(command: .whichHermes, settings: settings, timeout: 8, stdinData: nil)
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, "Simulated error")
        XCTAssertEqual(result.stdout, "")
    }
    
    func testMockRunnerTimeout() async {
        let runner = MockRemoteCommandRunner()
        runner.shouldTimeout = true
        let settings = RemoteHostSettings(host: "localhost")
        
        let result = await runner.execute(command: .whichHermes, settings: settings, timeout: 8, stdinData: nil)
        XCTAssertEqual(result.exitCode, -1)
        XCTAssertTrue(result.timedOut)
    }
    
    func testMockRunnerStreaming() async {
        let runner = MockRemoteCommandRunner()
        let settings = RemoteHostSettings(host: "localhost")
        
        var receivedStdout = ""
        var completed = false
        
        let stream = runner.executeStreaming(command: .hermesStatus, settings: settings, timeout: 8, stdinData: nil)
        for await event in stream {
            switch event {
            case .stdout(let text):
                receivedStdout += text
            case .completed(let code):
                XCTAssertEqual(code, 0)
                completed = true
            default:
                break
            }
        }
        
        XCTAssertTrue(completed)
        XCTAssertEqual(receivedStdout, "Status: OK\n")
    }
    
    @MainActor
    func testViewModelTestConnectionMockSuccess() async {
        // Set mock mode in UserDefaults
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let settings = RemoteHostSettings(host: "success.local")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertNil(vm.remoteHostStatus.errorMessage)
        XCTAssertEqual(vm.remoteHostStatus.hermesVersion, "hermes-agent 1.2.3")
        XCTAssertEqual(vm.remoteHostStatus.statusSummary, "Status: OK")
        XCTAssertEqual(vm.remoteHostStatus.state, .connected)
        XCTAssertEqual(vm.remoteHostStatus.preflightDiagnostic?.status, .pass)
    }
    
    @MainActor
    func testViewModelTestConnectionMockFailure() async {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let settings = RemoteHostSettings(host: "fail.local")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Remote command check failed. Review the diagnostic details below.")
        XCTAssertEqual(vm.remoteHostStatus.state, .failed("Remote command check failed. Review the diagnostic details below."))
        // Preflight remains passDiag so UI can show it passed
        XCTAssertEqual(vm.remoteHostStatus.preflightDiagnostic?.status, .pass)
    }
    
    @MainActor
    func testViewModelTestConnectionMockTimeout() async {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let settings = RemoteHostSettings(host: "timeout.local")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Timed out")
        XCTAssertEqual(vm.remoteHostStatus.state, .failed("Timed out"))
        XCTAssertEqual(vm.remoteHostStatus.preflightDiagnostic?.status, .pass)
    }
}
