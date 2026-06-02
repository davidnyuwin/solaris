import Foundation

public struct DiagnosticsRedactor {
    /// Redacts sensitive information from diagnostics text defensively.
    /// - Parameters:
    ///   - text: The input text to sanitize.
    ///   - redactPIDs: If true, redacts process ID numbers.
    ///   - redactTokens: If true, redacts defensive hex tokens, authorization, and secret values.
    /// - Returns: A sanitized version of the input text.
    public static func redact(_ text: String, redactPIDs: Bool = true, redactTokens: Bool = true) -> String {
        var redacted = text
        
        // 1. Redact `/Users/username` to `~`
        if let regex = try? NSRegularExpression(pattern: "/Users/[a-zA-Z0-9_.-]+", options: []) {
            let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
            redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "~")
        }
        
        // 2. Redact PIDs (e.g. "PID: 12345" or "Process ID: 4123")
        if redactPIDs {
            if let regex = try? NSRegularExpression(pattern: "(?i)(pid|process\\s*id)\\s*[:\\s]\\s*\\d+", options: []) {
                let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
                redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "$1: [PID]")
            }
        }
        
        // 3. Redact defensive token-like strings
        if redactTokens {
            // Hex token of length 16 to 128 characters
            if let regex = try? NSRegularExpression(pattern: "\\b[a-fA-F0-9]{16,128}\\b", options: []) {
                let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
                redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "[REDACTED_TOKEN]")
            }
            // Keys, credentials, secrets, tokens, password fields
            if let regex = try? NSRegularExpression(pattern: "(?i)(bearer|token|key|secret|passwd|password|auth|authorization)\\s*[:\\s=]\\s*[^\\s\\n]{4,}", options: []) {
                let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
                redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "$1: [REDACTED]")
            }
        }
        
        return redacted
    }
}
