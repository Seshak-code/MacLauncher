import AppKit
import IOKit

final class KeyboardHandler {
    private let router: InputRouter
    private var keyDownMonitor: Any?
    private var scrollMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var globalFlagsChangedMonitor: Any?
    private var globalKeyDownMonitor: Any?
    
    // Key tap tracking state
    private var isOptionDown = false
    private var isCommandDown = false
    private var optionKeyPressTime: CFAbsoluteTime = 0.0
    private var commandKeyPressTime: CFAbsoluteTime = 0.0
    private var wasOtherKeyPressed = false
    
    // Scroll debouncing to prevent rapid-fire triggers on trackpads
    private var lastScrollTime: CFAbsoluteTime = 0.0
    private let scrollDebounceInterval: CFAbsoluteTime = 0.15

    init(router: InputRouter) {
        self.router = router
    }

    func start() {
        // Arrow keys and navigation keys (local)
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard self.isExternalEvent(event) else { return event }
            self.wasOtherKeyPressed = true
            
            switch event.keyCode {
            case 123: // Left Arrow
                self.router.handleDirection(.left)
                return nil
            case 124: // Right Arrow
                self.router.handleDirection(.right)
                return nil
            case 125: // Down Arrow
                self.router.handleDirection(.down)
                return nil
            case 126: // Up Arrow
                self.router.handleDirection(.up)
                return nil
            case 36, 76: // Return / Enter
                self.router.handleSelect()
                return nil
            case 53: // Escape
                self.router.handleCancel()
                return nil
            case 48: // Tab -> navigate sections
                let shiftPressed = event.modifierFlags.contains(.shift)
                self.router.handleDirection(shiftPressed ? .up : .down)
                return nil
            default:
                return event
            }
        }

        // Scroll wheel mapping with debounce (local)
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            guard self.isExternalEvent(event) else { return event }
            
            let now = CFAbsoluteTimeGetCurrent()
            guard (now - self.lastScrollTime) > self.scrollDebounceInterval else {
                return event
            }
            
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            
            // Lower thresholds for better trackpad/scroll wheel responsiveness
            if abs(dx) > 5 {
                self.router.handleDirection(dx > 0 ? .left : .right)
                self.lastScrollTime = now
            }
            if abs(dy) > 5 {
                self.router.handleDirection(dy > 0 ? .up : .down)
                self.lastScrollTime = now
            }
            
            return event
        }

        // Local flags changed monitor (for Option/Command when app is active)
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            guard self.isExternalEvent(event) else { return event }
            self.handleFlagsChanged(event)
            return event
        }

        // Global flags changed monitor (for Option/Command when app is in background)
        globalFlagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            guard self.isExternalEvent(event) else { return }
            self.handleFlagsChanged(event)
        }

        // Global key down monitor to invalidate modifier tap if another key is pressed
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            guard self.isExternalEvent(event) else { return }
            self.wasOtherKeyPressed = true
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let keyCode = event.keyCode
        
        // Option/Alt Key (Left Option: 58, Right Option: 61)
        if keyCode == 58 || keyCode == 61 {
            let isDown = event.modifierFlags.contains(.option)
            if isDown {
                if !isOptionDown {
                    isOptionDown = true
                    optionKeyPressTime = CFAbsoluteTimeGetCurrent()
                    wasOtherKeyPressed = false
                }
            } else {
                if isOptionDown {
                    isOptionDown = false
                    let duration = CFAbsoluteTimeGetCurrent() - optionKeyPressTime
                    if !wasOtherKeyPressed && duration < 0.4 {
                        DispatchQueue.main.async { [weak self] in
                            self?.router.handleAppSwitcher()
                        }
                    }
                }
            }
        }
        
        // Command/Windows Key (Left Cmd: 55, Right Cmd: 54)
        if keyCode == 55 || keyCode == 54 {
            let isDown = event.modifierFlags.contains(.command)
            if isDown {
                if !isCommandDown {
                    isCommandDown = true
                    commandKeyPressTime = CFAbsoluteTimeGetCurrent()
                    wasOtherKeyPressed = false
                }
            } else {
                if isCommandDown {
                    isCommandDown = false
                    let duration = CFAbsoluteTimeGetCurrent() - commandKeyPressTime
                    if !wasOtherKeyPressed && duration < 0.4 {
                        DispatchQueue.main.async { [weak self] in
                            self?.router.handleAppSwitcher()
                        }
                    }
                }
            }
        }
    }

    /// Determines if a keyboard event was triggered by an external keyboard (USB/Bluetooth) rather than the built-in MacBook keyboard
    private func isExternalEvent(_ event: NSEvent) -> Bool {
        guard let cgEvent = event.cgEvent else { return true }
        
        // Field 87 is the registry entry ID for the device that sent the event
        let registryID = cgEvent.getIntegerValueField(CGEventField(rawValue: 87)!)
        guard registryID != 0 else { return true } // Fallback to true if unavailable
        
        let matchingDict = IORegistryEntryIDMatching(UInt64(registryID))
        let service = IOServiceGetMatchingService(0, matchingDict) // Consumes matchingDict
        guard service != 0 else { return true }
        defer { IOObjectRelease(service) }
        
        // Query the "Built-in" property
        if let isBuiltIn = IORegistryEntryCreateCFProperty(service, "Built-in" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
            return !isBuiltIn
        }
        
        // Fallback: Query "Transport" connection type (USB/Bluetooth = external)
        if let transport = IORegistryEntryCreateCFProperty(service, "Transport" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return transport == "USB" || transport == "Bluetooth"
        }
        
        return true // Fallback default
    }

    func stop() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        if let monitor = globalFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsChangedMonitor = nil
        }
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }
    }
}

