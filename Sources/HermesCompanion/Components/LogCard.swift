import SwiftUI

public struct LogCard: View {
    let log: LogLine
    
    public init(log: LogLine) {
        self.log = log
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(log.level)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .cornerRadius(4)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                
                Text(formatTimestamp(log.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private var badgeColor: Color {
        switch log.level {
        case "ERROR": return .rose
        case "WARN": return .amber
        default: return .hermesTeal
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
