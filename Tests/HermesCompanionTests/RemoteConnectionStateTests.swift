import XCTest
@testable import HermesCompanion

final class RemoteConnectionStateTests: XCTestCase {
    
    @MainActor
    func testValidationFailureStateTransition() async {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let invalidHostSettings = RemoteHostSettings(host: "invalid; host")
        await vm.testRemoteConnection(settings: invalidHostSettings)
        
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .localValidationFailed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Host cannot contain metacharacters or whitespace.")
    }
    
    @MainActor
    func testPreflightFailureStateTransition() async {
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        // Use an invalid identity file path that fails the existence check
        let settings = RemoteHostSettings(host: "localhost", identityFilePath: "/nonexistent/path/to/key")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .sshPreflightFailed)
        XCTAssertTrue(vm.remoteHostStatus.errorMessage?.contains("does not exist") ?? false)
    }
    
    @MainActor
    func testMockHeartbeatPassedStateTransition() async {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let settings = RemoteHostSettings(host: "success.local")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatPassed)
        XCTAssertNil(vm.remoteHostStatus.errorMessage)
    }
    
    @MainActor
    func testMockHeartbeatFailedStateTransition() async {
        UserDefaults.standard.set(HermesServiceMode.mock.rawValue, forKey: "HermesServiceMode")
        defer {
            UserDefaults.standard.removeObject(forKey: "HermesServiceMode")
        }
        
        let store = ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = HermesViewModel(service: MockHermesService(), historyStore: store)
        
        let settings = RemoteHostSettings(host: "fail.local")
        await vm.testRemoteConnection(settings: settings)
        
        XCTAssertEqual(vm.remoteHostStatus.connectionState, .heartbeatFailed)
        XCTAssertEqual(vm.remoteHostStatus.errorMessage, "Remote command check failed. Review the diagnostic details below.")
    }
    
    func testRemoteConnectionStateCodable() throws {
        let states: [RemoteConnectionState] = [
            .notConfigured,
            .localValidationFailed,
            .sshPreflightFailed,
            .readyToVerify,
            .verifying,
            .heartbeatPassed,
            .heartbeatFailed,
            .liveChecksDisabled
        ]
        
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RemoteConnectionState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
    }
}
