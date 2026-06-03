import Foundation
import SwiftUI

/// Non-secret Remote Host settings persisted in UserDefaults.
/// SSH keys and passwords are never stored here — Solaris relies on the
/// macOS SSH agent (`ssh-agent`) and `~/.ssh/config`.
public struct RemoteHostSettings: Codable, Equatable {
    public var host: String
    public var username: String
    public var port: Int
    public var hermesCommand: String
    public var identityFilePath: String

    public static let defaultPort = 22
    public static let defaultHermesCommand = "hermes"

    public init(
        host: String = "",
        username: String = "",
        port: Int = Self.defaultPort,
        hermesCommand: String = Self.defaultHermesCommand,
        identityFilePath: String = ""
    ) {
        self.host = host
        self.username = username
        self.port = port
        self.hermesCommand = hermesCommand
        self.identityFilePath = identityFilePath
    }

    public static func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func isValidUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard !trimmed.contains("@") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func isValidPort(_ port: Int) -> Bool {
        return (1...65535).contains(port)
    }

    public static func isValidIdentityFilePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let forbidden = CharacterSet.controlCharacters
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else { return false }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    /// A label safe for UI display (avoids exposing raw hostname if empty).
    public var displayLabel: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Not configured"
            : host
    }

    /// Whether the settings are minimally filled in for a connection attempt.
    public var isValid: Bool {
        Self.isValidHost(host) &&
        Self.isValidUsername(username) &&
        Self.isValidPort(port) &&
        Self.isValidIdentityFilePath(identityFilePath)
    }

    /// Sanitised SSH user@host string safe for display.
    public var userAtHost: String {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty { return h }
        return "\(u)@\(h)"
    }
}
