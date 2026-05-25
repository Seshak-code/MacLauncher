import SwiftUI
import AppKit

struct TopShelfView: View {
    @Environment(LauncherViewModel.self) var vm
    
    @State private var isAutoplayActive = false
    @State private var autoplayTimer: Timer? = nil
    @State private var kenBurnsOffset: CGFloat = 0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var trailerProgress: Double = 0.0
    @State private var trailerTimer: Timer? = nil

    private var systemVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
    
    private var processorName: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandStr = String(cString: brand)
        return brandStr.isEmpty ? "Apple Silicon" : brandStr
    }
    
    private var physicalMemoryGB: String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return "\(bytes / 1024 / 1024 / 1024) GB"
    }

    private func startAutoplayTimer(for item: LauncherItem) {
        autoplayTimer?.invalidate()
        trailerTimer?.invalidate()
        isAutoplayActive = false
        kenBurnsScale = 1.0
        kenBurnsOffset = 0
        trailerProgress = 0.0
        
        autoplayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                isAutoplayActive = true
            }
            
            // Ken Burns zoom & slow horizontal panning
            withAnimation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true)) {
                kenBurnsScale = 1.15
                kenBurnsOffset = -25
            }
            
            // Increment progress of the autoplaying preview trailer
            trailerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if trailerProgress < 1.0 {
                    trailerProgress += 0.004
                } else {
                    trailerProgress = 0.0
                }
            }
        }
    }

    var body: some View {
        ZStack {
            if let item = vm.topShelfItem {
                let accentColor = Color(hex: item.accentHex) ?? .blue
                let rgb = accentColor.rgbComponents

                ZStack {
                    // 1. Immersive Backdrop Artwork
                    if let metadata = vm.appMetadataCache[item.id],
                       let nsImage = metadata.cachedBackdrop ?? metadata.cachedImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 400)
                            .scaleEffect(kenBurnsScale)
                            .offset(x: kenBurnsOffset)
                            .clipped()
                    } else {
                        // Dynamic themed ambient gradient background
                        TimelineView(.animation) { timeline in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            let xOffset = sin(time * 0.4) * 100.0
                            let yOffset = cos(time * 0.5) * 80.0
                            
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(0.45),
                                    Color(red: rgb.0 * 0.2, green: rgb.1 * 0.2, blue: rgb.2 * 0.2).opacity(0.6),
                                    .black
                                ],
                                center: UnitPoint(x: 0.5 + xOffset / 1000.0, y: 0.4 + yOffset / 1000.0),
                                startRadius: 10,
                                endRadius: 600
                            )
                        }
                    }

                    // 2. Linear gradient shadows to fade the backdrop into the TV content layout
                    // Vertical fade from top to bottom
                    LinearGradient(
                        colors: [.black.opacity(0.15), .black.opacity(0.4), .black.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Horizontal fade from left to right to protect text readability
                    LinearGradient(
                        colors: [.black.opacity(0.85), .black.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // 3. Autoplay Trailer Ambient Light Simulation
                    if isAutoplayActive {
                        TimelineView(.animation) { timeline in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            let pulse = 0.08 * sin(time * 2.5)
                            
                            ZStack {
                                Color.clear
                                
                                RadialGradient(
                                    colors: [accentColor.opacity(0.22 + pulse), .clear],
                                    center: .bottomLeading,
                                    startRadius: 0,
                                    endRadius: 400
                                )
                            }
                        }
                        .transition(.opacity)
                    }

                    // 4. Hero Content Columns
                    HStack(spacing: 40) {
                        // Left column: Typography, Metadata tags, Description and Buttons
                        VStack(alignment: .leading, spacing: 18) {
                            
                            // Category Badge
                            HStack(spacing: 8) {
                                Text("FEATURED " + item.itemType.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(accentColor)
                                    .cornerRadius(4)
                                    .shadow(color: accentColor.opacity(0.4), radius: 6, x: 0, y: 2)

                                if isAutoplayActive {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 6, height: 6)
                                        Text("AUTOPLAY PREVIEW")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(4)
                                    .transition(.opacity)
                                }
                            }
                            
                            // Immersive Large Title
                            Text(item.name)
                                .font(.system(size: 42, weight: .heavy))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)
                            
                            // Simulated media specs (Netflix style)
                            HStack(spacing: 12) {
                                Text("98% Match")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("2026")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("TV-MA")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .border(Color.white.opacity(0.5), width: 1)
                                
                                Text("4K Ultra HD")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(3)
                                
                                Text("HDR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(3)
                            }
                            
                            // Dynamic rich description
                            let descText: String = {
                                if let metadata = vm.appMetadataCache[item.id], metadata.description != "Loading details..." {
                                    return metadata.description
                                }
                                if item.name.lowercased().contains("settings") {
                                    return "Configure launcher features, adjust overscan calibration, customize input seized modes, and inspect raw controllers diagnostics."
                                } else if item.name.lowercased().contains("calculator") {
                                    return "Perform quick mathematical operations with full gamepad D-pad and button mapping integration."
                                } else if item.name.lowercased().contains("chess") {
                                    return "Play a classic game of Chess. Spotlight previews show ongoing matches, statistics, and scores."
                                } else if item.name.lowercased().contains("terminal") {
                                    return "Execute zsh and bash scripting commands. Integrates virtual overlay keyboard typing."
                                }
                                return item.subtitle ?? "Launch \(item.name) directly on your Apple TV inspired interface."
                            }()
                            
                            Text(descText)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(3)
                                .frame(maxWidth: 550, alignment: .leading)
                                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                            
                            Spacer()
                            
                            // Netflix-style Action Buttons
                            HStack(spacing: 16) {
                                let isTopShelfFocused = vm.focusedPosition.sectionIndex == -1
                                
                                let primaryLabel: String = {
                                    if item.name.lowercased().contains("youtube") || item.itemType == .website {
                                        return "Play Trailer"
                                    }
                                    return "Open App"
                                }()
                                
                                TopShelfButton(
                                    label: primaryLabel,
                                    iconName: primaryLabel.contains("Trailer") ? "play.fill" : "arrow.up.right.square.fill",
                                    isFocused: isTopShelfFocused && vm.focusedPosition.itemIndex == 0,
                                    accentColor: .white
                                ) {
                                    vm.focusedPosition.itemIndex = 0
                                    vm.activateFocused()
                                }
                                
                                TopShelfButton(
                                    label: "Favorite",
                                    iconName: "star.fill",
                                    isFocused: isTopShelfFocused && vm.focusedPosition.itemIndex == 1,
                                    accentColor: .white.opacity(0.15)
                                ) {
                                    vm.focusedPosition.itemIndex = 1
                                    vm.activateFocused()
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Right column: Live state / system metrics or interactive mockups (hidden during autoplay)
                        if !isAutoplayActive {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.45))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                
                                if item.name.lowercased().contains("settings") {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text("SYSTEM DIAGNOSTICS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.4))
                                        
                                        SystemMetricRow(label: "OS Version", value: systemVersion)
                                        SystemMetricRow(label: "Processor", value: processorName)
                                        SystemMetricRow(label: "Memory", value: physicalMemoryGB)
                                        SystemMetricRow(label: "Gamepad Status", value: vm.isControllerConnected ? "CONNECTED" : "DISCONNECTED")
                                    }
                                    .padding(24)
                                } else if item.name.lowercased().contains("chess") {
                                    VStack(spacing: 8) {
                                        Text("SPOTLIGHT: CLASSIC CHESS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.4))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        GridBoardView()
                                            .frame(width: 130, height: 130)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(8)
                                        
                                        Text("Turn: White • 32 Moves")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(16)
                                } else {
                                    // Styled App logo fallback
                                    VStack(spacing: 16) {
                                        if let bundleID = item.iconBundleID,
                                           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                                            Image(nsImage: appIcon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 72, height: 72)
                                                .cornerRadius(16)
                                                .shadow(color: accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                                        } else {
                                            Text(item.iconEmoji)
                                                .font(.system(size: 64))
                                                .shadow(radius: 8)
                                        }
                                        
                                        Text("MACLAUNCHER TV")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.5))
                                            .tracking(2)
                                    }
                                }
                            }
                            .frame(width: 280, height: 210)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    
                    // 5. Autoplay trailer progress bar at the very bottom
                    if isAutoplayActive {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 4)
                                    
                                    Rectangle()
                                        .fill(accentColor)
                                        .frame(width: geo.size.width * CGFloat(trailerProgress), height: 4)
                                }
                            }
                        }
                        .frame(height: 4)
                        .transition(.opacity)
                    }
                }
                .frame(height: 400)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .onAppear {
                    startAutoplayTimer(for: item)
                }
                .onChange(of: item) { _, newItem in
                    startAutoplayTimer(for: newItem)
                }
            } else {
                // Splash welcome
                HStack(spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow.opacity(0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome to MacLauncher TV")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Use the left stick or D-pad to navigate. Push UP on the top row to focus here.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(24)
                .frame(height: 400)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                )
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .frame(height: 400)
        .onDisappear {
            autoplayTimer?.invalidate()
            trailerTimer?.invalidate()
        }
    }
}

// Focusable Button helper for Top Shelf
struct TopShelfButton: View {
    let label: String
    let iconName: String
    let isFocused: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                isFocused
                ? Color.white
                : Color.white.opacity(0.12)
            )
            .foregroundColor(isFocused ? .black : .white)
            .cornerRadius(10)
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(color: isFocused ? .white.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Layout helpers
struct SystemMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

struct GridBoardView: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<8) { row in
                HStack(spacing: 2) {
                    ForEach(0..<8) { col in
                        let isDark = (row + col) % 2 == 1
                        Rectangle()
                            .fill(isDark ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
                            .overlay(
                                Group {
                                    if row == 6 && col == 4 {
                                        Text("♙").font(.system(size: 10)).foregroundColor(.white)
                                    } else if row == 7 && col == 4 {
                                        Text("♔").font(.system(size: 10)).foregroundColor(.white)
                                    } else if row == 1 && col == 4 {
                                        Text("♟").font(.system(size: 10)).foregroundColor(.black)
                                    } else if row == 0 && col == 4 {
                                        Text("♚").font(.system(size: 10)).foregroundColor(.black)
                                    }
                                }
                            )
                    }
                }
            }
        }
        .padding(4)
    }
}

// Translucent window helper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
