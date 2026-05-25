import GameController
import Foundation
import AppKit

final class GameControllerManager {
    static let shared = GameControllerManager()
    
    private var viewModel: LauncherViewModel?
    private var router: InputRouter?
    private var isRunning = false
    
    // Left stick navigation debounce
    private var hasTriggeredX = false
    private var hasTriggeredY = false
    
    // D-pad tracking states for edge trigger detection
    private var lastDpadUp = false
    private var lastDpadDown = false
    private var lastDpadLeft = false
    private var lastDpadRight = false
    
    // Button pressed tracking states for edge trigger detection
    private var isADown = false
    private var isBDown = false
    private var isL2Down = false
    private var isR2Down = false
    private var isOptionsDown = false
    private var isMenuDown = false
    private var isHomeDown = false
    private var isWestDown = false
    
    // Autorepeat states
    private var activeDpadDirection: MoveDirection?
    private var activeHeldDirection: MoveDirection?
    private var repeatTimer: Timer?
    
    // Stick click combo states
    private var isL3Down = false
    private var isR3Down = false

    // Calibration offsets
    private(set) var leftStickOffsetX: Float = 0.0
    private(set) var leftStickOffsetY: Float = 0.0
    private(set) var rightStickOffsetX: Float = 0.0
    private(set) var rightStickOffsetY: Float = 0.0

    // Keep reference to handle layout warning checks
    var didExclusiveSeizeSucceed = true
    
