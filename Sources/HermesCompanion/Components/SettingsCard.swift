import SwiftUI

public struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let iconName: String?
    let content: Content
    
    public init(
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.content = content()
    }
    
    public var body: some View {
        DiagnosticPanel(title: title, subtitle: subtitle, iconName: iconName) {
            content
        }
    }
}
