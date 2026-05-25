import SwiftUI
import GameController

struct ControllerSettingsView: View {
    @Environment(LauncherViewModel.self) var vm
    
    @State private var controllerName: String = "No controller detected"
    @State private var deadzone: Float = 0.05
    @State private var exponent: Float = 2.0
    
    @State private var leftOffsetX: Float = 0.0
    @State private var leftOffsetY: Float = 0.0
    @State private var rightOffsetX: Float = 0.0
    @State private var rightOffsetY: Float = 0.0
    
    @State private var isCalibratingSticks: Bool = false
    @State private var calibrationProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop blur
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isCalibratingSticks {
                        vm.isControllerSettingsVisible = false
                    }
                }
            
            VStack(spacing: 24) {
                // Title & Close Button
                HStack {
                    Text("🎮 Game Controller Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        vm.isControllerSettingsVisible = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCalibratingSticks)
                }
                
                // Device Info Card
                HStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 32))
                        .foregroundColor(controllerName == "No controller detected" ? .gray : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Gamepad")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .textCase(.uppercase)
                        
                        Text(controllerName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                
                if controllerName != "No controller detected" {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // Radial Dead Zone Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Radial Dead Zone")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(deadzone * 100))%")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $deadzone, in: 0.0...0.50, step: 0.01)
                                    .accentColor(.blue)
                                    .onChange(of: deadzone) { _, newValue in
                                        UserDefaults.standard.set(newValue, forKey: "GamepadDeadzone")
                                    }
                                
                                Text("Deadzones ignore minor input near the center of the sticks. Radial deadzones measure the combined 2D vector for a smoother, circular boundary.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(20)
                            .background(.white.opacity(0.03))
                            .cornerRadius(16)
                            
                            // Response Curve Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Response Curve (Exponent)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                // Preset Pickers
                                HStack(spacing: 12) {
                                    PresetButton(label: "Linear", val: 1.0, currentVal: exponent) {
                                        exponent = 1.0
                                        UserDefaults.standard.set(1.0, forKey: "GamepadExponent")
                                    }
                                    PresetButton(label: "Mild", val: 1.5, currentVal: exponent) {
                                        exponent = 1.5
                                        UserDefaults.standard.set(1.5, forKey: "GamepadExponent")
                                    }
                                    PresetButton(label: "Standard", val: 2.0, currentVal: exponent) {
                                        exponent = 2.0
                                        UserDefaults.standard.set(2.0, forKey: "GamepadExponent")
                                    }
                                }
                                
                                // Exponent Custom Slider
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Custom Exponent")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Text(String(format: "%.1f", exponent))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Slider(value: $exponent, in: 1.0...4.0, step: 0.1)
                                        .accentColor(.blue)
                                        .onChange(of: exponent) { _, newValue in
                                            UserDefaults.standard.set(newValue, forKey: "GamepadExponent")
                                        }
                                }
                                
                                // Live Curve Preview
                                ResponseCurveChart(exponent: Double(exponent))
                                
                                Text("Higher exponent values give more precise control near the stick's center and faster movements at full deflection.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(20)
                            .background(.white.opacity(0.03))
                            .cornerRadius(16)
                            
                            // Drift Calibration Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Stick Drift Calibration")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 16) {
                                    // Left Stick Status
                                    CalibrationStatusBox(
                                        title: "Left Stick",
                                        offsetX: leftOffsetX,
                                        offsetY: leftOffsetY
                                    )
                                    
                                    // Right Stick Status
                                    CalibrationStatusBox(
                                        title: "Right Stick",
                                        offsetX: rightOffsetX,
                                        offsetY: rightOffsetY
                                    )
                                }
                                
                                HStack(spacing: 12) {
                                    Button {
                                        triggerCalibration()
                                    } label: {
                                        HStack {
                                            if isCalibratingSticks {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .padding(.trailing, 6)
                                                Text("Calibrating...")
                                            } else {
                                                Image(systemName: "circle.circle")
                                                Text("Calibrate Sticks")
                                            }
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isCalibratingSticks ? Color.gray : Color.white)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isCalibratingSticks)
                                    
                                    Button {
                                        GameControllerManager.shared.resetCalibration()
                                        refreshOffsets()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("Reset")
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(.white.opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isCalibratingSticks)
                                }
                                
                                Text("Leave the controller sticks in their neutral resting position and click Calibrate to map and correct stick drift offsets.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(20)
                            .background(.white.opacity(0.03))
                            .cornerRadius(16)
                        }
                    }
                    .frame(maxHeight: 520)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.2))
                        
                        Text("Connect a compatible controller (via Bluetooth or USB) to adjust deadzones, response curves, and calibrate stick drift.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(height: 250)
                }
            }
            .frame(maxWidth: 550)
            .padding(32)
            .background(Color(red: 0.08, green: 0.08, blue: 0.1))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            refreshControllerState()
            
            // Listen for connection / disconnection to update UI
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { _ in
                refreshControllerState()
            }
            
            NotificationCenter.default.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { _ in
                refreshControllerState()
            }
        }
    }
    
    private func refreshControllerState() {
        deadzone = UserDefaults.standard.object(forKey: "GamepadDeadzone") as? Float ?? 0.05
        exponent = UserDefaults.standard.object(forKey: "GamepadExponent") as? Float ?? 2.0
        
        if let controller = GCController.controllers().first {
            controllerName = controller.vendorName ?? "Gamepad"
        } else {
            controllerName = "No controller detected"
        }
        refreshOffsets()
    }
    
    private func refreshOffsets() {
        leftOffsetX = GameControllerManager.shared.leftStickOffsetX
        leftOffsetY = GameControllerManager.shared.leftStickOffsetY
        rightOffsetX = GameControllerManager.shared.rightStickOffsetX
        rightOffsetY = GameControllerManager.shared.rightStickOffsetY
    }
    
    private func triggerCalibration() {
        guard !isCalibratingSticks else { return }
        isCalibratingSticks = true
        
        GameControllerManager.shared.calibrateActiveController {
            DispatchQueue.main.async {
                isCalibratingSticks = false
                refreshOffsets()
            }
        }
    }
}

