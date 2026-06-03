import SwiftUI

public struct CommandBar: View {
    @Binding var text: String
    let isPending: Bool
    let onSend: () -> Void
    let onCancel: (() -> Void)?
    
    public init(text: Binding<String>, isPending: Bool, onSend: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self._text = text
        self.isPending = isPending
        self.onSend = onSend
        self.onCancel = onCancel
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            
            TextField("Enter diagnostic command...", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 12.5))
                .onSubmit {
                    if !isPending && !text.isEmpty {
                        onSend()
                    }
                }
            
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            
            Button(action: {
                if isPending {
                    onCancel?()
                } else {
                    onSend()
                }
            }) {
                if isPending {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.rose)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(text.isEmpty ? .white.opacity(0.2) : .hermesTeal)
                        .font(.system(size: 18))
                }
            }
            .buttonStyle(.plain)
            .disabled(!isPending && text.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.015))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .cornerRadius(24)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
