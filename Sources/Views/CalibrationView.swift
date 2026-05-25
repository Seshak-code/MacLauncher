import SwiftUI

struct CalibrationView: View {
    @Environment(LauncherViewModel.self) var vm

    var body: some View {
        ZStack {
            // Dark solid background
            Color(red: 0.02, green: 0.02, blue: 0.03)
                .ignoresSafeArea()

            // Outer Boundary Guide lines (Red border to indicate limits)
            GeometryReader { geo in
                ZStack {
                    // Top-Left L-shaped bracket
                    Path { path in
                        path.move(to: CGPoint(x: 40, y: 10))
                        path.addLine(to: CGPoint(x: 10, y: 10))
                        path.addLine(to: CGPoint(x: 10, y: 40))
                    }
                    .stroke(Color.red, lineWidth: 4)

                    // Top-Right L-shaped bracket
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width - 40, y: 10))
                        path.addLine(to: CGPoint(x: geo.size.width - 10, y: 10))
                        path.addLine(to: CGPoint(x: geo.size.width - 10, y: 40))
                    }
                    .stroke(Color.red, lineWidth: 4)

                    // Bottom-Left L-shaped bracket
                    Path { path in
                        path.move(to: CGPoint(x: 40, y: geo.size.height - 10))
                        path.addLine(to: CGPoint(x: 10, y: geo.size.height - 10))
                        path.addLine(to: CGPoint(x: 10, y: geo.size.height - 40))
                    }
                    .stroke(Color.red, lineWidth: 4)

                    // Bottom-Right L-shaped bracket
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width - 40, y: geo.size.height - 10))
                        path.addLine(to: CGPoint(x: geo.size.width - 10, y: geo.size.height - 10))
                        path.addLine(to: CGPoint(x: geo.size.width - 10, y: geo.size.height - 40))
                    }
                    .stroke(Color.red, lineWidth: 4)
                }
            }
            .ignoresSafeArea()

            // Calibration Instructions panel
            VStack(spacing: 24) {
                Text("📺 Overscan Calibration")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Adjust the screen margins until the red boundary brackets align perfectly with your TV screen edges.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)

                // Current margins
                VStack(spacing: 10) {
                    HStack(spacing: 40) {
                        VStack {
                            Text("Horizontal Offset")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                            Text("\(Int(vm.overscanHorizontal)) pt")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack {
                            Text("Vertical Offset")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                            Text("\(Int(vm.overscanVertical)) pt")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(20)
                    .background(.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                }

                // Controls Info
                VStack(spacing: 8) {
                    Text("← / →  adjusts horizontal margins")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("↑ / ↓  adjusts vertical margins")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Press [A / Return] to Save & Exit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.top, 10)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
    }
}
