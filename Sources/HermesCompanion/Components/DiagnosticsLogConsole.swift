import SwiftUI

public struct DiagnosticsLogConsole: View {
    let logs: [LogLine]
    let isPrivacyActive: Bool
    
    public init(logs: [LogLine], isPrivacyActive: Bool = false) {
        self.logs = logs
        self.isPrivacyActive = isPrivacyActive
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.15))
                    Text("No diagnostic logs ingested")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Active process logs will populate here automatically.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { log in
                            LogConsoleRow(log: log, isPrivacyActive: isPrivacyActive)
                                .id(log.id)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(minHeight: 180, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .accessibilityLabel(logs.isEmpty ? "Diagnostics log console, no entries" : "Diagnostics log console, \(logs.count) entries")
    }
}

struct LogConsoleRow: View {
    let log: LogLine
    let isPrivacyActive: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(formatTimestamp(log.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 76, alignment: .leading)
            
            // Severity Badge
            SeverityBadge(level: log.level)
                .scaleEffect(0.9)
                .frame(width: 52, alignment: .leading)
            
            // Log message
            Text(safeMessage)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3.5)
        .padding(.horizontal, 6)
        .background(rowBgColor)
        .cornerRadius(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(log.level.isEmpty ? "Log entry" : "\(log.level) log")
        .accessibilityValue("\(formatTimestamp(log.timestamp)): \(safeMessage)")
    }
    
    private var rowBgColor: Color {
        switch log.level.uppercased() {
        case "ERROR", "CRITICAL", "ERR":
            return Color.rose.opacity(0.05)
        case "WARN", "WARNING":
            return Color.amber.opacity(0.05)
        default:
            return Color.clear
        }
    }
    
    private var safeMessage: String {
        let msg = log.message
        if isPrivacyActive {
            return DiagnosticsRedactor.redact(msg, redactPIDs: true, redactTokens: true)
        }
        return msg
    }

    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
