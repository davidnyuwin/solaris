import Foundation

public struct SanitisedResult: Sendable, Equatable {
    public let text: String
    public let isTruncated: Bool
    public let isRedacted: Bool
    
    public init(text: String, isTruncated: Bool, isRedacted: Bool = false) {
        self.text = text
        self.isTruncated = isTruncated
        self.isRedacted = isRedacted
    }
}

public struct OutputSanitiser: Sendable {
    private static let byteLimit = 65536
    
    /// Sanitises untrusted raw command output string defensively.
    public static func sanitise(_ input: String, isStreaming: Bool = false) -> SanitisedResult {
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

        let textBeforeRedactions = text
        
        // 5. Secret-Shaped Redaction (Preserves harmless commit hashes and diagnostic hex fingerprints)
        // Redact OpenAI API keys (sk- followed by characters)
        if let openaiRegex = try? NSRegularExpression(pattern: "\\bsk-[a-zA-Z0-9_-]{20,}\\b", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = openaiRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[REDACTED_KEY]")
        }
        
        // Redact Authorization header values (Basic, Digest, Token, Bearer, or bare value).
        // MUST run before the standalone Bearer-token regex so the more-specific pattern
        // fires first and produces a clean "Authorization: [REDACTED]" replacement.
        if let authRegex = try? NSRegularExpression(
            pattern: "(?i)authorization:\\s*(?:(?:basic|digest|token|bearer)\\s+)?[a-zA-Z0-9_\\-\\.\\+/=]{8,}",
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = authRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Authorization: [REDACTED]")
        }
        
        // Redact standalone Bearer tokens (e.g. in JSON bodies or logs, not in Authorization headers)
        if let bearerRegex = try? NSRegularExpression(pattern: "(?i)bearer\\s+[a-zA-Z0-9_\\-\\.\\+]{12,}", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = bearerRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Bearer [REDACTED]")
        }
        
        // Redact Cookie header values
        if let cookieRegex = try? NSRegularExpression(
            pattern: "(?i)cookie:\\s*[^\\r\\n]{8,}",
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = cookieRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Cookie: [REDACTED]")
        }
        
        // Redact GitHub personal access tokens (ghp_, ghs_, github_pat_)
        if let githubTokenRegex = try? NSRegularExpression(
            pattern: "\\b(?:ghp|ghs|github_pat)_[a-zA-Z0-9_]{20,}\\b",
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = githubTokenRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[REDACTED_GITHUB_TOKEN]")
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

        // Redact credentialed URLs: https://user:pass@host or http://user:pass@host
        // Preserves scheme and host for diagnostic readability; redacts only the credential segment.
        if let credUrlRegex = try? NSRegularExpression(
            pattern: "(?i)(https?://)([^@\\s/]+:[^@\\s/]+@)",
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = credUrlRegex.stringByReplacingMatches(in: text, options: [], range: range,
                withTemplate: "$1[REDACTED_CREDENTIALS]@")
        }

        if isStreaming {
            text = holdBackStreamingSuffix(text)
        }

        // 6. Path Normalisation (replace absolute /Users/... paths with ~/)
        if let pathRegex = try? NSRegularExpression(pattern: "/Users/[a-zA-Z0-9_.-]+", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = pathRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "~")
        }
        
        let isRedacted = (text != textBeforeRedactions)
        
        // 7. Explicit Truncation Append
        if isTruncated {
            text += "\n[output truncated after 65536 bytes]"
        }
        
        return SanitisedResult(text: text, isTruncated: isTruncated, isRedacted: isRedacted)
    }
    
