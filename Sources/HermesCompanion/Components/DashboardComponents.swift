import SwiftUI

struct SummaryRow: View {
    let label: String
    let val: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(val)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
    }
}

struct DashboardSummaryCard: View {
    let mode: HermesServiceMode
    let status: HermesStatus?
    
    var body: some View {
        DiagnosticPanel(
            title: "System Summary",
            subtitle: "Solaris operational pathway status.",
            iconName: "info.circle.fill"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                SummaryRow(label: "Mode", val: mode.displayName, color: modeColor)
                SummaryRow(
                    label: "Gateway",
                    val: status?.state.rawValue ?? "Offline",
                    color: statusColor
                )
                SummaryRow(
                    label: "Uptime",
                    val: formatUptime(status?.uptimeSeconds ?? 0),
                    color: .white.opacity(0.8)
                )
                SummaryRow(
                    label: "Active Jobs",
                    val: "\(status?.activeJobsCount ?? 0)",
                    color: .white.opacity(0.8)
                )
            }
        }
    }
    
    private var modeColor: Color {
        switch mode {
        case .mock: return .emerald
        case .diagnostics: return .hermesTeal
        case .rest: return .amber
        }
    }
    
    private var statusColor: Color {
        guard let state = status?.state else { return .rose }
        switch state {
        case .idle: return .emerald
        case .listening: return .hermesPurple
        case .processing: return .amber
        case .error: return .rose
        }
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0h 0m" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}

struct ActivityMiniCard: View {
    let runs: [HermesRun]
    
    var body: some View {
        DiagnosticPanel(
            title: "Recent Activity",
            subtitle: "Latest execution timeline records.",
            iconName: "clock.arrow.circlepath"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if runs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.horizontal")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No recent activity")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(runs.prefix(3)) { run in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(run.prompt)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Circle()
                                    .fill(run.isSuccess ? Color.emerald : Color.rose)
                                    .frame(width: 5, height: 5)
                            }
                            
                            Text(run.response)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.015))
                        .cornerRadius(6)
                        
                        if run.id != runs.prefix(3).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.04))
                        }
                    }
                }
            }
        }
    }
}

struct LatestSignalCard: View {
    let logs: [LogLine]
    
    var body: some View {
        let latest = logs.first
        
        return DiagnosticPanel(
            title: "Latest Signal",
            subtitle: "Most recent operational log event.",
            iconName: "waveform.path"
        ) {
            HStack(spacing: 10) {
                if let log = latest {
                    Circle()
                        .fill(badgeColor(log.level).opacity(0.12))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: badgeIcon(log.level))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(badgeColor(log.level))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(log.level)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(badgeColor(log.level))
                            
                            Text(formatTimestamp(log.timestamp))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        
                        Text(log.message)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Circle()
                        .fill(Color.emerald.opacity(0.12))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.emerald)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Stable")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("All local pathways reporting healthy.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(latest != nil ? "Latest signal" : "Latest signal: System stable")
            .accessibilityValue(latest.map { "\($0.level): \($0.message)" } ?? "All local pathways reporting healthy")
        }
    }
    
    private func badgeColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "ERROR", "CRITICAL", "ERR": return .rose
        case "WARN", "WARNING": return .amber
        default: return .hermesTeal
        }
    }
    
    private func badgeIcon(_ level: String) -> String {
        switch level.uppercased() {
        case "ERROR", "CRITICAL", "ERR": return "exclamationmark.triangle.fill"
        case "WARN", "WARNING": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct SuggestedActionCard: View {
    let mode: HermesServiceMode
    let status: HermesStatus?
    let onAction: () -> Void
    
    var body: some View {
        let subtitle: String
        let buttonText: String
        let icon: String
        
        switch mode {
        case .mock:
            subtitle = "Perform a mock system scan check."
            buttonText = "Execute Demo Scan"
            icon = "bolt.fill"
        case .diagnostics:
            subtitle = "Review local logs and processes."
            buttonText = "Inspect System Checks"
            icon = "doc.text.magnifyingglass"
        case .rest:
            subtitle = "Live REST API daemon is unavailable."
            buttonText = "Swap to Mock Mode"
            icon = "network"
        }
        
        return DiagnosticPanel(
            title: "Suggested Action",
            subtitle: subtitle,
            iconName: "lightbulb.fill"
        ) {
            Button(action: onAction) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(buttonText)
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.hermesTeal.opacity(0.12))
                .foregroundColor(.hermesTeal)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hermesTeal.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel(buttonText)
            .accessibilityHint(subtitle)
        }
    }
}

public struct DashboardContextRail: View {
    let mode: HermesServiceMode
    let status: HermesStatus?
    let runs: [HermesRun]
    let logs: [LogLine]
    let onQuickAction: (String) -> Void
    let onSwapMode: (HermesServiceMode) -> Void
    
    public init(
        mode: HermesServiceMode,
        status: HermesStatus?,
        runs: [HermesRun],
        logs: [LogLine],
        onQuickAction: @escaping (String) -> Void,
        onSwapMode: @escaping (HermesServiceMode) -> Void
    ) {
        self.mode = mode
        self.status = status
        self.runs = runs
        self.logs = logs
        self.onQuickAction = onQuickAction
        self.onSwapMode = onSwapMode
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            DashboardSummaryCard(mode: mode, status: status)
            
            ActivityMiniCard(runs: runs)
            
            LatestSignalCard(logs: logs)
            
            SuggestedActionCard(mode: mode, status: status) {
                switch mode {
                case .mock:
                    onQuickAction("Check relay health")
                case .diagnostics:
                    onQuickAction("Summarize latest logs")
                case .rest:
                    onSwapMode(.mock)
                }
            }
        }
    }
}
