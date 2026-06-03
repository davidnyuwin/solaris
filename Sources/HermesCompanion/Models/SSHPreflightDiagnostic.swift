import Foundation
import SwiftUI

public enum SSHPreflightStatus: String, Codable, Sendable {
    case pass
    case warning
    case fail
}

public struct SSHPreflightDiagnostic: Codable, Equatable, Sendable {
    public let status: SSHPreflightStatus
    public let title: String
    public let message: String
    public let actionGuide: String?
    
    public init(status: SSHPreflightStatus, title: String, message: String, actionGuide: String? = nil) {
        self.status = status
        self.title = title
        self.message = message
        self.actionGuide = actionGuide
    }
    
    public var iconName: String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "lock.dash.ellipse"
        }
    }
    
    public var color: Color {
        switch status {
        case .pass: return .emerald
        case .warning: return .amber
        case .fail: return .rose
        }
    }
}
