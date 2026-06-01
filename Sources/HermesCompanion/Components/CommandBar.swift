import SwiftUI

public struct CommandBar: View {
    @Binding var text: String
    let isPending: Bool
    let onSend: () -> Void
    
    public init(text: Binding<String>, isPending: Bool, onSend: @escaping () -> Void) {
        self._text = text
        self.isPending = isPending
        self.onSend = onSend
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            TextField("Ask Hermes a command...", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 13))
                .onSubmit {
                    if !isPending && !text.isEmpty {
                        onSend()
                    }
                }
            
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Button(action: onSend) {
                if isPending {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(text.isEmpty ? .white.opacity(0.3) : .hermesTeal)
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty || isPending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
