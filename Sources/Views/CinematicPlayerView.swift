import SwiftUI
import AppKit

struct CinematicPlayerView: View {
    @Environment(LauncherViewModel.self) var vm
    @State private var isHudVisible: Bool = true
    @State private var hudTimer: Timer? = nil

    private var sceneName: String {
        let progress = vm.playerProgress
        if progress < 0.25 {
            return "Scene 1: The Beginning"
        } else if progress < 0.50 {
            return "Scene 2: Hardware Design & Specs"
        } else if progress < 0.75 {
            return "Scene 3: Spatial Computing & Demos"
        } else {
            return "Scene 4: The Future of Mac"
        }
    }

    private var sceneTimestamp: String {
        let totalSeconds = 300.0 // 5-minute video representation
        let currentSeconds = vm.playerProgress * totalSeconds
        let minutes = Int(currentSeconds) / 60
        let seconds = Int(currentSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            // Full Screen Cinematic Background
            Color.black
                .ignoresSafeArea()
            
            // Video Simulation Graphic (Pulsing shapes and ambient colors simulating screen activity)
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let scale = 1.0 + 0.05 * sin(time * 0.5)
                
                ZStack {
                    RadialGradient(
                        colors: [
                            Color(hex: vm.topShelfItem?.accentHex ?? "#FF0000")?.opacity(0.35) ?? .blue.opacity(0.35),
                            .black
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 500
                    )
                    .scaleEffect(scale)
                    .blur(radius: 40)
                    
                    VStack(spacing: 20) {
                        Image(systemName: vm.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white.opacity(0.3))
                            .scaleEffect(vm.isPlaying ? 1.0 : 1.15)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.isPlaying)
                        
                        Text(vm.isPlaying ? "PLAYING STREAM..." : "PAUSED (SCRUBBING)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(3)
                    }
                }
            }
            .ignoresSafeArea()
            
            // Interactive Scrubbing Thumbnails Popup
            if !vm.isPlaying {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .frame(width: 200, height: 110)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        // Scene Preview Graphics
                        VStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.4))
                            Text(sceneName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(sceneTimestamp)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 8)
                }
                .padding(.bottom, 220)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            
            // Cinematic HUD Playbar
            if isHudVisible || !vm.isPlaying {
                VStack {
                    // Top Bar (Exit message)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.topShelfItem?.name ?? "Trailer Preview")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Apple Continuity Media Stream")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Button(action: {
                            withAnimation {
                                vm.isCinematicPlayerVisible = false
                                vm.isPlaying = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Back to Menu (B)")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(32)
                    
                    Spacer()
                    
                    // Bottom Playback Timeline Controls
                    VStack(spacing: 12) {
                        HStack {
                            Text(sceneTimestamp)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text("5:00")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 4)
                        
                        // Timeline Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: vm.topShelfItem?.accentHex ?? "#FF0000") ?? .blue)
                                    .frame(width: geo.size.width * CGFloat(vm.playerProgress), height: 8)
                                
                                // Drag handle
                                Circle()
                                    .fill(.white)
                                    .frame(width: 16, height: 16)
                                    .offset(x: geo.size.width * CGFloat(vm.playerProgress) - 8, y: -4)
                                    .shadow(radius: 4)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let pct = Double(value.location.x / geo.size.width)
                                        vm.playerProgress = min(max(pct, 0.0), 1.0)
                                        vm.isPlaying = false
                                    }
                            )
                        }
                        .frame(height: 12)
                        
                        // HUD Control Buttons
                        HStack(spacing: 24) {
                            Button(action: { vm.scrubTimeline(by: -0.05) }) {
                                Image(systemName: "gobackward.15")
                                    .font(.title2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { vm.isPlaying.toggle() }) {
                                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { vm.scrubTimeline(by: 0.05) }) {
                                Image(systemName: "goforward.15")
                                    .font(.title2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Volume control HUD component
                            HStack(spacing: 8) {
                                Image(systemName: vm.playerVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                Slider(value: Binding(get: { vm.playerVolume }, set: { vm.playerVolume = $0 }), in: 0...1)
                                    .frame(width: 100)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
        }
        .onAppear {
            resetHudTimer()
        }
        .onChange(of: vm.isPlaying) { _, playing in
            if playing {
                resetHudTimer()
            }
        }
        .onTapGesture {
            withAnimation {
                isHudVisible.toggle()
            }
            if isHudVisible && vm.isPlaying {
                resetHudTimer()
            }
        }
    }

    private func resetHudTimer() {
        hudTimer?.invalidate()
        isHudVisible = true
        hudTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            if vm.isPlaying {
                withAnimation {
                    isHudVisible = false
                }
            }
        }
    }
}
