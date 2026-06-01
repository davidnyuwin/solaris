import SwiftUI

public struct CommandResultCard: View {
    let run: HermesRun
    
    public init(run: HermesRun) {
        self.run = run
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.hermesTeal)
                    Text(run.prompt)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(run.durationMs)ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Circle()
                        .fill(run.isSuccess ? Color.emerald : Color.rose)
                        .frame(width: 6, height: 6)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            Text(run.response)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: false)
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
