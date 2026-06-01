import SwiftUI

public struct HermesOrbView: View {
    let state: HermesState
    @State private var scale: CGFloat = 1.0
    @State private var rotate: Double = 0.0
    
    public init(state: HermesState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            // Glow backdrop
            Circle()
                .fill(orbColor.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 20)
                .scaleEffect(scale * 1.2)
            
            // Outer dynamic breathing ring
            Circle()
                .stroke(orbColor.opacity(0.4), lineWidth: 2)
                .frame(width: 110, height: 110)
                .scaleEffect(scale)
            
            // Rotating gradient core representing intelligence
            Circle()
                .fill(
                    LinearGradient(
                        colors: [orbColor, orbColor.opacity(0.5), orbColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(rotate))
                .shadow(color: orbColor.opacity(0.5), radius: 10)
            
            // Central core glyph
            Image(systemName: "bolt.horizontal.fill")
                .foregroundColor(.white)
                .font(.system(size: 24, weight: .bold))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                rotate = 360.0
            }
        }
    }
    
    private var orbColor: Color {
        switch state {
        case .idle: return .hermesTeal
        case .listening: return .hermesPurple
        case .processing: return .amber
        case .error: return .rose
        }
    }
}