    private static func holdBackStreamingSuffix(_ text: String) -> String {
        let patterns = [
            "\\bsk-[a-zA-Z0-9_-]{0,100}$",
            "(?i)authorization:\\s*(?:(?:basic|digest|token|bearer)\\s+)?[a-zA-Z0-9_\\-\\.\\+/=]{0,100}$",
            "(?i)\\bbearer(?:\\s+[a-zA-Z0-9_\\-\\.\\+]{0,100})?$",
            "/(?:Users(?:/[a-zA-Z0-9_.-]{0,50})?|User|Use|Us)$",
            "-----BEGIN[a-zA-Z0-9\\+/=\\s-]{0,2000}$",
            "(?i)\\b([a-zA-Z0-9_-]*(?:key|secret|token|password|passwd|client_secret|auth)[a-zA-Z0-9_-]*)\\s*[:=]\\s*[\"']?[A-Za-z0-9_\\-\\.\\+]{0,100}$",
            "(?i)(https?://)([^@\\s/]*:[^@\\s/]*@[^\\s/]{0,100})$",
            "(?i)https?://[^@\\s/]+:[^\\s/]*$",
            "(?i)cookie:\\s*[^\\r\\n]{0,200}$",
            "\\b(?:ghp|ghs|github_pat)_[a-zA-Z0-9_]{0,100}$"
        ]
        
        var longestMatchLength = 0
        var matchedRange: NSRange? = nil
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let matchRange = match.range
                    if matchRange.location != NSNotFound {
                        let len = matchRange.length
                        if len > longestMatchLength {
                            longestMatchLength = len
                            matchedRange = matchRange
                        }
                    }
                }
            }
        }
        
        if let matchRange = matchedRange, let swiftRange = Range(matchRange, in: text) {
            return String(text[..<swiftRange.lowerBound]) + "..."
        }
        
        return text
    }
}

// MARK: - Stateful Streaming Output Sanitiser

public final class StreamingOutputSanitiser: @unchecked Sendable {
    private enum ParserState {
        case normal
        case sawEsc
        case ansiCsi
        case osc
        case oscEsc
    }
    
    private var state: ParserState = .normal
    private var utf8Buffer = Data()
    
    public init() {}
    
    /// Processes a new chunk of raw bytes, statefully strips ANSI/OSC/Control sequences,
    /// and returns the incremental sanitised string.
    public func appendAndSanitise(_ chunk: Data) -> String {
        utf8Buffer.append(chunk)
        
        let (completeBytes, remainingBytes) = findCompleteUTF8Prefix(in: utf8Buffer)
        utf8Buffer = remainingBytes
        
        guard !completeBytes.isEmpty else {
            return ""
        }
        
        let decodedText = String(decoding: completeBytes, as: UTF8.self)
        
        var filteredText = ""
        filteredText.reserveCapacity(decodedText.count)
        
        for scalar in decodedText.unicodeScalars {
            let val = scalar.value
            
            switch state {
            case .normal:
                if val == 0x001B { // ESC
                    state = .sawEsc
                } else {
                    // Control Character Filtering (Exclude C0/C1 control characters except safe whitespace)
                    // Safe whitespace: Tab (9), LF (10), CR (13)
                    let isControl = (val <= 8) || (val >= 11 && val <= 12) || (val >= 14 && val <= 31) || (val == 127) || (val >= 128 && val <= 159)
                    if !isControl {
                        filteredText.append(Character(scalar))
                    }
                }
                
            case .sawEsc:
                if val == 0x005B { // '['
                    state = .ansiCsi
                } else if val == 0x005D { // ']'
                    state = .osc
                } else {
                    state = .normal
                }
                
            case .ansiCsi:
                if val >= 0x40 && val <= 0x7E {
                    state = .normal
                } else if val >= 0x20 && val <= 0x3F {
                    break
                } else {
                    state = .normal
                }
                
            case .osc:
                if val == 0x001B { // ESC
                    state = .oscEsc
                } else if val == 0x0007 { // BEL
                    state = .normal
                } else {
                    break
                }
                
            case .oscEsc:
                if val == 0x005C { // '\'
                    state = .normal
                } else {
                    state = .osc
                }
            }
        }
        
        return filteredText
    }
    
