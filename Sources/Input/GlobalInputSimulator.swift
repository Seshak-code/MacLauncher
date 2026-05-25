import CoreGraphics
import AppKit

final class GlobalInputSimulator {
    static let shared = GlobalInputSimulator()
    
    private var mouseTimer: Timer?
    private var isRunning = false
    
    // Right stick velocities for mouse cursor
    private var mouseVelocityX: CGFloat = 0.0
    private var mouseVelocityY: CGFloat = 0.0
    
    // Speed multiplier (adjustable)
    private let maxSpeed: CGFloat = 18.0
    private let deadzone: Float = 0.12
    
    // Check accessibility permissions (uncached check)
    func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func requestAccessibilityIfNeeded() {
        if !hasAccessibilityPermission() {
            // Prompt the system dialog
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // 60Hz mouse update loop — frame-rate independent via fixed interval
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
        // Ensure timer fires even during tracking loops (e.g. during menu/sheet)
        if let timer = mouseTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        mouseTimer?.invalidate()
        mouseTimer = nil
        mouseVelocityX = 0
        mouseVelocityY = 0
    }
    
    // Called by GameControllerManager for right thumbstick input
    func updateMouseStick(x: Float, y: Float) {
        let deadzoneVal = UserDefaults.standard.object(forKey: "GamepadDeadzone") as? Float ?? 0.05
        let exponent = UserDefaults.standard.object(forKey: "GamepadExponent") as? Float ?? 2.0
        
        let dx = CGFloat(x)
        let dy = CGFloat(y)
        let magnitude = sqrt(dx * dx + dy * dy)
        let dz = CGFloat(deadzoneVal)
        
        if magnitude > dz {
            let normalizedMagnitude = (magnitude - dz) / (1.0 - dz)
            let curveMagnitude = pow(normalizedMagnitude, CGFloat(exponent))
            
            // Scale velocity based on directional components
            mouseVelocityX = (dx / magnitude) * curveMagnitude * maxSpeed
            mouseVelocityY = (dy / magnitude) * curveMagnitude * maxSpeed
        } else {
            mouseVelocityX = 0.0
            mouseVelocityY = 0.0
        }
    }
    
    private func updateMousePosition() {
        guard mouseVelocityX != 0 || mouseVelocityY != 0 else { return }
        
        let currentPos = getCurrentMousePosition()
        var newX = currentPos.x + mouseVelocityX
        // GameController +Y is UP, screen +Y is DOWN
        var newY = currentPos.y - mouseVelocityY
        
        // Clamp to all screens combined bounds
        let screenFrame = allScreensBounds()
        newX = max(screenFrame.minX, min(newX, screenFrame.maxX))
        newY = max(screenFrame.minY, min(newY, screenFrame.maxY))
        
        let newPoint = CGPoint(x: newX, y: newY)
        postMouseEvent(type: .mouseMoved, point: newPoint, button: .left)
    }
    
    // MARK: - Click Simulation
    
    func simulateLeftClick() {
        let pos = getCurrentMousePosition()
        postMouseEvent(type: .leftMouseDown, point: pos, button: .left)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.postMouseEvent(type: .leftMouseUp, point: pos, button: .left)
        }
    }
    
    func simulateRightClick() {
        let pos = getCurrentMousePosition()
        postMouseEvent(type: .rightMouseDown, point: pos, button: .right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.postMouseEvent(type: .rightMouseUp, point: pos, button: .right)
        }
    }
    
    func simulateScroll(deltaY: CGFloat) {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: Int32(deltaY), wheel2: 0, wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }

