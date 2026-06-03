import XCTest
@testable import HermesCompanion

final class SSHPreflightTests: XCTestCase {
    
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
    
    func testPreflightNoIdentityAgentAvailable() async throws {
        let sshAddPath = try createMockSSHAdd(
            exitCode: 0,
            stdout: "2048 SHA256:abc /Users/dnguyen/.ssh/id_rsa (RSA)",
            stderr: ""
        )
        let service = SSHPreflightService(sshAddPath: sshAddPath)
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: "")
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNil(diag) // should pass
    }
    
    func testPreflightUnsafePath() async throws {
        let service = SSHPreflightService(sshAddPath: "/usr/bin/ssh-add")
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: "key; rm -rf /")
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .fail)
        XCTAssertEqual(diag?.title, "Forbidden Path Characters")
    }
    
    func testPreflightMissingIdentityFile() async throws {
        let service = SSHPreflightService(sshAddPath: "/usr/bin/ssh-add")
        let nonexistentPath = tempDir.appendingPathComponent("nonexistent_key").path
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: nonexistentPath)
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .fail)
        XCTAssertEqual(diag?.title, "Key File Missing")
    }
    
    func testPreflightUnreadableIdentityFile() async throws {
        let keyURL = tempDir.appendingPathComponent("unreadable_key")
        try "dummy-key-content".write(to: keyURL, atomically: true, encoding: .utf8)
        
        // chmod 000
        let chmodProc = Process()
        chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProc.arguments = ["000", keyURL.path]
        try chmodProc.run()
        chmodProc.waitUntilExit()
        
        defer {
            // Restore permissions so we can clean up
            let restoreProc = Process()
            restoreProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
            restoreProc.arguments = ["600", keyURL.path]
            try? restoreProc.run()
            restoreProc.waitUntilExit()
        }
        
        let service = SSHPreflightService(sshAddPath: "/usr/bin/ssh-add")
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: keyURL.path)
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .fail)
        XCTAssertEqual(diag?.title, "Key File Unreadable")
    }
    
    func testPreflightAgentUnavailableNoIdentity() async throws {
        let sshAddPath = try createMockSSHAdd(
            exitCode: 2,
            stdout: "",
            stderr: "Could not open a connection to your authentication agent."
        )
        let service = SSHPreflightService(sshAddPath: sshAddPath)
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: "")
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .warning)
        XCTAssertEqual(diag?.title, "SSH Agent Unreachable")
    }
    
    func testPreflightAgentAvailableEmptyNoIdentity() async throws {
        let sshAddPath = try createMockSSHAdd(
            exitCode: 1,
            stdout: "The agent has no identities.",
            stderr: ""
        )
        let service = SSHPreflightService(sshAddPath: sshAddPath)
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: "")
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .warning)
        XCTAssertEqual(diag?.title, "No Keys in SSH Agent")
    }
    
    func testPreflightEncryptedKeyNotLoaded() async throws {
        // Create an encrypted key file
        let keyURL = tempDir.appendingPathComponent("encrypted_key")
        try "-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: DES-EDE3-CBC\n-----END RSA PRIVATE KEY-----".write(to: keyURL, atomically: true, encoding: .utf8)
        
        let sshAddPath = try createMockSSHAdd(
            exitCode: 1,
            stdout: "The agent has no identities.",
            stderr: ""
        )
        let service = SSHPreflightService(sshAddPath: sshAddPath)
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: keyURL.path)
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNotNil(diag)
        XCTAssertEqual(diag?.status, .warning)
        XCTAssertEqual(diag?.title, "Passphrase Required")
        XCTAssertTrue(diag?.message.contains("encrypted and requires a passphrase") ?? false)
    }
    
    func testPreflightEncryptedKeyLoaded() async throws {
        let keyURL = tempDir.appendingPathComponent("encrypted_key")
        try "-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: DES-EDE3-CBC\n-----END RSA PRIVATE KEY-----".write(to: keyURL, atomically: true, encoding: .utf8)
        
        // ssh-add -l will report this key loaded (by matching filename or full path)
        let sshAddPath = try createMockSSHAdd(
            exitCode: 0,
            stdout: "2048 SHA256:abc \(keyURL.path) (RSA)",
            stderr: ""
        )
        let service = SSHPreflightService(sshAddPath: sshAddPath)
        let settings = RemoteHostSettings(host: "test-host", identityFilePath: keyURL.path)
        
        let diag = await service.performPreflightChecks(settings: settings)
        XCTAssertNil(diag) // should pass since key is loaded in agent
    }
    
    func testOpenSSHPrivateKeyEncryptedParsing() throws {
        // Unencrypted key data (ciphername "none", kdfname "none")
        var unencryptedData = Data("openssh-key-v1\0".utf8)
        unencryptedData.append(contentsOf: [0, 0, 0, 4])
        unencryptedData.append(Data("none".utf8))
        unencryptedData.append(contentsOf: [0, 0, 0, 4])
        unencryptedData.append(Data("none".utf8))
        
        let unencryptedBase64 = unencryptedData.base64EncodedString()
        let unencryptedPEM = "-----BEGIN OPENSSH PRIVATE KEY-----\n\(unencryptedBase64)\n-----END OPENSSH PRIVATE KEY-----"
        
        let unencryptedURL = tempDir.appendingPathComponent("unencrypted_openssh_key")
        try unencryptedPEM.write(to: unencryptedURL, atomically: true, encoding: .utf8)
        
        XCTAssertFalse(SSHPreflightService.isPrivateKeyEncrypted(atPath: unencryptedURL.path))
        
        // Encrypted key data (ciphername "aes256-ctr", kdfname "bcrypt")
        var encryptedData = Data("openssh-key-v1\0".utf8)
        encryptedData.append(contentsOf: [0, 0, 0, 10])
        encryptedData.append(Data("aes256-ctr".utf8))
        encryptedData.append(contentsOf: [0, 0, 0, 6])
        encryptedData.append(Data("bcrypt".utf8))
        
        let encryptedBase64 = encryptedData.base64EncodedString()
        let encryptedPEM = "-----BEGIN OPENSSH PRIVATE KEY-----\n\(encryptedBase64)\n-----END OPENSSH PRIVATE KEY-----"
        
        let encryptedURL = tempDir.appendingPathComponent("encrypted_openssh_key")
        try encryptedPEM.write(to: encryptedURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(SSHPreflightService.isPrivateKeyEncrypted(atPath: encryptedURL.path))
    }
}
