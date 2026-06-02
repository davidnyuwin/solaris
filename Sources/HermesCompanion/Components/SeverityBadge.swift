import SwiftUI

public struct SeverityBadge: View {
    let level: String
    
    public init(level: String) {
        self.level = level.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var body: some View {
        Text(displayLabel)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.12))
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(foregroundColor.opacity(0.25), lineWidth: 0.5)
            )
    }
    
    private var displayLabel: String {
        switch level {
        case "INFO": return "INFO"
        case "WARN", "WARNING": return "WARN"
        case "ERROR", "CRITICAL", "ERR": return "ERROR"
        case "DEBUG": return "DEBUG"
        default: return level.isEmpty ? "UNKNOWN" : level
        }
    }
    
    private var foregroundColor: Color {
        switch level {
        case "ERROR", "CRITICAL", "ERR":
            return .rose
        case "WARN", "WARNING":
            return .amber
        case "INFO":
            return Color.hermesTeal
        case "DEBUG":
            return Color(red: 0.25, green: 0.55, blue: 1.0)
        default:
            return Color.white.opacity(0.6)
        }
    }
    
    private var backgroundColor: Color {
        foregroundColor
    }
}
