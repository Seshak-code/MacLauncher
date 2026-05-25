import SwiftUI
import AppKit

struct TileView: View {
    let item: LauncherItem
    let position: FocusPosition
    let isFocused: Bool

    @Environment(LauncherViewModel.self) var vm
    @Environment(TileFrameRegistry.self) var registry

    // Parallax tilt states from mouse hover
    @State private var tiltWidth: CGFloat = 0.0
    @State private var tiltHeight: CGFloat = 0.0

    // Micro-animation states
    @State private var gearRotation: Double = 0.0
    @State private var bounceOffset: CGFloat = 0.0
    @State private var sheenOffset: CGFloat = -350.0

    private var accentColor: Color {
        Color(hex: item.accentHex) ?? .blue
    }
    
    private var rgb: (Double, Double, Double) {
        accentColor.rgbComponents
    }

    private var cardWidth: CGFloat { 290 }
    private var cardHeight: CGFloat { 165 }

    private var finalTiltWidth: CGFloat {
        let hover = tiltWidth
        let controller = isFocused ? CGFloat(vm.liveLeftStickX) * 0.8 : 0.0
        return hover + controller
    }

    private var finalTiltHeight: CGFloat {
        let hover = tiltHeight
        let controller = isFocused ? CGFloat(vm.liveLeftStickY) * 0.8 : 0.0
        return hover + controller
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Base frosted card
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        isFocused
                        ? Color(red: rgb.0, green: rgb.1, blue: rgb.2).opacity(0.22)
                        : Color.white.opacity(0.06)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isFocused
                                ? accentColor.opacity(0.8)
                                : Color.white.opacity(0.08),
                                lineWidth: isFocused ? 2.5 : 1.0
                            )
                    )
                    // High elevation glow shadow on focus, offset dynamically by tilt
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.5) : .clear,
                        radius: isFocused ? 28 : 0,
                        x: isFocused ? finalTiltWidth * -15.0 : 0,
                        y: isFocused ? finalTiltHeight * 15.0 + 10.0 : 0
                    )

                // Background artwork if dynamic metadata is available (Netflix style)
                if let metadata = vm.appMetadataCache[item.id],
                   let nsImage = metadata.cachedImage ?? metadata.cachedBackdrop {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .cornerRadius(22)
                        .overlay(
                            // Dark gradient overlay for text readability
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Fallback visual layout (Frosted panel with centered App icon/Emoji)
                    Group {
                        if let bundleID = item.iconBundleID,
                           !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            
                            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .cornerRadius(16)
                                .rotationEffect(.degrees(gearRotation))
                                .offset(y: bounceOffset)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        } else {
                            // Fallback styled emoji
                            Text(item.iconEmoji)
                                .font(.system(size: 60))
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                                .rotationEffect(.degrees(gearRotation))
                                .offset(y: bounceOffset)
                        }
                    }
                }

                // Glossy Sheen Overlay Sweep
                if isFocused {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .offset(x: sheenOffset)
                    .mask(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .onAppear {
                        sheenOffset = -cardWidth - 50
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            sheenOffset = cardWidth + 50
                        }
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            
            // 3D Parallax Tilt Effects
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .offset(y: isFocused ? -6 : 0)
            .rotation3DEffect(
                .degrees(Double(finalTiltHeight * -14.0)),
                axis: (x: 1.0, y: 0.0, z: 0.0)
            )
            .rotation3DEffect(
                .degrees(Double(finalTiltWidth * 14.0)),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .onContinuousHover { phase in
                guard isFocused else { return }
                switch phase {
                case .active(let point):
                    let dx = point.x - (cardWidth / 2.0)
                    let dy = point.y - (cardHeight / 2.0)
                    tiltWidth = dx / (cardWidth / 2.0)
                    tiltHeight = dy / (cardHeight / 2.0)
                case .ended:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        tiltWidth = 0.0
                        tiltHeight = 0.0
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isFocused)

            // Label
            VStack(spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: isFocused ? .semibold : .regular))
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: cardWidth - 10)
                
                let subtitleText: String = {
                    if let metadata = vm.appMetadataCache[item.id], metadata.description != "Loading details..." {
                        return metadata.description
                    }
                    return item.subtitle ?? ""
                }()
                
                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isFocused ? .white.opacity(0.7) : .white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: cardWidth - 10)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .frame(width: cardWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.focusedPosition = position
            vm.updateAccent(for: item)
            vm.activateFocused()
        }
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
        .contextMenu {
            Button(role: .destructive) {
                if let sec = vm.sections.first(where: { $0.items.contains(where: { $0.id == item.id }) }) {
                    vm.removeItem(id: item.id, fromSectionID: sec.id)
                }
            } label: {
                Label("Delete Shortcut", systemImage: "trash")
            }
        }
        .onChange(of: isFocused, initial: true) { _, focused in
            // Always fetch metadata on load/focus
            vm.fetchAppMetadata(for: item)
            
            if focused {
                vm.updateAccent(for: item)
                
                // Micro-animations
                let isSettings = item.iconBundleID == "com.apple.systempreferences" || item.name.lowercased().contains("settings") || item.iconEmoji == "⚙️"
                if isSettings {
                    withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                        gearRotation = 360.0
                    }
                }
                
                let isGame = item.itemType == .game || item.name.lowercased().contains("chess")
                if isGame {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        bounceOffset = -8.0
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    gearRotation = 0.0
                    bounceOffset = 0.0
                }
            }
        }
        .onAppear {
            vm.fetchAppMetadata(for: item)
            if isFocused {
                vm.updateAccent(for: item)
            }
        }
    }
}
