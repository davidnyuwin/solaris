import Foundation

public struct SanitisedResult: Sendable, Equatable {
    public let text: String
    public let isTruncated: Bool
    
    public init(text: String, isTruncated: Bool) {
        self.text = text
        self.isTruncated = isTruncated
    }
}

public struct OutputSanitiser: Sendable {
    private static let byteLimit = 65536
    
    /// Sanitises untrusted raw command output string defensively.
    public static func sanitise(_ input: String) -> SanitisedResult {
        var isTruncated = false
        var rawData = Data(input.utf8)
        
        // 1. Byte limit check
        if rawData.count > byteLimit {
            rawData = rawData.prefix(byteLimit)
            isTruncated = true
        }
        
        // 2. UTF-8 Validation and Lossy conversion
        // String(decoding:as:) replaces invalid UTF-8 bytes with Unicode replacement character (\u{FFFD})
        var text = String(decoding: rawData, as: UTF8.self)
        
        // 3. ANSI/OSC Escape Sequence Stripping
        let esc = "\u{001B}"
        let bel = "\u{0007}"
        
        // ANSI CSI escapes: ESC [ <numbers> <letter>
        if let ansiRegex = try? NSRegularExpression(pattern: "\(esc)\\[[0-9;]*[a-zA-Z]", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = ansiRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        // OSC sequences terminated by BEL (ESC ] ... BEL) or ST (ESC ] ... ESC \)
        if let oscRegex = try? NSRegularExpression(pattern: "\(esc)\\][0-9]+;[^\(bel)\(esc)]*(?:\(bel)|\(esc)\\\\)", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = oscRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        // 4. Control Character Filtering (Exclude C0/C1 control characters except safe whitespace)
        // Allowed whitespace: Tab (9), LF (10), CR (13)
        // C0 range to filter: 0-8, 11-12, 14-31, 127
        // C1 range to filter: 128-159 (0x80-0x9F)
        text = String(text.unicodeScalars.filter { scalar in
            let val = scalar.value
            if val >= 0 && val <= 8 { return false }
            if val >= 11 && val <= 12 { return false }
            if val >= 14 && val <= 31 { return false }
            if val == 127 { return false }
            if val >= 128 && val <= 159 { return false }
            return true
        })

        
        // 5. Secret-Shaped Redaction (Preserves harmless commit hashes and diagnostic hex fingerprints)
        // Redact OpenAI API keys (sk- followed by characters)
        if let openaiRegex = try? NSRegularExpression(pattern: "\\bsk-[a-zA-Z0-9_-]{20,}\\b", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = openaiRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[REDACTED_KEY]")
        }
        
        // Redact Bearer tokens
        if let bearerRegex = try? NSRegularExpression(pattern: "(?i)bearer\\s+[a-zA-Z0-9_\\-\\.\\+]{12,}", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = bearerRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Bearer [REDACTED]")
        }
        
        // Redact PEM private key blocks (multi-line)
        if let pemRegex = try? NSRegularExpression(pattern: "-----BEGIN[A-Z\\s]+PRIVATE KEY-----([\\s\\S]*?)-----END[A-Z\\s]+PRIVATE KEY-----", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = pemRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[REDACTED_PRIVATE_KEY]")
        }
        
        // Redact generic variable assignments with secrets/keys/tokens/passwords (e.g. API_TOKEN = "value")
        // But avoid matching non-secret keys by requiring 8+ chars and ignoring quotes or key-like variable declarations.
        if let assignmentRegex = try? NSRegularExpression(
            pattern: "(?i)\\b([a-zA-Z0-9_-]*(?:key|secret|token|password|passwd|client_secret|auth)[a-zA-Z0-9_-]*)\\s*[:=]\\s*[\"']?[A-Za-z0-9_\\-\\.\\+]{8,}[\"']?",
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = assignmentRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1: [REDACTED]")
        }

        
        // 6. Path Normalisation (replace absolute /Users/... paths with ~/)
        if let pathRegex = try? NSRegularExpression(pattern: "/Users/[a-zA-Z0-9_.-]+", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = pathRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "~")
        }
        
        // 7. Explicit Truncation Append
        if isTruncated {
            text += "\n[output truncated after 65536 bytes]"
        }
        
        return SanitisedResult(text: text, isTruncated: isTruncated)
    }
}