    private func findCompleteUTF8Prefix(in data: Data) -> (complete: Data, remaining: Data) {
        guard !data.isEmpty else { return (data, Data()) }
        
        let baseData = Data(data)
        let maxUTF8Length = 4
        let lastBytesCount = min(baseData.count, maxUTF8Length)
        let startIndex = baseData.count - lastBytesCount
        
        for i in (startIndex..<baseData.count).reversed() {
            let byte = baseData[i]
            if byte < 0x80 {
                return (Data(baseData.prefix(i + 1)), Data(baseData.suffix(baseData.count - (i + 1))))
            } else if byte >= 0xC0 {
                let expectedLen: Int
                if (byte & 0xE0) == 0xC0 {
                    expectedLen = 2
                } else if (byte & 0xF0) == 0xE0 {
                    expectedLen = 3
                } else if (byte & 0xF0) == 0xF0 {
                    expectedLen = 4
                } else {
                    return (Data(baseData.prefix(i + 1)), Data(baseData.suffix(baseData.count - (i + 1))))
                }
                
                let actualLen = baseData.count - i
                if actualLen >= expectedLen {
                    return (baseData, Data())
                } else {
                    return (Data(baseData.prefix(i)), Data(baseData.suffix(actualLen)))
                }
            }
        }
        
        return (baseData, Data())
    }
}

// MARK: - Remote Command Input Metadata

/// A metadata-only audit record describing an SSH stdin submission.
///
/// **Security contract**: This struct MUST NOT hold the raw stdin payload.
/// It captures only structural metadata (byte count, command type, timestamp,
/// and an optional sanitised first-line hint) so that diagnostic log entries
/// remain meaningful without leaking secret-bearing content.
public struct RemoteCommandInputMetadata: Sendable, Equatable {
    /// The allowlisted command that received the stdin payload.
    public let command: String

    /// Byte length of the raw stdin payload (not the content itself).
    public let byteCount: Int

    /// Wall-clock time when the stdin payload was submitted.
    public let submittedAt: Date

    /// An optional sanitised one-line hint derived from the first line of
    /// the payload (e.g. the command verb, with all secrets redacted).
    /// Nil when the payload is binary or when even the first line is secret-
    /// shaped after sanitisation.
    public let sanitisedFirstLineHint: String?

    /// Creates metadata from a raw stdin `Data` payload and a command label.
    ///
    /// - Parameters:
    ///   - rawPayload: The actual stdin bytes — used only to derive metadata;
    ///     the payload itself is NOT stored.
    ///   - command: A human-readable label for the allowlisted command.
    public init(rawPayload: Data, command: String) {
        self.command = command
        self.byteCount = rawPayload.count
        self.submittedAt = Date()

        // Extract first line of the payload as a UTF-8 string, then run it
        // through the full sanitiser to strip any secrets before storing.
        if let rawString = String(data: rawPayload, encoding: .utf8) {
            let firstLine = String(rawString.prefix(200))
                .components(separatedBy: .newlines)
                .first ?? ""
            let hint = OutputSanitiser.sanitise(firstLine, isStreaming: false).text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Only store the hint if it is non-empty AND does not look like it
            // was entirely redacted (i.e., it still carries some human-readable
            // content beyond placeholder tokens).
            let isEntirelyRedacted = hint.isEmpty
                || hint == "[REDACTED_KEY]"
                || hint == "Bearer [REDACTED]"
                || hint == "[REDACTED_PRIVATE_KEY]"
                || hint == "[REDACTED_GITHUB_TOKEN]"
                || hint == "Authorization: [REDACTED]"
                || hint == "Cookie: [REDACTED]"
            self.sanitisedFirstLineHint = isEntirelyRedacted ? nil : hint
        } else {
            // Binary payload — no hint available.
            self.sanitisedFirstLineHint = nil
        }
    }

    /// A human-readable diagnostic description safe for inclusion in log entries.
    public var diagnosticDescription: String {
        var parts: [String] = [
            "command=\(command)",
            "bytes=\(byteCount)"
        ]
        if let hint = sanitisedFirstLineHint {
            parts.append("hint=\(hint)")
        }
        return parts.joined(separator: " ")
    }
}
