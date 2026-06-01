import SwiftUI

public struct ProviderCard: View {
    let provider: ProviderHealth
    
    public init(provider: ProviderHealth) {
        self.provider = provider
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Text(provider.isOnline ? "Online • \(provider.latencyMs)ms latency" : "Offline")
                    .font(.system(size: 11))
                    .foregroundColor(provider.isOnline ? .white.opacity(0.6) : .rose.opacity(0.8))
            }
            Spacer()
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(provider.successRate * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text("success")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Circle()
                    .fill(provider.isOnline ? Color.emerald : Color.rose)
                    .frame(width: 8, height: 8)
                    .shadow(color: provider.isOnline ? Color.emerald.opacity(0.5) : Color.rose.opacity(0.5), radius: 4)
            }
        }
        .padding(12)
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
