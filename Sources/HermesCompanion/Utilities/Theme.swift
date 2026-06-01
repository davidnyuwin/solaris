import SwiftUI

public struct Theme {
    static let primaryBackground = Color(NSColor.windowBackgroundColor)
    static let glassOverlay = Color.white.opacity(0.05)
    
    // Core brand gradients
    static let hermesGlow = LinearGradient(
        colors: [Color.hermesTeal, Color.hermesPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Custom semantic colors
    static let statusOk = Color.emerald
    static let statusWarning = Color.amber
    static let statusCritical = Color.rose
}

extension Color {
    static let hermesTeal = Color(red: 0.08, green: 0.75, blue: 0.70)
    static let hermesPurple = Color(red: 0.55, green: 0.20, blue: 0.90)
    static let hermesObsidian = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let emerald = Color(red: 0.06, green: 0.72, blue: 0.41)
    static let amber = Color(red: 0.96, green: 0.60, blue: 0.00)
    static let rose = Color(red: 0.88, green: 0.16, blue: 0.32)
}