    func simulateTyping(_ text: String) {
        let utf16Chars = Array(text.utf16)
        guard !utf16Chars.isEmpty else { return }
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Post character down/up events using unicode string
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            utf16Chars.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: buffer.baseAddress)
            }
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            utf16Chars.withUnsafeBufferPointer { buffer in
                keyUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: buffer.baseAddress)
            }
            keyUp.post(tap: .cghidEventTap)
        }
        
        // Post Return key to submit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let returnKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true)
            returnKeyDown?.post(tap: .cghidEventTap)
            let returnKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false)
            returnKeyUp?.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Fullscreen Toggle for External Apps
    
    func sendFullscreenShortcut() {
        // Ctrl+Cmd+F is the standard macOS fullscreen shortcut
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x03, keyDown: true) // 'f' key
        keyDown?.flags = [.maskCommand, .maskControl]
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x03, keyDown: false)
        keyUp?.flags = [.maskCommand, .maskControl]
        keyUp?.post(tap: .cghidEventTap)
    }

    func makeApplicationFullscreen(app: NSRunningApplication, completion: (() -> Void)? = nil) {
        let pid = app.processIdentifier
        DiagnosticsManager.shared.log("Starting state-aware fullscreen automation for PID \(pid) (\(app.localizedName ?? "Unknown"))")
        
        let axApp = AXUIElementCreateApplication(pid)
        var attempts = 0
        let maxAttempts = 15 // 3 seconds total (15 * 0.2s)
        
        func checkWindow() {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
            
            if result == .success, let windows = value as? [AXUIElement], let firstWindow = windows.first {
                DiagnosticsManager.shared.log("Window detected for PID \(pid). Setting AXFullScreen = true.")
                let error = AXUIElementSetAttributeValue(firstWindow, "AXFullScreen" as CFString, kCFBooleanTrue)
                
                if error == .success {
                    DiagnosticsManager.shared.log("Fullscreen attribute applied successfully for PID \(pid)")
                    // Verify the fullscreen state
                    var isFS: AnyObject?
                    let fsCheck = AXUIElementCopyAttributeValue(firstWindow, "AXFullScreen" as CFString, &isFS)
                    if fsCheck == .success, let fsBool = isFS as? Bool, fsBool {
                        DiagnosticsManager.shared.log("Fullscreen state verified for PID \(pid)")
                        completion?()
                        return
                    }
                } else {
                    DiagnosticsManager.shared.log("Failed to set AXFullScreen: \(error.rawValue)")
                }
            }
            
            attempts += 1
            if attempts < maxAttempts && !app.isTerminated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    checkWindow()
                }
            } else {
                DiagnosticsManager.shared.log("AX fullscreen failed/timed out for PID \(pid). Falling back to keyboard shortcut.")
                app.activate(options: [.activateAllWindows])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.sendFullscreenShortcut()
                    completion?()
                }
            }
        }
        
        checkWindow()
    }

    private func isScreenshotHUDActive() -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.screenshot.launcher" || $0.localizedName == "Screenshot"
        }
    }

    func releaseAllModifiers() {
        DiagnosticsManager.shared.log("Executing modifier key release recovery routine.")
        let source = CGEventSource(stateID: .combinedSessionState)
        let modifiers: [UInt16] = [55, 58, 61, 56, 60, 59] // Cmd, Opt L, Opt R, Shift L, Shift R, Ctrl
        for key in modifiers {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
            event?.post(tap: .cghidEventTap)
        }
    }

    func triggerOSAppSwitcher() {
        DiagnosticsManager.shared.log("Triggering OS App Switcher via Screenshot HUD trick...")
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Clear modifiers first to avoid stuck key combinations
        releaseAllModifiers()
        
        // 1. Post Cmd + Shift + 5 to trigger Screenshot HUD
        let scrFlags: CGEventFlags = [.maskCommand, .maskShift]
        let scrDown = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: true)
        scrDown?.flags = scrFlags
        scrDown?.post(tap: .cghidEventTap)
        
        let scrUp = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: false)
        scrUp?.flags = scrFlags
        scrUp?.post(tap: .cghidEventTap)
        
        // 2. Poll for HUD to appear
        var hudAttempts = 0
        func checkHUDAndPost() {
            if isScreenshotHUDActive() || hudAttempts >= 10 {
                DiagnosticsManager.shared.log("HUD verified active/ready. Posting Cmd+Tab.")
                
                let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true)
                cmdDown?.flags = .maskCommand
                cmdDown?.post(tap: .cghidEventTap)
                
                let tabDown = CGEvent(keyboardEventSource: source, virtualKey: 48, keyDown: true)
                tabDown?.flags = .maskCommand
                tabDown?.post(tap: .cghidEventTap)
                
                let tabUp = CGEvent(keyboardEventSource: source, virtualKey: 48, keyDown: false)
                tabUp?.flags = .maskCommand
                tabUp?.post(tap: .cghidEventTap)
                
                let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
                cmdUp?.post(tap: .cghidEventTap)
                
                // 3. Dismiss HUD via Escape
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let escDown = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true)
                    escDown?.post(tap: .cghidEventTap)
                    
                    let escUp = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false)
                    escUp?.post(tap: .cghidEventTap)
                    DiagnosticsManager.shared.log("App Switcher triggered and Screenshot HUD dismissed successfully.")
                }
            } else {
                hudAttempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkHUDAndPost)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkHUDAndPost)
    }
    
    func triggerOSVirtualKeyboard() {
        DiagnosticsManager.shared.log("Triggering OS Virtual Keyboard via Screenshot HUD trick...")
        let source = CGEventSource(stateID: .combinedSessionState)
        
        releaseAllModifiers()
        
        // 1. Post Cmd + Shift + 5 to trigger Screenshot HUD
        let scrFlags: CGEventFlags = [.maskCommand, .maskShift]
        let scrDown = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: true)
        scrDown?.flags = scrFlags
        scrDown?.post(tap: .cghidEventTap)
        
        let scrUp = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: false)
        scrUp?.flags = scrFlags
        scrUp?.post(tap: .cghidEventTap)
        
        // 2. Poll for HUD to appear
        var hudAttempts = 0
        func checkHUDAndPost() {
            if isScreenshotHUDActive() || hudAttempts >= 10 {
                DiagnosticsManager.shared.log("HUD verified active/ready. Posting Cmd+Opt+F5.")
                
                let kbFlags: CGEventFlags = [.maskCommand, .maskAlternate]
                let kbDown = CGEvent(keyboardEventSource: source, virtualKey: 96, keyDown: true) // F5
                kbDown?.flags = kbFlags
                kbDown?.post(tap: .cghidEventTap)
                
                let kbUp = CGEvent(keyboardEventSource: source, virtualKey: 96, keyDown: false)
                kbUp?.flags = kbFlags
                kbUp?.post(tap: .cghidEventTap)
                
                // 3. Dismiss HUD via Escape
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let escDown = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true)
                    escDown?.post(tap: .cghidEventTap)
                    
                    let escUp = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false)
                    escUp?.post(tap: .cghidEventTap)
                    DiagnosticsManager.shared.log("Virtual Keyboard triggered and Screenshot HUD dismissed successfully.")
                }
            } else {
                hudAttempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkHUDAndPost)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkHUDAndPost)
    }
    
    func triggerOSScreenRecorderHUD() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let flags: CGEventFlags = [.maskCommand, .maskShift] // Cmd + Shift
        
        // '5' is keycode 23
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 23, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Arrow Key Simulation (for left stick when not in launcher)

    func sendArrowKey(direction: ArrowDirection) {
        let keyCode: UInt16
        switch direction {
        case .up: keyCode = 126
        case .down: keyCode = 125
        case .left: keyCode = 123
        case .right: keyCode = 124
        }
        
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDown?.post(tap: .cghidEventTap)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Helpers
    
    private func getCurrentMousePosition() -> CGPoint {
        let event = CGEvent(source: nil)
        return event?.location ?? .zero
    }
    
    private func postMouseEvent(type: CGEventType, point: CGPoint, button: CGMouseButton) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        event?.post(tap: .cghidEventTap)
    }
    
    private func allScreensBounds() -> CGRect {
        var combined = CGRect.zero
        for screen in NSScreen.screens {
            combined = combined.union(screen.frame)
        }
        return combined
    }
}

enum ArrowDirection {
    case up, down, left, right
}
