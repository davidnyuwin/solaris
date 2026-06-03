import Foundation

public final class SSHPreflightService: Sendable {
    private let sshAddPath: String
    private let environment: [String: String]?

    public init(sshAddPath: String = "/usr/bin/ssh-add", environment: [String: String]? = nil) {
        self.sshAddPath = sshAddPath
        self.environment = environment
    }

    public enum AgentState {
        case unreachable(String)
        case empty
        case loaded([String])
    }

    /// Evaluates the local SSH agent and key parameters, returning a structured diagnostic
    /// warning/failure if something is misconfigured or not ready.
    public func performPreflightChecks(settings: RemoteHostSettings) async -> SSHPreflightDiagnostic? {
        let keyPath = settings.identityFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. If key is specified, validate path safety, file existence, and readability.
        if !keyPath.isEmpty {
            let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: " ;|&`$<>()[]{}#'\"!\\\\"))
            guard keyPath.rangeOfCharacter(from: forbidden) == nil else {
                return SSHPreflightDiagnostic(
                    status: .fail,
                    title: "Forbidden Path Characters",
                    message: "The key file path contains unsafe or forbidden characters.",
                    actionGuide: "Use standard directories (e.g. ~/.ssh/)"
                )
            }
            
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: keyPath, isDirectory: &isDir)
            guard exists && !isDir.boolValue else {
                return SSHPreflightDiagnostic(
                    status: .fail,
                    title: "Key File Missing",
                    message: "The selected identity key file does not exist at the given path.",
                    actionGuide: "Check path: \(keyPath)"
                )
            }
            
            guard FileManager.default.isReadableFile(atPath: keyPath) else {
                return SSHPreflightDiagnostic(
                    status: .fail,
                    title: "Key File Unreadable",
                    message: "Access to the private key file was denied. macOS sandboxing prevents reading files outside user-selected paths.",
                    actionGuide: "Click 'Browse...' to grant access"
                )
            }
        }
        
        // 2. Query the local ssh-agent status
        let agentState = await querySSHAgent()
        
        switch agentState {
        case .unreachable(let reason):
            // If agent is dead and no key is selected, we have no credentials to offer.
            if keyPath.isEmpty {
                return SSHPreflightDiagnostic(
                    status: .warning,
                    title: "SSH Agent Unreachable",
                    message: "Solaris cannot contact your local ssh-agent (\(reason)). Batch mode connection may fail.",
                    actionGuide: "Ensure SSH_AUTH_SOCK is active"
                )
            }
            
        case .empty:
            // Agent is running but holds no keys.
            if keyPath.isEmpty {
                return SSHPreflightDiagnostic(
                    status: .warning,
                    title: "No Keys in SSH Agent",
                    message: "No identities are currently loaded in ssh-agent. Batch mode connection may fail.",
                    actionGuide: "Run: ssh-add /path/to/key"
                )
            } else {
                // Key specified, let's check if it needs a passphrase
                if Self.isPrivateKeyEncrypted(atPath: keyPath) {
                    return SSHPreflightDiagnostic(
                        status: .warning,
                        title: "Passphrase Required",
                        message: "This private key is encrypted and requires a passphrase. Solaris runs SSH in non-interactive batch mode.",
                        actionGuide: "Load key into agent: ssh-add \(URL(fileURLWithPath: keyPath).lastPathComponent)"
                    )
                }
            }
            
        case .loaded(let loadedPaths):
            // Agent has keys! If key is specified, verify it is loaded in the agent if it is encrypted.
            if !keyPath.isEmpty {
                let selectedFilename = URL(fileURLWithPath: keyPath).lastPathComponent
                let isLoaded = loadedPaths.contains { loaded in
                    loaded == keyPath || URL(fileURLWithPath: loaded).lastPathComponent == selectedFilename
                }
                
                if !isLoaded && Self.isPrivateKeyEncrypted(atPath: keyPath) {
                    return SSHPreflightDiagnostic(
                        status: .warning,
                        title: "Passphrase Required",
                        message: "This private key is encrypted and requires a passphrase. Solaris runs SSH in non-interactive batch mode.",
                        actionGuide: "Load key into agent: ssh-add \(selectedFilename)"
                    )
                }
            }
        }
        
        // Everything checks out locally!
        return nil
    }

    // MARK: - Local Subprocess Queries

    private func querySSHAgent() async -> AgentState {
        // If an environment override exists, make sure SSH_AUTH_SOCK is present.
        if let env = environment, env["SSH_AUTH_SOCK"] == nil {
            return .unreachable("SSH_AUTH_SOCK environment variable is missing.")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sshAddPath)
        process.arguments = ["-l"]
        if let env = environment {
            process.environment = env
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let status = process.terminationStatus
            
            // Read pipes safely
            let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if status == 0 {
                let lines = stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
                // ssh-add -l output line structure: "2048 SHA256:... /path/to/key (RSA)"
                let loadedKeys = lines.compactMap { line -> String? in
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    return parts.count >= 3 ? parts[2] : nil
                }
                return .loaded(loadedKeys)
            } else if status == 1 {
                return .empty
            } else {
                return .unreachable(stderr.isEmpty ? "ssh-add exited with status \(status)" : stderr)
            }
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }

    // MARK: - Key Encryption Detection

    public static func isPrivateKeyEncrypted(atPath path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else {
            return false
        }
        guard let contents = String(data: data.prefix(512), encoding: .utf8) else {
            return false
        }
        
        if contents.contains("ENCRYPTED") || contents.contains("DEK-Info") {
            return true
        }
        
        if contents.contains("BEGIN OPENSSH PRIVATE KEY") {
            return isOpenSSHPrivateKeyEncrypted(data: data)
        }
        
        return false
    }

    private static func isOpenSSHPrivateKeyEncrypted(data: Data) -> Bool {
        guard let contents = String(data: data, encoding: .utf8) else { return false }
        let clean = contents
            .replacingOccurrences(of: "-----BEGIN OPENSSH PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END OPENSSH PRIVATE KEY-----", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        guard let decoded = Data(base64Encoded: clean) else { return false }
        
        // "openssh-key-v1" length is 15 (including trailing null byte)
        let magic = "openssh-key-v1\0".data(using: .utf8)!
        guard decoded.count > 30, decoded.prefix(magic.count) == magic else {
            return false
        }
        
        var offset = magic.count
        
        // Read ciphername length
        guard offset + 4 <= decoded.count else { return false }
        let cipherLen = Int(decoded[offset]) << 24 | Int(decoded[offset+1]) << 16 | Int(decoded[offset+2]) << 8 | Int(decoded[offset+3])
        offset += 4
        
        guard offset + cipherLen <= decoded.count else { return false }
        let cipherData = decoded[offset..<(offset + cipherLen)]
        guard let cipherName = String(data: cipherData, encoding: .utf8) else { return false }
        offset += cipherLen
        
        // Read kdfname length
        guard offset + 4 <= decoded.count else { return false }
        let kdfLen = Int(decoded[offset]) << 24 | Int(decoded[offset+1]) << 16 | Int(decoded[offset+2]) << 8 | Int(decoded[offset+3])
        offset += 4
        
        guard offset + kdfLen <= decoded.count else { return false }
        let kdfData = decoded[offset..<(offset + kdfLen)]
        guard let kdfName = String(data: kdfData, encoding: .utf8) else { return false }
        
        return !(cipherName == "none" && kdfName == "none")
    }
}
