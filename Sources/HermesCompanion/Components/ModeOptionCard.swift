import SwiftUI

public struct ModeOptionCard: View {
    let mode: HermesServiceMode
    let isSelected: Bool
    let statusText: String
    let statusColor: Color
    let iconName: String
    let description: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    public init(
        mode: HermesServiceMode,
        isSelected: Bool,
        statusText: String,
        statusColor: Color,
        iconName: String,
        description: String,
        action: @escaping () -> Void
    ) {
        self.mode = mode
        self.isSelected = isSelected
        self.statusText = statusText
        self.statusColor = statusColor
        self.iconName = iconName
        self.description = description
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(isSelected ? Color.hermesTeal.opacity(0.15) : Color.white.opacity(0.04))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isSelected ? .hermesTeal : .white.opacity(0.6))
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                        
                        Text(statusText)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(statusColor.opacity(0.12))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Selected Check Indicator
                    Circle()
                        .stroke(isSelected ? Color.hermesTeal : Color.white.opacity(0.15), lineWidth: 1.5)
                        .fill(isSelected ? Color.hermesTeal : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                                .opacity(isSelected ? 1 : 0)
                        )
                }
                
                Text(description)
                    .font(.system(size: 10.5))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .white.opacity(0.45))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.02) : Color.white.opacity(0.01))
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .cornerRadius(10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected 
                                    ? Color.hermesTeal.opacity(0.4) 
                                    : (isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.06)),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
        }
    }
}
