import AppKit
import SwiftUI

final class MouseHandler {
    private let viewModel: LauncherViewModel
    private let registry: TileFrameRegistry
    private var mouseMoveMonitor: Any?
    private var clickMonitor: Any?
    private var lastSnappedMousePos: CGPoint = .zero

    init(viewModel: LauncherViewModel, registry: TileFrameRegistry) {
        self.viewModel = viewModel
        self.registry = registry
    }

    func start() {
        // Track mouse movement for focus snapping
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return event }
            
            // Skip mouse snap if switcher or keyboard is open
            if self.viewModel.isKeyboardVisible || self.viewModel.isAppSwitcherVisible || self.viewModel.isCalibrating {
                return event
            }
            
            let window = NSApp.windows.first
            let mousePos = self.convertToTopLeft(event.locationInWindow, in: window)
            
            let dx = abs(mousePos.x - self.lastSnappedMousePos.x)
            let dy = abs(mousePos.y - self.lastSnappedMousePos.y)
            if dx > 3.0 || dy > 3.0 {
                self.snapFocusToNearestTile(at: mousePos)
                self.lastSnappedMousePos = mousePos
            }
            return event
        }

        // Mouse click activation
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Only capture left click to activate if we are not clicking sheet elements
            if self.viewModel.isAddingItem {
                return event
            }
            
            // If virtual keyboard or app switcher is open, let clicks handle standard events,
            // or we can consume it if it aligns with a tile. For simplicity, let standard SwiftUI buttons handle clicks,
            // but if clicking active launcher grid outside buttons, activate focused.
            // Let's just activate the focused element if clicking. Actually, standard buttons in SwiftUI handle clicks natively!
            // But if they click a focused tile, it should open. Let's let the tile's .onTapGesture handle the activation
            // rather than capturing globally, which would steal clicks from sheets or buttons!
            // So we don't necessarily need a global leftMouseDown monitor if we have .onTapGesture on TileView!
            // That is much cleaner and safer.
            
            return event
        }
    }

    func stop() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func convertToTopLeft(_ point: CGPoint, in window: NSWindow?) -> CGPoint {
        guard let win = window else { return point }
        // Convert bottom-left coordinates to top-left coordinates to match SwiftUI geometry reader
        return CGPoint(x: point.x, y: win.frame.height - point.y)
    }

    private func snapFocusToNearestTile(at point: CGPoint) {
        // Find nearest tile coordinates
        guard let pos = registry.nearestPosition(to: point) else { return }
        
        // Compute distance, must be within 80pt threshold to prevent accidental jumps
        if let dist = registry.distance(toPosition: pos, from: point), dist <= 80.0 {
            if viewModel.focusedPosition != pos {
                viewModel.focusedPosition = pos
                
                // Update accent
                if pos.sectionIndex < viewModel.sections.count {
                    let sec = viewModel.sections[pos.sectionIndex]
                    if pos.itemIndex < sec.items.count {
                        viewModel.updateAccent(for: sec.items[pos.itemIndex])
                    } else {
                        // focused on Add tile
                        withAnimation(.easeInOut(duration: 0.8)) {
                            viewModel.backgroundAccentColor = .gray
                        }
                    }
                }
            }
        }
    }
}
