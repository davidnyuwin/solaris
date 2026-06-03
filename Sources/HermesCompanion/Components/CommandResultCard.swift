import SwiftUI

public struct CommandResultCard: View {
    let run: HermesRun
    
    public init(run: HermesRun) {
        self.run = run
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. User Prompt Bubble
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.hermesTeal)
                    
                    Text(run.prompt.isEmpty ? "Prompt not saved" : run.prompt)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if !run.prompt.isEmpty {
                        CopyButton(textToCopy: cleanForCopy(run.prompt), buttonLabel: "Copy")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            
            // 2. Assistant Response Bubble
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.hermesPurple)
                        
                        Text("Hermes Agent")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if run.durationMs > 0 {
                            Text("\(run.durationMs)ms")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        if !run.response.isEmpty {
                            CopyButton(textToCopy: cleanForCopy(run.response), buttonLabel: "Copy Response")
                        }
                        
                        statusBadge
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
                if run.response.isEmpty {
                    Text("Streaming response...")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    MarkdownMessageView(text: run.response)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusBorderColor, lineWidth: 1)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if run.response.contains("[Cancelled]") {
            statusTag("Cancelled", color: .rose)
        } else if run.response.contains("[Timeout]") {
            statusTag("Timeout", color: .amber)
        } else if !run.isSuccess && !run.response.isEmpty {
            statusTag("Failed", color: .rose)
        } else {
            statusTag("Completed", color: .emerald)
        }
    }
    
    private func statusTag(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
    
    private var statusBorderColor: Color {
        if run.response.contains("[Cancelled]") {
            return Color.rose.opacity(0.2)
        } else if run.response.contains("[Timeout]") {
            return Color.amber.opacity(0.2)
        } else if !run.isSuccess && !run.response.isEmpty {
            return Color.rose.opacity(0.2)
        } else {
            return Color.white.opacity(0.06)
        }
    }
}
