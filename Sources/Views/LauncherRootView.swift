import SwiftUI

struct LauncherRootView: View {
    @State private var vm = LauncherViewModel()
    @State private var registry = TileFrameRegistry()
    @State private var isAccessibilityAllowed: Bool = AXIsProcessTrusted()
    @State private var bypassAccessibilityWarning: Bool = false
    
    // Monitors references
    @State private var keyboardHandler: KeyboardHandler?
    @State private var mouseHandler: MouseHandler?

    var body: some View {
        ZStack {
            // Dynamic theme background
            BackgroundView(accentColor: vm.backgroundAccentColor)

            // Primary Content with Custom Overscan Safe-Area
            VStack {
                if !vm.isKeyboardVisible && !vm.isAppSwitcherVisible && !vm.isCalibrating {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 36) {
                                    TopBarView()
                                    
                                    TopShelfView()
                                        .id("TopShelf")
                                    
                                    ForEach(Array(vm.sections.enumerated()), id: \.element.id) { si, section in
                                        SectionRowView(
                                            section: section,
                                            sectionIndex: si,
                                            focusedPosition: vm.focusedPosition
                                        )
                                        .id("section_\(si)")
                                    }
                                }
                                .padding(.horizontal, 48)
                                .padding(.top, 32)
                                .padding(.bottom, 20)
                                .onChange(of: vm.focusedPosition) { _, newPosition in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        if newPosition.sectionIndex == -1 {
                                            scrollProxy.scrollTo("TopShelf", anchor: .top)
                                        } else {
                                            scrollProxy.scrollTo("section_\(newPosition.sectionIndex)", anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                                .background(Color.white.opacity(0.12))
                            
                            HStack {
                                HStack(spacing: 20) {
                                    Button {
                                        vm.isCalibrating = true
                                    } label: {
                                        Label("Screen Calibrate", systemImage: "tv")
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.08))
                                    .cornerRadius(8)
                                    
                                    Button {
                                        vm.isControllerSettingsVisible = true
                                    } label: {
                                        Label("Controller Settings", systemImage: "gamecontroller")
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.08))
                                    .cornerRadius(8)
                                    
                                    Button {
                                        vm.toggleAppSwitcher()
                                    } label: {
                                        Label("App Switcher", systemImage: "macwindow.on.rectangle")
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.08))
                                    .cornerRadius(8)
                                    
                                    Button {
                                        vm.toggleVirtualKeyboard()
                                    } label: {
                                        Label("Virtual Keyboard", systemImage: "keyboard")
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.08))
                                    .cornerRadius(8)
                                }
                                .foregroundStyle(.white.opacity(0.8))
                                
                                Spacer()
                                
                                HStack(spacing: 24) {
                                    ControllerHint(icon: "l.joystick", label: "Navigate")
                                    ControllerHint(icon: "r.joystick", label: "Mouse")
                                    ControllerHint(icon: "r2.rectangle.roundedtop", label: "Click")
                                    ControllerHint(icon: "l2.rectangle.roundedtop", label: "Right Click")
                                    ControllerHint(icon: "rectangle.split.3x1", label: "Keyboard")
                                    ControllerHint(icon: "line.3.horizontal", label: "Switcher")
                                    ControllerHint(icon: "house", label: "Home")
                                }
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.bottom, 24)
                        .background(Color.black.opacity(0.25))
                    }
                }
            }
            .padding(.horizontal, vm.overscanHorizontal)
            .padding(.vertical, vm.overscanVertical)
            .blur(radius: (vm.isKeyboardVisible || vm.isAppSwitcherVisible || vm.isControllerSettingsVisible || vm.isCinematicPlayerVisible || vm.isProfileSwitcherVisible) ? 15 : 0)
            .disabled(vm.isKeyboardVisible || vm.isAppSwitcherVisible || vm.isCalibrating || vm.isControllerSettingsVisible || vm.isCinematicPlayerVisible || vm.isProfileSwitcherVisible)
            .animation(.easeInOut(duration: 0.3), value: vm.isKeyboardVisible)
            .animation(.easeInOut(duration: 0.3), value: vm.isAppSwitcherVisible)



            // Overlay 2: Task Switcher Dashboard
            if vm.isAppSwitcherVisible {
                AppSwitcherView()
                    .transition(.opacity)
            }

            // Overlay 3: Screen Margins Calibration
            if vm.isCalibrating {
                CalibrationView()
                    .transition(.opacity)
            }
            
            // Overlay 4: Controller Settings
            if vm.isControllerSettingsVisible {
                ControllerSettingsView()
                    .transition(.opacity)
            }
            
            // Overlay 5: Cinematic Player Overlay
            if vm.isCinematicPlayerVisible {
                CinematicPlayerView()
                    .transition(.opacity)
            }

            // Overlay 6: Profile Continuity Switcher
            if vm.isProfileSwitcherVisible {
                ProfileSwitcherOverlay()
                    .transition(.opacity)
            }

            // Top Right Continuity Toast Notifications
            ContinuityNotificationBanner()
            
            // Guided Onboarding Overlay
            let needsPermissions = !isAccessibilityAllowed
            if needsPermissions && !bypassAccessibilityWarning {
                AccessibilityOnboardingView(
                    isAXAllowed: isAccessibilityAllowed,
                    onFixAX: {
                        GlobalInputSimulator.shared.requestAccessibilityIfNeeded()
                    },
                    onResetTCC: {
                        resetTCC()
                    },
                    onBypass: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            bypassAccessibilityWarning = true
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .environment(vm)
        .environment(registry)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: vm.isKeyboardVisible)
        .animation(.easeInOut(duration: 0.35), value: vm.isAppSwitcherVisible)
        .animation(.easeInOut(duration: 0.3), value: vm.isCalibrating)
        .sheet(isPresented: $vm.isAddingItem) {
            AddItemSheet()
                .environment(vm)
                .environment(registry)
        }
        .onAppear {
            setupInputRouter()
            GlobalVirtualKeyboardWindow.shared.setup(viewModel: vm)
            // Always start global controller input simulator
            GlobalInputSimulator.shared.requestAccessibilityIfNeeded()
            GlobalInputSimulator.shared.start()
            
            // Periodically check Accessibility status to bypass UI caching
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                let allowed = GlobalInputSimulator.shared.hasAccessibilityPermission()
                if allowed != isAccessibilityAllowed {
                    isAccessibilityAllowed = allowed
                }
            }
        }
        .onDisappear {
            teardownInputRouter()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAccessibilityAllowed = AXIsProcessTrusted()
        }
    }

    private func setupInputRouter() {
        let router = InputRouter(viewModel: vm)

        let kh = KeyboardHandler(router: router)
        kh.start()
        self.keyboardHandler = kh

        let mh = MouseHandler(viewModel: vm, registry: registry)
        mh.start()
        self.mouseHandler = mh

        GameControllerManager.shared.configure(viewModel: vm, router: router)
        GameControllerManager.shared.start()
    }

    private func teardownInputRouter() {
        keyboardHandler?.stop()
        mouseHandler?.stop()
        GameControllerManager.shared.stop()
        GlobalInputSimulator.shared.stop()
    }
    
    private func resetTCC() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.gemini.MacLauncher"]
        do {
            try process.run()
            process.waitUntilExit()
            DiagnosticsManager.shared.log("TCC Accessibility database reset successfully.")
            // Trigger UI update
            isAccessibilityAllowed = AXIsProcessTrusted()
        } catch {
            DiagnosticsManager.shared.log("Failed to run tccutil: \(error.localizedDescription)")
        }
    }
}

