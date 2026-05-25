import SwiftUI

struct BackgroundView: View {
    var accentColor: Color

    var body: some View {
        ZStack {
            // Moody dark space background
            Color(red: 0.03, green: 0.03, blue: 0.05)
                .ignoresSafeArea()

            // Dynamic top radial glow, interpolates color based on focus
            RadialGradient(
                colors: [accentColor.opacity(0.24), .clear],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 800
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.4), value: accentColor)

            // Deep blue atmospheric ambient glow (static top-left)
            RadialGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.4).opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            // Soft purple atmospheric ambient glow (static bottom-right)
            RadialGradient(
                colors: [Color(red: 0.3, green: 0.05, blue: 0.3).opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}
