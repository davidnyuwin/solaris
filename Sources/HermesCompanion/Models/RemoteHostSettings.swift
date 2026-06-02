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

    public static let defaultPort = 22
    public static let defaultHermesCommand = "hermes"

    public init(
        host: String = "",
        username: String = "",
        port: Int = Self.defaultPort,
        hermesCommand: String = Self.defaultHermesCommand
    ) {
        self.host = host
        self.username = username
        self.port = port
        self.hermesCommand = hermesCommand
    }

    /// A label safe for UI display (avoids exposing raw hostname if empty).
    public var displayLabel: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Not configured"
            : host
    }

    /// Whether the settings are minimally filled in for a connection attempt.
    public var isValid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sanitised SSH user@host string safe for display.
    public var userAtHost: String {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty { return h }
        return "\(u)@\(h)"
    }
}
