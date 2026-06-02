import Foundation

public struct HermesParsedStatus: Sendable {
    public var activeProvider: String?
    public var activeModel: String?
    public var messagingGatewayState: String?
    public var dashboardState: String?
    public var hermesHome: String?
    public var activeProfile: String?
    public var configVersion: String?
}

public struct HermesParsedGatewayStatus: Sendable {
    public var serviceStatus: String?
    public var processID: String?
    public var platformListeners: String?
    public var activeLogFile: String?
    public var logSize: String?
    public var recentEvents: [String] = []
}

public final class HermesCLIParsers: Sendable {
    
    public init() {}
    
    /// Redacts absolute /Users/username paths to ~ paths defensively
    public static func redactPath(_ path: String) -> String {
        var result = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.starts(with: "/") else { return result }
        
        let components = result.components(separatedBy: "/")
        if components.count > 2 && components[1] == "Users" {
            // Replaces /Users/username/ with ~/
            let remaining = components.dropFirst(3).joined(separator: "/")
            result = "~/\(remaining)"
        }
        return result
    }
    
    /// Parses the raw plain-text output of `hermes status`
    public func parseStatus(_ stdout: String) -> HermesParsedStatus {
        var parsed = HermesParsedStatus()
        let lines = stdout.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Check key prefixes
            if let value = extractValue(from: trimmed, prefix: "Active Provider:") {
                parsed.activeProvider = value
            } else if let value = extractValue(from: trimmed, prefix: "Active Model:") {
                parsed.activeModel = value
            } else if let value = extractValue(from: trimmed, prefix: "Messaging Gateway:") {
                parsed.messagingGatewayState = value
            } else if let value = extractValue(from: trimmed, prefix: "Vite Dashboard:") {
                parsed.dashboardState = value
            } else if let value = extractValue(from: trimmed, prefix: "Hermes Home:") {
                parsed.hermesHome = Self.redactPath(value)
            } else if let value = extractValue(from: trimmed, prefix: "Active Profile:") {
                parsed.activeProfile = value
            } else if let value = extractValue(from: trimmed, prefix: "Config Version:") {
                parsed.configVersion = value
            }
        }
        
        return parsed
    }
    
    /// Parses the raw plain-text output of `hermes gateway status`
    public func parseGatewayStatus(_ stdout: String) -> HermesParsedGatewayStatus {
        var parsed = HermesParsedGatewayStatus()
        let lines = stdout.components(separatedBy: .newlines)
        
        var insideRecentEvents = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Check for Recent Events block start
            if trimmed.contains("Recent Events") {
                insideRecentEvents = true
                continue
            }
            
            if insideRecentEvents {
                // If we encounter a new header prefix, stop event collection
                if trimmed.contains(":") && !trimmed.starts(with: "[") {
                    insideRecentEvents = false
                } else {
                    // Collect recent gateway events, formatting cleanly
                    parsed.recentEvents.append(trimmed)
                    continue
                }
            }
            
            // Check key prefixes
            if let value = extractValue(from: trimmed, prefix: "Service Status:") {
                parsed.serviceStatus = value
            } else if let value = extractValue(from: trimmed, prefix: "Process ID:") {
                parsed.processID = value
            } else if let value = extractValue(from: trimmed, prefix: "Platform Listeners:") {
                parsed.platformListeners = value
            } else if let value = extractValue(from: trimmed, prefix: "Active Log File:") {
                parsed.activeLogFile = Self.redactPath(value)
            } else if let value = extractValue(from: trimmed, prefix: "Log Size:") {
                parsed.logSize = value
            }
        }
        
        return parsed
    }
    
    private func extractValue(from line: String, prefix: String) -> String? {
        guard line.range(of: prefix, options: [.caseInsensitive]) != nil else { return nil }
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        // Rejoin components in case the value itself contained colons
        let value = components.dropFirst().joined(separator: ":")
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip any trailing parentheses/comments if present in certain keys (e.g. "Stopped (No running PID found)")
        return cleaned.isEmpty ? nil : cleaned
    }
}