// Preset Button helper View
struct PresetButton: View {
    let label: String
    let val: Float
    let currentVal: Float
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(currentVal == val ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(currentVal == val ? Color.blue : Color.white.opacity(0.06))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// Calibration status panel
struct CalibrationStatusBox: View {
    let title: String
    let offsetX: Float
    let offsetY: Float
    
    var isCalibrated: Bool {
        offsetX != 0.0 || offsetY != 0.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if isCalibrated {
                    Text("Calibrated")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("X Offset")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%+.3f", offsetX))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isCalibrated ? .green : .white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Y Offset")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(String(format: "%+.3f", offsetY))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isCalibrated ? .green : .white.opacity(0.8))
                }
            }
            .padding(10)
            .background(.white.opacity(0.03))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}

// Live response curve render chart
struct ResponseCurveChart: View {
    let exponent: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Grid background
                    Path { path in
                        // Vertical grids
                        for i in 1..<4 {
                            let x = CGFloat(i) * geo.size.width / 4
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                        // Horizontal grids
                        for i in 1..<4 {
                            let y = CGFloat(i) * geo.size.height / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                    }
                    .stroke(.white.opacity(0.04), lineWidth: 1)
                    
                    // Curve path
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for x in stride(from: 0.0, through: 1.0, by: 0.02) {
                            let y = pow(x, exponent)
                            let px = CGFloat(x) * geo.size.width
                            let py = geo.size.height - CGFloat(y) * geo.size.height
                            path.addLine(to: CGPoint(x: px, y: py))
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2.5)
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
            }
            .frame(height: 100)
            
            HStack {
                Text("Low Input (Precise)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                Text("Full Deflection (Fast)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}
