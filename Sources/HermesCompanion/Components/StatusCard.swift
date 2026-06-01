import SwiftUI

public struct StatusCard: View {
    let status: HermesStatus
    
    public init(status: HermesStatus) {
        self.status = status
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HERMES METRICS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 8, height: 8)
                        Text(status.state.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uptime")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatUptime(status.uptimeSeconds))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Jobs")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(status.activeJobsCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var stateColor: Color {
        switch status.state {
        case .idle: return .emerald
        case .listening: return .hermesPurple
        case .processing: return .amber
        case .error: return .rose
        }
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}
