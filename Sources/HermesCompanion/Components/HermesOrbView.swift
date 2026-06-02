import SwiftUI

public struct HermesOrbView: View {
    let state: HermesState
    @State private var scale: CGFloat = 1.0
    @State private var rotate: Double = 0.0
    @State private var rotateCounter: Double = 0.0
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(state: HermesState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            // 1. Soft Blue/Violet Edge Glow (Gives deep volumetric perspective)
            Circle()
                .fill(RadialGradient(
                    colors: [Color.indigo.opacity(0.18), Color.blue.opacity(0.04), Color.clear],
                    center: .center,
                    startRadius: 5,
                    endRadius: 100
                ))
                .frame(width: 200, height: 200)
                .blur(radius: 20)
                .scaleEffect(scale * 1.1)
            
            // 2. Base Glow Backdrop (Breathing)
            Circle()
                .fill(RadialGradient(
                    colors: [coreGradient[0].opacity(0.35), coreGradient[1].opacity(0.12), Color.clear],
                    center: .center,
                    startRadius: 5,
                    endRadius: 80
                ))
                .frame(width: 160, height: 160)
                .blur(radius: 15)
                .scaleEffect(scale)
            
            // 3. Volumetric Mid Layer (Rotating Clockwise)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [coreGradient[1].opacity(0.85), coreGradient[2].opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 115, height: 115)
                .rotationEffect(.degrees(rotate))
                .blur(radius: 8)
                .scaleEffect(scale * 0.95)
            
            // 4. Solaris Volumetric Core (Counter-Rotating & breathing)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [coreGradient[0], coreGradient[1].opacity(0.75), coreGradient[2].opacity(0.1)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 40
                    )
                )
                .frame(width: 85, height: 85)
                .rotationEffect(.degrees(rotateCounter))
                .shadow(color: coreGradient[0].opacity(0.55), radius: 15)
                .scaleEffect(scale * 0.9)
            
            // 5. Ambient highlights for volumetric solar feel
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: 75, height: 75)
                .blur(radius: 2)
                .scaleEffect(scale * 0.85)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    scale = 1.06
                }
                withAnimation(.linear(duration: 14.0).repeatForever(autoreverses: false)) {
                    rotate = 360.0
                }
                withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                    rotateCounter = -360.0
                }
            }
        }
    }
    
    private var coreGradient: [Color] {
        switch state {
        case .idle:
            // Solaris Teal Core
            return [
                Color(red: 0.1, green: 0.8, blue: 0.7),
                Color(red: 0.05, green: 0.5, blue: 0.6),
                Color(red: 0.0, green: 0.2, blue: 0.3)
            ]
        case .listening:
            // Deep purple-indigo with solar orange-amber highlights
            return [
                Color(red: 0.55, green: 0.2, blue: 0.9),
                Color(red: 0.92, green: 0.58, blue: 0.1),
                Color(red: 0.18, green: 0.08, blue: 0.45)
            ]
        case .processing:
            // High flare amber-orange-gold
            return [
                Color(red: 1.0, green: 0.82, blue: 0.15),
                Color(red: 1.0, green: 0.42, blue: 0.0),
                Color(red: 0.62, green: 0.1, blue: 0.0)
            ]
        case .error:
            // Deep solar rose-crimson
            return [
                Color(red: 0.92, green: 0.12, blue: 0.32),
                Color(red: 0.52, green: 0.0, blue: 0.2),
                Color(red: 0.22, green: 0.0, blue: 0.12)
            ]
        }
    }
}
