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
    @State private var sheenOffset: CGFloat = -220.0

    private var accentColor: Color {
        Color(hex: item.accentHex) ?? .blue
    }
    
    private var rgb: (Double, Double, Double) {
        accentColor.rgbComponents
    }

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
        VStack(spacing: 12) {
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
                                lineWidth: isFocused ? 2.0 : 1.0
                            )
                    )
                    // High elevation glow shadow on focus, offset dynamically by tilt
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.45) : .clear,
                        radius: isFocused ? 26 : 0,
                        x: isFocused ? finalTiltWidth * -12.0 : 0,
                        y: isFocused ? finalTiltHeight * 12.0 + 10.0 : 0
                    )

                // Icon (Emoji, Web-streamed Icon or App Icon)
                Group {
                    if item.itemType == .website,
                       let metadata = vm.webMetadataCache[item.url],
                       let nsImage = metadata.cachedImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .cornerRadius(12)
                    } else if let bundleID = item.iconBundleID,
                       !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        
                        let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .cornerRadius(12)
                            .rotationEffect(.degrees(gearRotation))
                            .offset(y: bounceOffset)
                    } else {
                        // Fallback styled emoji
                        Text(item.iconEmoji)
                            .font(.system(size: 44))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .rotationEffect(.degrees(gearRotation))
                            .offset(y: bounceOffset)
                    }
                }

                // Glossy Sheen Overlay Sweep
                if isFocused {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 170, height: 110)
                    .offset(x: sheenOffset)
                    .mask(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .onAppear {
                        sheenOffset = -220.0
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            sheenOffset = 220.0
                        }
                    }
                }
            }
            .frame(width: 170, height: 110)
            
            // 3D Parallax Tilt Effects
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .offset(y: isFocused ? -4 : 0)
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
                    let dx = point.x - 85.0 // half of 170
                    let dy = point.y - 55.0 // half of 110
                    tiltWidth = dx / 85.0
                    tiltHeight = dy / 55.0
                case .ended:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        tiltWidth = 0.0
                        tiltHeight = 0.0
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isFocused)

            // Label
            VStack(spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: isFocused ? .semibold : .regular))
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 160)
                
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(isFocused ? .white.opacity(0.75) : .white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 160)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .frame(width: 170)
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
            if focused {
                vm.updateAccent(for: item)
                
                // Trigger web metadata fetch if website
                if item.itemType == .website {
                    vm.fetchWebMetadata(for: item.url)
                }

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
            if isFocused {
                vm.updateAccent(for: item)
                if item.itemType == .website {
                    vm.fetchWebMetadata(for: item.url)
                }
            }
        }
    }
}
