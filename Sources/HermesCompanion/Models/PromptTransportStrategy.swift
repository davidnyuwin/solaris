import Foundation

/// Represents the transport path strategy for passing chat query prompts
/// safely to a remote Hermes Agent host.
public enum PromptTransportStrategy: String, Sendable, CaseIterable, Identifiable {
    /// Safe transport: pipe the prompt through standard input (stdin)
    /// of a fixed allowed remote Hermes command (e.g. `hermes chat -q -`).
    /// This prevents any remote-shell parsing or command injection.
    case stdinSupported = "stdinSupported"
    
    /// Unsafe/Blocked transport: prompt passed only via command-line arguments.
    /// Remote login shells on the SSH daemon host will interpret the argument string,
    /// exposing command injection vectors.
    case argumentOnlyBlocked = "argumentOnlyBlocked"
    
    /// Alternate transport: communicate through the REST HTTP/WebSocket gateway.
    case gatewayPreferred = "gatewayPreferred"
    
    /// Fallback strategy for unknown configurations. Fail closed.
    case unknownBlocked = "unknownBlocked"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .stdinSupported:
            return "Standard Input Pipe (stdin)"
        case .argumentOnlyBlocked:
            return "Command Arguments (Blocked)"
        case .gatewayPreferred:
            return "Nous Tool Gateway (REST)"
        case .unknownBlocked:
            return "Unknown (Blocked)"
        }
    }
}
