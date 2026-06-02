import Foundation

public enum HermesCLICommand: Sendable {
    case status
    case gatewayStatus

    public var name: String {
        switch self {
        case .status: return "status"
        case .gatewayStatus: return "gatewayStatus"
        }
    }

    public var arguments: [String] {
        switch self {
        case .status:
            return ["-m", "hermes_cli.main", "status"]
        case .gatewayStatus:
            return ["-m", "hermes_cli.main", "gateway", "status"]
        }
    }
}

public struct HermesCLIResult: Sendable {
    public let commandName: String
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let duration: TimeInterval
    public let timedOut: Bool
}

public enum HermesCLIError: Error, LocalizedError {
    case executableNotFound
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "The bundled Python interpreter was not found at /Applications/Hermes Studio.app"
        case .executionFailed(let reason):
            return "CLI execution failed: \(reason)"
        }
    }
}

public final class HermesCLIExecutor: Sendable {
    
    private let defaultPythonPath = "/Applications/Hermes Studio.app/Contents/Resources/python/bin/python3"
    
    public init() {}
    
    public func execute(command: HermesCLICommand, timeout: TimeInterval = 4.0) async throws -> HermesCLIResult {
        let executableURL = URL(fileURLWithPath: defaultPythonPath)
        
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw HermesCLIError.executableNotFound
        }
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = command.arguments
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            // Start a non-blocking background Task to handle process execution timeouts
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }
            
            process.terminationHandler = { proc in
                timeoutTask.cancel()
                
                let duration = Date().timeIntervalSince(startTime)
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                
                let result = HermesCLIResult(
                    commandName: command.name,
                    exitCode: proc.terminationStatus,
                    stdout: stdout,
                    stderr: stderr,
                    duration: duration,
                    timedOut: !timeoutTask.isCancelled
                )
                continuation.resume(returning: result)
            }
            
            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: HermesCLIError.executionFailed(error.localizedDescription))
            }
        }
    }
}
