import SwiftUI

public struct LocalDiagnosticsCard: View {
    let status: HermesStatus
    
    public init(status: HermesStatus) {
        self.status = status
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCAL DIAGNOSTICS SWEEP")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                // Gateway Process
                HStack {
                    Label("Gateway Process", systemImage: "cpu")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if status.gatewayRunning == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emerald)
                            Text("Detected")
                                .foregroundColor(.emerald)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.rose)
                            Text("Not Detected")
                                .foregroundColor(.rose)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                // Dashboard API
                HStack {
                    Label("Dashboard API (Port 9119)", systemImage: "network")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if status.dashboardAvailable == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emerald)
                            Text("Available")
                                .foregroundColor(.emerald)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.amber)
                            Text("Unavailable")
                                .foregroundColor(.amber)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                // Agent Log
                HStack {
                    Label("Agent Log File", systemImage: "doc.text")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if status.agentLogFound == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emerald)
                            Text("Found")
                                .foregroundColor(.emerald)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.rose)
                            Text("Missing")
                                .foregroundColor(.rose)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                // Gateway Log
                HStack {
                    Label("Gateway Log File", systemImage: "doc.text")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if status.gatewayLogFound == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.emerald)
                            Text("Found")
                                .foregroundColor(.emerald)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.rose)
                            Text("Missing")
                                .foregroundColor(.rose)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
            }
            
            // Diagnostics paths warning/info
            if status.gatewayRunning == false {
                Text("⚠️ To resolve process issues, launch the background daemon using command:\n`hermes gateway install` or `hermes gateway run --replace`")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
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
}
