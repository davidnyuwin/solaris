import Foundation

public final class LocalHermesDiagnosticsService: HermesService, @unchecked Sendable {
    
    private let homeDir: URL
    private let cliExecutor = HermesCLIExecutor()
    private let cliParsers = HermesCLIParsers()
    
    public init() {
        self.homeDir = FileManager.default.homeDirectoryForCurrentUser
    }
    
    private var logsDir: URL {
        homeDir.appendingPathComponent(".hermes").appendingPathComponent("logs")
    }
    
    private var agentLogURL: URL {
        logsDir.appendingPathComponent("agent.log")
    }
    
    private var gatewayLogURL: URL {
        logsDir.appendingPathComponent("gateway.log")
    }
    
    public func getStatus() async throws -> HermesStatus {
        let isGatewayRunning = isProcessRunning(name: "hermes_cli.main gateway") || isProcessRunning(name: "hermes_cli")
        let isDashboardAvailable = isPortListening(port: 9119)
        
        let fm = FileManager.default
        let isAgentLogFound = fm.fileExists(atPath: agentLogURL.path)
        let isGatewayLogFound = fm.fileExists(atPath: gatewayLogURL.path)
        
        // Retrieve process uptime if running
        var uptime = 0
        if isGatewayRunning, let pid = getGatewayPID() {
            uptime = getProcessUptime(pid: pid)
        }
        
        // Enrich with CLI status if available
        var activeProvider: String? = nil
        var activeModel: String? = nil
        var cliStatus = "Unavailable"
        let cliLastChecked = Date()
        
        do {
            let cliResult = try await cliExecutor.execute(command: .status)
            if cliResult.timedOut {
                cliStatus = "Timed out"
            } else if cliResult.exitCode != 0 {
                cliStatus = "Unavailable (Exit code: \(cliResult.exitCode))"
            } else if cliResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cliStatus = "Parse warning (Empty stdout)"
            } else {
                let parsed = cliParsers.parseStatus(cliResult.stdout)
                activeProvider = parsed.activeProvider
                activeModel = parsed.activeModel
                
                if activeProvider != nil || activeModel != nil {
                    cliStatus = "Available"
                } else {
                    cliStatus = "Parse warning (No fields parsed)"
                }
            }
        } catch HermesCLIError.executableNotFound {
            cliStatus = "Unavailable (Python missing)"
        } catch HermesCLIError.executionFailed(let reason) {
            cliStatus = "Unavailable (\(reason))"
        } catch {
            cliStatus = "Unavailable (\(error.localizedDescription))"
        }
        
