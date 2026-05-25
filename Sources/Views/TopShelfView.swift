import SwiftUI
import AppKit

struct TopShelfView: View {
    @Environment(LauncherViewModel.self) var vm
    
    // For rendering system info
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

    var body: some View {
        ZStack {
            // Glassmorphic background blur
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            if let item = vm.topShelfItem {
                HStack(spacing: 40) {
                    // Left Column: Previews and dynamic visuals
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Icon
                            if item.itemType == .website,
                               let metadata = vm.webMetadataCache[item.url],
                               let nsImage = metadata.cachedImage {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(10)
                            } else if let bundleID = item.iconBundleID,
                                      let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(10)
                            } else {
                                Text(item.iconEmoji)
                                    .font(.system(size: 38))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.itemType == .website ? (vm.webMetadataCache[item.url]?.title ?? item.name) : item.name)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text(item.itemType.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: item.accentHex)?.opacity(0.8) ?? .blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Description (Web-fetched or fallback)
                        let descText: String = {
                            if item.itemType == .website {
                                return vm.webMetadataCache[item.url]?.description ?? "Loading site description..."
                            } else if item.name.lowercased().contains("settings") {
                                return "Configure launcher features, adjust overscan calibration, customize input seized modes, and inspect raw controllers diagnostics."
                            } else if item.name.lowercased().contains("calculator") {
                                return "Perform quick mathematical operations with full gamepad D-pad and button mapping integration."
                            } else if item.name.lowercased().contains("chess") {
                                return "Play a classic game of Chess. Spotlight previews show ongoing matches, statistics, and scores."
                            } else if item.name.lowercased().contains("terminal") {
                                return "Execute zsh and bash scripting commands. Integrates virtual overlay keyboard typing."
                            }
                            return "Launch \(item.name) directly on your Apple TV inspired interface."
                        }()
                        
                        Text(descText)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(4)
                            .frame(maxWidth: 400, alignment: .leading)
                        
                        Spacer()
                        
                        // Focusable Buttons Row
                        HStack(spacing: 16) {
                            let isTopShelfFocused = vm.focusedPosition.sectionIndex == -1
                            
                            // Button 0 (Primary)
                            let primaryLabel: String = {
                                if item.name.lowercased().contains("youtube") || item.itemType == .website {
                                    return "Play Trailer"
                                }
                                return "Open Application"
                            }()
                            
                            TopShelfButton(
                                label: primaryLabel,
                                iconName: "play.fill",
                                isFocused: isTopShelfFocused && vm.focusedPosition.itemIndex == 0,
                                accentColor: Color(hex: item.accentHex) ?? .blue
                            ) {
                                vm.focusedPosition.itemIndex = 0
                                vm.activateFocused()
                            }
                            
                            // Button 1 (Secondary)
                            TopShelfButton(
                                label: "Favorite",
                                iconName: "star.fill",
                                isFocused: isTopShelfFocused && vm.focusedPosition.itemIndex == 1,
                                accentColor: .gray
                            ) {
                                vm.focusedPosition.itemIndex = 1
                                vm.activateFocused()
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Column: Gorgeous graphics / live state previews
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        
                        if item.name.lowercased().contains("settings") {
                            // Settings Diagnostics preview
                            VStack(alignment: .leading, spacing: 14) {
                                Text("SYSTEM DIAGNOSTICS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                SystemMetricRow(label: "OS Version", value: systemVersion)
                                SystemMetricRow(label: "Processor", value: processorName)
                                SystemMetricRow(label: "Memory", value: physicalMemoryGB)
                                SystemMetricRow(label: "Gamepad Status", value: vm.isControllerConnected ? "CONNECTED" : "DISCONNECTED")
                                if vm.isControllerConnected {
                                    SystemMetricRow(label: "Gamepad Name", value: vm.connectedControllerName)
                                }
                            }
                            .padding(24)
                        } else if item.name.lowercased().contains("youtube") {
                            // YouTube Cinematic preview mockup
                            ZStack {
                                Image(systemName: "play.tv")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Spacer()
                                    Text("Featured: Apple Vision Pro - Guided Tour")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Simulated 4K Streaming Trailer")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                )
                                .cornerRadius(16)
                            }
                        } else if item.name.lowercased().contains("chess") {
                            // Chess board preview mockup
                            VStack(spacing: 8) {
                                Text("SPOTLIGHT: CLASSIC CHESS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                GridBoardView()
                                    .frame(width: 140, height: 140)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                
                                Text("Turn: White (You) • 32 Moves")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(16)
                        } else if item.itemType == .website {
                            // General website preview card
                            VStack(spacing: 12) {
                                if let metadata = vm.webMetadataCache[item.url],
                                   metadata.logoURL != nil {
                                    Text("WEBSITE DETAIL STREAM")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    Spacer()
                                    Image(systemName: "globe")
                                        .font(.system(size: 50))
                                        .foregroundColor(Color(hex: item.accentHex) ?? .blue)
                                        .opacity(0.8)
                                    Spacer()
                                    Text(item.url)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .lineLimit(1)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Fetching open-graph data...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(24)
                        } else {
                            // Default MacLauncher splash
                            VStack(spacing: 12) {
                                Image(systemName: "appletv")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("MACLAUNCHER BIG SCREEN")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("tvOS Design System")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .frame(width: 280, height: 200)
                }
                .padding(24)
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
            }
        }
        .frame(height: 240)
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
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                isFocused
                ? accentColor
                : Color.white.opacity(0.08)
            )
            .foregroundColor(isFocused ? .white : .white.opacity(0.8))
            .cornerRadius(10)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? accentColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 4)
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
