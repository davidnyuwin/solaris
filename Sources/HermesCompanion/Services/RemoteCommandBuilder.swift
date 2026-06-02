import Foundation

public enum AllowedRemoteCommand: Sendable, Equatable {
    case which
    case version
    case status
    case gatewayStatus
    case chat(promptPlaceholder: String)
}

public enum RemoteCommandBuilderError: Error, LocalizedError, Equatable {
    case chatExecutionNotYetApproved
    case emptyHermesCommand
    case invalidHermesCommand(String)

    public var errorDescription: String? {
        switch self {
        case .chatExecutionNotYetApproved:
            return "Chat execution is blocked in this batch as safety transport controls are not yet approved."
        case .emptyHermesCommand:
            return "Hermes command path cannot be empty."
        case .invalidHermesCommand(let command):
            return "Hermes command '\(command)' is invalid due to forbidden shell characters."
        }
    }
}

public struct RemoteCommandBuilder: Sendable {
    
    /// Sanitises the base command to ensure it contains no shell metacharacters.
    /// Throws an error if forbidden characters are present.
    public static func sanitiseHermesCommand(_ base: String) throws -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RemoteCommandBuilderError.emptyHermesCommand
        }

        let forbidden = CharacterSet(charactersIn: " ;|&`$<>()[]{}#'\"!\\")
        if trimmed.rangeOfCharacter(from: forbidden) != nil {
            throw RemoteCommandBuilderError.invalidHermesCommand(trimmed)
        }
        return trimmed
    }

    /// Constructs the final remote arguments to be executed over SSH for the given command type.
    /// Blocks chat execution and fails closed.
    public static func buildArguments(
        for command: AllowedRemoteCommand,
        hermesCommandBase: String
    ) throws -> [String] {
        let verifiedBase = try sanitiseHermesCommand(hermesCommandBase)
        
        switch command {
        case .which:
            return ["which", verifiedBase]
        case .version:
            return [verifiedBase, "--version"]
        case .status:
            return [verifiedBase, "status"]
        case .gatewayStatus:
            return [verifiedBase, "gateway", "status"]
        case .chat:
            throw RemoteCommandBuilderError.chatExecutionNotYetApproved
        }
    }
}