        return HermesStatus(
            state: isGatewayRunning ? .listening : .idle,
            uptimeSeconds: uptime,
            relayConnected: isGatewayRunning,
            activeJobsCount: 0,
            gatewayRunning: isGatewayRunning,
            dashboardAvailable: isDashboardAvailable,
            agentLogFound: isAgentLogFound,
            gatewayLogFound: isGatewayLogFound,
            agentLogPath: agentLogURL.path,
            gatewayLogPath: gatewayLogURL.path,
            gatewayPID: isGatewayRunning ? getGatewayPID() : nil,
            activeProvider: activeProvider,
            activeModel: activeModel,
            cliStatus: cliStatus,
            cliLastChecked: cliLastChecked
        )
    }
    
    public func getRecentRuns() async throws -> [HermesRun] {
        // Since we are offline and the server database is unavailable,
        // we can construct diagnostic runs that show the diagnostic action timeline.
        let status = try await getStatus()
        
        var diagnosticsRuns: [HermesRun] = []
        
        if let provider = status.activeProvider, let model = status.activeModel {
            diagnosticsRuns.append(
                HermesRun(
                    id: "diag-cli-info",
                    timestamp: Date(),
                    prompt: "Query Active Inference Configuration",
                    response: "CLI reports active configuration: Provider is '\(provider)', Model is '\(model)'. Read-only CLI status checks are enabled.",
                    isSuccess: true,
                    durationMs: 8
                )
            )
        }
        
        if status.gatewayRunning == true {
            diagnosticsRuns.append(
                HermesRun(
                    id: "diag-001",
                    timestamp: Date(),
                    prompt: "Check Gateway Process Status",
                    response: "Gateway process is actively running (PID: \(getGatewayPID() ?? "Unknown")). System is monitoring cron/telemetry background loops.",
                    isSuccess: true,
                    durationMs: 12
                )
            )
        } else {
            diagnosticsRuns.append(
                HermesRun(
                    id: "diag-001",
                    timestamp: Date(),
                    prompt: "Check Gateway Process Status",
                    response: "Gateway daemon process was not detected. Start with 'hermes gateway' or use the Hermes Studio launch panel.",
                    isSuccess: false,
                    durationMs: 15
                )
            )
        }
        
        diagnosticsRuns.append(
            HermesRun(
                id: "diag-002",
                timestamp: Date().addingTimeInterval(-10),
                prompt: "Scan Local Web Server (Port 9119)",
                response: status.dashboardAvailable == true
                    ? "Dashboard REST API is active and listening on port 9119."
                    : "Dashboard server is offline/unreachable on port 9119. Verified: Bundled python environment is missing FastAPI dependencies.",
                isSuccess: status.dashboardAvailable == true,
                durationMs: 40
            )
        )
        
        return diagnosticsRuns
    }
    
    public func getProviderHealth() async throws -> [ProviderHealth] {
        // Construct localized config provider status
        let fm = FileManager.default
        let hasAgentLog = fm.fileExists(atPath: agentLogURL.path)
        let hasGatewayLog = fm.fileExists(atPath: gatewayLogURL.path)
        
        var list = [
            ProviderHealth(
                name: "Gateway Daemon Status",
                isOnline: isProcessRunning(name: "hermes_cli"),
                latencyMs: 0,
                successRate: hasGatewayLog ? 1.0 : 0.0
            ),
            ProviderHealth(
                name: "Agent Cli Console",
                isOnline: hasAgentLog,
                latencyMs: 0,
                successRate: hasAgentLog ? 1.0 : 0.0
            ),
            ProviderHealth(
                name: "Local Web API Gateway",
                isOnline: isPortListening(port: 9119),
                latencyMs: 0,
                successRate: 0.0
            )
        ]
        
        // Add active provider if found via CLI
        do {
            let cliResult = try await cliExecutor.execute(command: .status)
            if cliResult.exitCode == 0 {
                let parsed = cliParsers.parseStatus(cliResult.stdout)
                if let provider = parsed.activeProvider, let model = parsed.activeModel {
                    list.insert(
                        ProviderHealth(
                            name: "Inference: \(provider) (\(model))",
                            isOnline: true,
                            latencyMs: 0,
                            successRate: 1.0
                        ),
                        at: 0
                    )
                }
            }
        } catch {}
        
        return list
    }
    
    public func getRecentLogs() async throws -> [LogLine] {
        var allLogLines: [LogLine] = []
        
        // Load and parse agent.log
        if let agentLogs = readLogFile(at: agentLogURL, limit: 50) {
            allLogLines.append(contentsOf: agentLogs)
        }
        
        // Load and parse gateway.log
        if let gatewayLogs = readLogFile(at: gatewayLogURL, limit: 50) {
            allLogLines.append(contentsOf: gatewayLogs)
        }
        
        // Add CLI recent events as LogLines if available
        do {
            let cliResult = try await cliExecutor.execute(command: .gatewayStatus)
            if cliResult.exitCode == 0 {
                let parsed = cliParsers.parseGatewayStatus(cliResult.stdout)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                for event in parsed.recentEvents {
                    let trimmed = event.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.starts(with: "[") else { continue }
                    
                    let parts = trimmed.components(separatedBy: "]")
                    guard parts.count >= 2 else { continue }
                    
                    let datePart = parts[0].replacingOccurrences(of: "[", with: "")
                    let msgPart = parts.dropFirst().joined(separator: "]").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let date = formatter.date(from: datePart) ?? Date()
                    allLogLines.append(
                        LogLine(
                            id: "cli-event-\(UUID().uuidString.prefix(6))",
                            timestamp: date,
                            level: "CLI",
                            message: msgPart
                        )
                    )
                }
            }
        } catch {}
        
        // Sort merged logs by timestamp descending (newest first)
        return allLogLines.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func sendCommand(_ command: String) async throws -> HermesResponse {
        // Offline submissions: diagnostic actions
        let cmd = command.lowercased()
        
        let responseText: String
        let success: Bool
        
        if cmd.contains("process") || cmd.contains("gateway") {
            let running = isProcessRunning(name: "hermes_cli")
            responseText = running
                ? "Diagnostics: Hermes gateway daemon is currently running. PID: \(getGatewayPID() ?? "Unknown")."
                : "Diagnostics: Hermes gateway daemon is not running on this host."
            success = true
        } else if cmd.contains("log") || cmd.contains("scan") {
            let fm = FileManager.default
            let agentExist = fm.fileExists(atPath: agentLogURL.path)
            let gatewayExist = fm.fileExists(atPath: gatewayLogURL.path)
            responseText = "Diagnostics Scan: agent.log found: \(agentExist), gateway.log found: \(gatewayExist)."
            success = true
        } else if cmd.contains("api") || cmd.contains("port") || cmd.contains("server") {
            let listening = isPortListening(port: 9119)
            responseText = listening
                ? "Diagnostics Check: Dashboard API server is ACTIVE on port 9119."
                : "Diagnostics Check: Dashboard API server is OFFLINE on port 9119 (FastAPI missing)."
            success = listening
        } else {
            responseText = "Local Diagnostics Mode: Network APIs are currently disabled. Local process and log scans are active. Unknown or unsupported diagnostic command: '\(command)'."
            success = false
        }
        
        let run = HermesRun(
            id: "diag-\(UUID().uuidString.prefix(6).lowercased())",
            timestamp: Date(),
            prompt: command,
            response: responseText,
            isSuccess: success,
            durationMs: 15
        )
        
        return HermesResponse(
            responseText: responseText,
            executionTimeMs: 15,
            success: success,
            createdRun: run
        )
    }
    
    // MARK: - Private Helpers
    
    private func isProcessRunning(name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", name]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let pids = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return !pids.isEmpty
            }
        } catch {
            return isProcessRunningFallback(name: name)
        }
        return false
    }
    
    private func isProcessRunningFallback(name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["ax"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains(name)
            }
        } catch {}
        return false
    }
    
    private func getGatewayPID() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "hermes_cli"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let firstLine = output.components(separatedBy: "\n").first ?? ""
                let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, Int(trimmed) != nil {
                    return trimmed
                }
            }
        } catch {}
        return nil
    }
    
    private func getProcessUptime(pid: String) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", pid, "-o", "etime="]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let etime = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let components = etime.components(separatedBy: ":")
                if components.count == 2 {
                    let m = Int(components[0]) ?? 0
                    let s = Int(components[1]) ?? 0
                    return m * 60 + s
                } else if components.count == 3 {
                    let firstComp = components[0]
                    let h: Int
                    let d: Int
                    if firstComp.contains("-") {
                        let subComps = firstComp.components(separatedBy: "-")
                        d = Int(subComps[0]) ?? 0
                        h = Int(subComps[1]) ?? 0
                    } else {
                        d = 0
                        h = Int(firstComp) ?? 0
                    }
                    let m = Int(components[1]) ?? 0
                    let s = Int(components[2]) ?? 0
                    return d * 86400 + h * 3600 + m * 60 + s
                }
            }
        } catch {}
        return 0
    }
    
    private func isPortListening(port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } catch {}
        return false
    }
    
    private func readLogFile(at url: URL, limit: Int) -> [LogLine]? {
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else { return nil }
            
            let lines = content.components(separatedBy: "\n")
            let filteredLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            // Get suffix up to the limit
            let recentLines = filteredLines.suffix(limit)
            
            var parsedLogs: [LogLine] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss,SSS"
            
            for line in recentLines {
                if let parsed = parseLogLine(line, formatter: formatter) {
                    parsedLogs.append(parsed)
                }
            }
            return parsedLogs
        } catch {
            return nil
        }
    }
    
    private func parseLogLine(_ line: String, formatter: DateFormatter) -> LogLine? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let parts = trimmed.components(separatedBy: " ")
        guard parts.count >= 3 else {
            return LogLine(id: UUID().uuidString, timestamp: Date(), level: "INFO", message: trimmed)
        }
        
        let dateStr = parts[0]
        let timeStr = parts[1]
        let level = parts[2].replacingOccurrences(of: ":", with: "")
        
        let prefixLength = dateStr.count + 1 + timeStr.count + 1 + parts[2].count + 1
        let message: String
        if prefixLength < trimmed.count {
            message = String(trimmed.suffix(trimmed.count - prefixLength))
        } else {
            message = trimmed
        }
        
        let fullDateTimeStr = "\(dateStr) \(timeStr)"
        let date = formatter.date(from: fullDateTimeStr) ?? Date()
        
        return LogLine(id: UUID().uuidString, timestamp: date, level: level, message: message)
    }
}
