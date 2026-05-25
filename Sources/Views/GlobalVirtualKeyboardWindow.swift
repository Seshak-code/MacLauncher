import SwiftUI
import AppKit

final class GlobalVirtualKeyboardWindow: NSPanel {
    static let shared = GlobalVirtualKeyboardWindow()
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 500),
            styleMask: [.borderless, .hudWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver // Float on top of everything, including full-screen apps
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Remove .nonactivatingPanel so it can capture focus and keystrokes
        self.styleMask.remove(.nonactivatingPanel)
    }
    
    func setup(viewModel: LauncherViewModel) {
        let view = ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(28)
                .ignoresSafeArea()
            
            HStack(spacing: 48) {
                VirtualKeyboard()
                
                if viewModel.isPhoneKeyboardActive {
                    IPhoneKeyboardContinuityView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(32)
        }
        .environment(viewModel)
        .preferredColorScheme(.dark)
        
        self.contentView = NSHostingView(rootView: view)
        
        // Center on the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let x = screenRect.origin.x + (screenRect.size.width - 1100) / 2
            let y = screenRect.origin.y + (screenRect.size.height - 500) / 2
            self.setFrame(NSRect(x: x, y: y, width: 1100, height: 500), display: true)
        }
    }
    
    private var previouslyActiveApp: NSRunningApplication?
    
    func show() {
        // Capture currently active app
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        self.orderOut(nil)
        
        // Restore focus to the previously active app
        if let app = previouslyActiveApp {
            app.activate(options: [.activateAllWindows])
            previouslyActiveApp = nil
        }
    }
}
