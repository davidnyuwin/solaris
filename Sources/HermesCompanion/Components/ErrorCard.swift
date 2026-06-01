import SwiftUI

public struct ErrorCard: View {
    let message: String
    
    public init(message: String) {
        self.message = message
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.rose)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Alert")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.rose.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.rose.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