    func configure(viewModel: LauncherViewModel, router: InputRouter) {
        self.viewModel = viewModel
        self.router = router
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        loadCalibration()
        
        // Register for controller connection and disconnection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        // Tell GameController framework to monitor background controller events
        GCController.shouldMonitorBackgroundEvents = true
        
        // Set up value changed handlers for already connected controllers
        for controller in GCController.controllers() {
            setupController(controller)
        }
        
        if GCController.controllers().isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.isControllerConnected = false
                self?.viewModel?.connectedControllerName = "None"
            }
        }
        
        DiagnosticsManager.shared.log("GameControllerManager initialized using GCController framework.")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
        
        for controller in GCController.controllers() {
            if let gamepad = controller.extendedGamepad {
                gamepad.valueChangedHandler = nil
            }
        }
        
        repeatTimer?.invalidate()
        repeatTimer = nil
        
        DiagnosticsManager.shared.log("GameControllerManager stopped.")
    }

    private func setupController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            DiagnosticsManager.shared.log("Matched controller has no extended gamepad profile: \(controller.vendorName ?? "Unknown")")
            return
        }
        
        DiagnosticsManager.shared.log("Configuring gamepad input handler for: \(controller.vendorName ?? "Unknown")")
        
        // Override system gestures to prevent macOS from stealing shortcuts (Launchpad/Screenshot)
        gamepad.buttonHome?.preferredSystemGestureState = .disabled
        gamepad.buttonOptions?.preferredSystemGestureState = .disabled
        
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.isControllerConnected = true
            self?.viewModel?.connectedControllerName = controller.vendorName ?? "Gamepad"
        }
        
        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            guard let self = self else { return }
            self.handleGamepadElementChange(gamepad: gamepad, element: element)
        }
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DiagnosticsManager.shared.log("Controller disconnected: \(controller.vendorName ?? "Unknown")")
        
        DispatchQueue.main.async { [weak self] in
            if GCController.controllers().isEmpty {
                self?.viewModel?.isControllerConnected = false
                self?.viewModel?.connectedControllerName = "None"
                self?.viewModel?.liveRightStickX = 0.0
                self?.viewModel?.liveRightStickY = 0.0
                self?.viewModel?.liveLeftStickX = 0.0
                self?.viewModel?.liveLeftStickY = 0.0
            } else if let remaining = GCController.controllers().first {
                self?.viewModel?.isControllerConnected = true
                self?.viewModel?.connectedControllerName = remaining.vendorName ?? "Gamepad"
            }
        }
        
        repeatTimer?.invalidate()
        repeatTimer = nil
        activeHeldDirection = nil
        activeDpadDirection = nil
    }

    private func handleGamepadElementChange(gamepad: GCExtendedGamepad, element: GCControllerElement) {
        let isLauncherActive = NSApp.isActive
        
        // 1. Handle buttons
        if let button = element as? GCControllerButtonInput {
            let pressed = button.isPressed
            
            switch element {
            case gamepad.buttonA:
                let justPressed = pressed && !isADown
                isADown = pressed
                if justPressed {
                    if isLauncherActive {
                        router?.handleSelect()
                    } else {
                        GlobalInputSimulator.shared.simulateLeftClick()
                    }
                }
            case gamepad.buttonB:
                let justPressed = pressed && !isBDown
                isBDown = pressed
                if justPressed {
                    if viewModel?.isKeyboardVisible == true {
                        DispatchQueue.main.async { [weak self] in
                            self?.viewModel?.cancelOrBack()
                        }
                    } else if isLauncherActive {
                        router?.handleCancel()
                    } else {
                        GlobalInputSimulator.shared.simulateRightClick()
                    }
                }
            case gamepad.buttonX: // PS Square / Xbox X
                let justPressed = pressed && !isWestDown
                isWestDown = pressed
                if justPressed {
                    if viewModel?.isKeyboardVisible == true {
                        DispatchQueue.main.async { [weak self] in
                            self?.viewModel?.submitKeyboard()
                        }
                    }
                }
            case gamepad.leftShoulder: // L1
                if pressed {
                    GlobalInputSimulator.shared.simulateScroll(deltaY: 5)
                }
            case gamepad.rightShoulder: // R1
                if pressed {
                    GlobalInputSimulator.shared.simulateScroll(deltaY: -5)
                }
            case gamepad.leftTrigger: // L2 (Right Click / Left Trigger)
                let justPressed = pressed && !isL2Down
                isL2Down = pressed
                if justPressed {
                    GlobalInputSimulator.shared.simulateRightClick()
                }
            case gamepad.rightTrigger: // R2 (Left Click / Right Trigger)
                let justPressed = pressed && !isR2Down
                isR2Down = pressed
                if justPressed {
                    if isLauncherActive {
                        router?.handleSelect()
                    } else {
                        GlobalInputSimulator.shared.simulateLeftClick()
                    }
                }
            case gamepad.buttonOptions: // Select / Share
                let justPressed = pressed && !isOptionsDown
                isOptionsDown = pressed
                if justPressed {
                    DispatchQueue.main.async { [weak self] in
                        self?.viewModel?.toggleVirtualKeyboard()
                    }
                }
            case gamepad.buttonMenu: // Start / Menu
                let justPressed = pressed && !isMenuDown
                isMenuDown = pressed
                if justPressed {
                    GlobalInputSimulator.shared.triggerOSAppSwitcher()
                }
            case gamepad.leftThumbstickButton: // L3
                isL3Down = pressed
                checkStickCombo()
            case gamepad.rightThumbstickButton: // R3
                isR3Down = pressed
                checkStickCombo()
            case gamepad.buttonHome: // PS / Home button
                let justPressed = pressed && !isHomeDown
                isHomeDown = pressed
                if justPressed {
                    GlobalInputSimulator.shared.triggerOSAppSwitcher()
                }
            default:
                break
            }
        }
        
        // 2. Handle sticks & D-pad
        if element == gamepad.leftThumbstick {
            let x = gamepad.leftThumbstick.xAxis.value - leftStickOffsetX
            let y = gamepad.leftThumbstick.yAxis.value - leftStickOffsetY
            let threshold: Float = 0.5
            
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.liveLeftStickX = x
                self?.viewModel?.liveLeftStickY = y
            }
            
            // Intercept for Cinematic Player
            if let vm = viewModel, vm.isCinematicPlayerVisible {
                if abs(x) > 0.1 {
                    DispatchQueue.main.async {
                        vm.scrubTimeline(by: Double(x) * 0.01)
                    }
                }
                if abs(y) > 0.1 {
                    DispatchQueue.main.async {
                        vm.adjustVolume(by: Double(y) * 0.02)
                    }
                }
                return
            }
            
            var targetDir: MoveDirection? = nil
            if abs(x) > threshold {
                targetDir = x > 0 ? .right : .left
            } else if abs(y) > threshold {
                targetDir = y > 0 ? .up : .down
            }
            
            if activeDpadDirection == nil {
                setHeldDirection(targetDir)
            }
            
        } else if element == gamepad.rightThumbstick {
            let x = gamepad.rightThumbstick.xAxis.value - rightStickOffsetX
            let y = gamepad.rightThumbstick.yAxis.value - rightStickOffsetY
            
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.liveRightStickX = x
                self?.viewModel?.liveRightStickY = y
            }
            
            GlobalInputSimulator.shared.updateMouseStick(x: x, y: y)
            
        } else if element == gamepad.dpad {
            let upPressed = gamepad.dpad.up.isPressed
            let downPressed = gamepad.dpad.down.isPressed
            let leftPressed = gamepad.dpad.left.isPressed
            let rightPressed = gamepad.dpad.right.isPressed
            
            var targetDir: MoveDirection? = nil
            if upPressed { targetDir = .up }
            else if downPressed { targetDir = .down }
            else if leftPressed { targetDir = .left }
            else if rightPressed { targetDir = .right }
            
            activeDpadDirection = targetDir
            if let dir = targetDir {
                setHeldDirection(dir)
            } else {
                let stickX = gamepad.leftThumbstick.xAxis.value - leftStickOffsetX
                let stickY = gamepad.leftThumbstick.yAxis.value - leftStickOffsetY
                let stickThreshold: Float = 0.5
                
                var stickDir: MoveDirection? = nil
                if abs(stickX) > stickThreshold {
                    stickDir = stickX > 0 ? .right : .left
                } else if abs(stickY) > stickThreshold {
                    stickDir = stickY > 0 ? .up : .down
                }
                
                setHeldDirection(stickDir)
            }
        }
    }
    
    private func setHeldDirection(_ direction: MoveDirection?) {
        guard activeHeldDirection != direction else { return }
        
        activeHeldDirection = direction
        repeatTimer?.invalidate()
        repeatTimer = nil
        
        guard let dir = direction else { return }
        
        // Trigger immediately
        triggerDirection(dir)
        
        // Schedule repeat timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self, self.activeHeldDirection == dir else { return }
            
            // Trigger repeat
            self.triggerDirection(dir)
            
            // Start fast repeat
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                guard let self = self, self.activeHeldDirection == dir else { return }
                self.triggerDirection(dir)
            }
            RunLoop.main.add(self.repeatTimer!, forMode: .common)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }
    
    private func triggerDirection(_ direction: MoveDirection) {
        let isLauncherActive = NSApp.isActive
        let isKeyboardVisible = viewModel?.isKeyboardVisible == true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isLauncherActive || isKeyboardVisible {
                self.router?.handleDirection(direction)
            } else {
                let arrowDir: ArrowDirection
                switch direction {
                case .up: arrowDir = .up
                case .down: arrowDir = .down
                case .left: arrowDir = .left
                case .right: arrowDir = .right
                }
                GlobalInputSimulator.shared.sendArrowKey(direction: arrowDir)
            }
        }
    }
    
    private func checkStickCombo() {
        if isL3Down && isR3Down {
            DispatchQueue.main.async {
                GlobalInputSimulator.shared.triggerOSAppSwitcher()
            }
        }
    }

    // MARK: - Calibration Methods

    func calibrateActiveController(completion: @escaping () -> Void) {
        guard let controller = GCController.controllers().first,
              let gamepad = controller.extendedGamepad else {
            DiagnosticsManager.shared.log("Calibration failed: no controller detected.")
            completion()
            return
        }
        
        var leftXSum: Float = 0.0
        var leftYSum: Float = 0.0
        var rightXSum: Float = 0.0
        var rightYSum: Float = 0.0
        var samplesCount = 0
        
        // Sample at 60Hz for 1 second (60 samples total)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            leftXSum += gamepad.leftThumbstick.xAxis.value
            leftYSum += gamepad.leftThumbstick.yAxis.value
            rightXSum += gamepad.rightThumbstick.xAxis.value
            rightYSum += gamepad.rightThumbstick.yAxis.value
            samplesCount += 1
            
            if samplesCount >= 60 {
                timer.invalidate()
                self.leftStickOffsetX = leftXSum / 60.0
                self.leftStickOffsetY = leftYSum / 60.0
                self.rightStickOffsetX = rightXSum / 60.0
                self.rightStickOffsetY = rightYSum / 60.0
                
                // Store in UserDefaults
                UserDefaults.standard.set(self.leftStickOffsetX, forKey: "LeftStickOffsetX")
                UserDefaults.standard.set(self.leftStickOffsetY, forKey: "LeftStickOffsetY")
                UserDefaults.standard.set(self.rightStickOffsetX, forKey: "RightStickOffsetX")
                UserDefaults.standard.set(self.rightStickOffsetY, forKey: "RightStickOffsetY")
                
                DiagnosticsManager.shared.log("Controller calibrated. Offsets - Left: (\(self.leftStickOffsetX), \(self.leftStickOffsetY)), Right: (\(self.rightStickOffsetX), \(self.rightStickOffsetY))")
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func resetCalibration() {
        leftStickOffsetX = 0
        leftStickOffsetY = 0
        rightStickOffsetX = 0
        rightStickOffsetY = 0
        UserDefaults.standard.removeObject(forKey: "LeftStickOffsetX")
        UserDefaults.standard.removeObject(forKey: "LeftStickOffsetY")
        UserDefaults.standard.removeObject(forKey: "RightStickOffsetX")
        UserDefaults.standard.removeObject(forKey: "RightStickOffsetY")
        DiagnosticsManager.shared.log("Controller calibration reset.")
    }

    private func loadCalibration() {
        leftStickOffsetX = UserDefaults.standard.float(forKey: "LeftStickOffsetX")
        leftStickOffsetY = UserDefaults.standard.float(forKey: "LeftStickOffsetY")
        rightStickOffsetX = UserDefaults.standard.float(forKey: "RightStickOffsetX")
        rightStickOffsetY = UserDefaults.standard.float(forKey: "RightStickOffsetY")
        DiagnosticsManager.shared.log("Loaded calibration offsets - Left: (\(leftStickOffsetX), \(leftStickOffsetY)), Right: (\(rightStickOffsetX), \(rightStickOffsetY))")
    }
}