// Small helper view for controller button hints at the bottom
struct ControllerHint: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

// Guided Onboarding Components
// Guided Onboarding Components
struct AccessibilityOnboardingView: View {
    @Environment(LauncherViewModel.self) var vm
    let isAXAllowed: Bool
    let onFixAX: () -> Void
    let onResetTCC: () -> Void
    let onBypass: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                if #available(macOS 15.0, *) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)
                        .symbolEffect(.bounce, options: .repeating)
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)
                }
                
                VStack(spacing: 12) {
                    Text("Permissions Required")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("MacLauncher requires system Accessibility permission to simulate virtual mouse clicks, pointer movements, and trigger OS overlays.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Live Diagnostics Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("🔍 Live System Diagnostics")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(spacing: 8) {
                        DiagnosticRow(
                            label: "Accessibility Permission",
                            status: isAXAllowed ? "Granted ✓" : "Blocked ✗",
                            isOk: isAXAllowed
                        )
                        
                        DiagnosticRow(
                            label: "Synthetic Mouse Event Test",
                            status: isAXAllowed ? "Passed ✓" : "Blocked ✗",
                            isOk: isAXAllowed
                        )
                        
                        DiagnosticRow(
                            label: "Gamepad Connection",
                            status: vm.isControllerConnected ? "\(vm.connectedControllerName) ✓" : "None detected ✗",
                            isOk: vm.isControllerConnected
                        )
                        
                        let isStickActive = abs(vm.liveRightStickX) > 0.05 || abs(vm.liveRightStickY) > 0.05
                        DiagnosticRow(
                            label: "Right Stick Input",
                            status: vm.isControllerConnected ? (isStickActive ? String(format: "Active (X: %+.2f, Y: %+.2f) ✓", vm.liveRightStickX, vm.liveRightStickY) : "Neutral (Idle) ✓") : "No Controller ✗",
                            isOk: vm.isControllerConnected
                        )
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(8)
                }
                .padding(16)
                .background(.white.opacity(0.04))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Accessibility status
                    HStack(spacing: 12) {
                        Image(systemName: isAXAllowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isAXAllowed ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility (Required for mouse emulation)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Allows MacLauncher to move the cursor, click buttons, and open switcher/keyboard.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if !isAXAllowed {
                            Button(action: onFixAX) {
                                Text("Enable")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
                .background(.white.opacity(0.05))
                .cornerRadius(12)
                
                // macOS TCC Bug Warning section (Steam Input style wrapper fix)
                VStack(spacing: 8) {
                    Text("⚠️ macOS Permissions Troubleshooting")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                    Text("If you toggled Accessibility on in System Settings but the virtual mouse still fails, the macOS TCC database is cache-locked.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    Button(action: onResetTCC) {
                        Text("Reset macOS Permission Cache")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
                
                Button(action: onBypass) {
                    Text("Continue Anyway")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 650)
            .padding(40)
            .background(.white.opacity(0.03))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let status: String
    let isOk: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(status)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isOk ? .green : .red)
        }
    }
}

struct StepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 2)
        }
    }
}
