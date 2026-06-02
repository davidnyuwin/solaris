import SwiftUI

public enum ProcessStatusType: String {
    case active = "Active"
    case stable = "Stable"
    case idle = "Idle"
    case missing = "Missing"
    case unavailable = "Unavailable"
    
    public var color: Color {
        switch self {
        case .active, .stable:
            return .emerald
        case .idle:
            return .amber
        case .missing, .unavailable:
            return .rose
        }
    }
}

public struct ProcessStatusRow: View {
    let name: String
    let status: ProcessStatusType
    let detailText: String?
    let pidText: String?
    let iconName: String
    let isPrivacyActive: Bool
    
    public init(
        name: String,
        status: ProcessStatusType,
        detailText: String? = nil,
        pidText: String? = nil,
        iconName: String,
        isPrivacyActive: Bool = false
    ) {
        self.name = name
        self.status = status
        self.detailText = detailText
        self.pidText = pidText
        self.iconName = iconName
        self.isPrivacyActive = isPrivacyActive
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundColor(.hermesTeal)
                .frame(width: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let pid = pidText {
                        Text(isPrivacyActive ? "PID: [REDACTED]" : "PID: \(pid)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(3)
                    }
                }
                
                if let detail = detailText {
                    Text(isPrivacyActive ? redactPath(detail) : detail)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            // Status Badge
            Text(status.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.12))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(status.color.opacity(0.2), lineWidth: 0.5)
                )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.01))
        .cornerRadius(8)
    }
    
    private func redactPath(_ path: String) -> String {
        guard path.contains("/") else { return path }
        // Keep the filename or a simple relative path
        if let lastComponent = path.components(separatedBy: "/").last {
            return "~/.hermes/.../\(lastComponent)"
        }
        return "~/... [REDACTED]"
    }
}
