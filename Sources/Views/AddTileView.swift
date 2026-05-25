import SwiftUI

struct AddTileView: View {
    let sectionID: UUID
    let position: FocusPosition
    let isFocused: Bool

    @Environment(LauncherViewModel.self) var vm
    @Environment(TileFrameRegistry.self) var registry

    private var cardWidth: CGFloat { 290 }
    private var cardHeight: CGFloat { 165 }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Dashed border card container
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isFocused ? .white.opacity(0.12) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isFocused ? .white.opacity(0.7) : .white.opacity(0.2),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .miter, miterLimit: 10, dash: [6, 4], dashPhase: 0)
                            )
                    )
                    .shadow(color: isFocused ? .white.opacity(0.1) : .clear, radius: 15, x: 0, y: 8)

                // Plus Icon
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.4))
            }
            .frame(width: cardWidth, height: cardHeight)
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .offset(y: isFocused ? -6 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isFocused)

            // Label
            Text("Add Shortcut")
                .font(.system(size: 14, weight: isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? .white : .white.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: cardWidth - 10)
        }
        .frame(width: cardWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.addTargetSectionID = sectionID
            vm.isAddingItem = true
        }
        
        // Report frames to Registry for mouse snapping
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        registry.frames[position] = frame
                    }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        registry.frames[position] = frame
                    }
            }
        )
    }
}
