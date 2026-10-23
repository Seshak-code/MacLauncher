import SwiftUI
import AppKit

final class GlobalVirtualKeyboardWindow: NSPanel {
    static let shared = GlobalVirtualKeyboardWindow()
    
    private weak var viewModel: LauncherViewModel?
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 420),
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
    }
    
    func setup(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
        
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
    }
    
    func show() {
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let keyboardWidth: CGFloat = 1100
            let keyboardHeight: CGFloat = 420
            let x = screenRect.origin.x + (screenRect.size.width - keyboardWidth) / 2
            let overscanY = viewModel?.overscanVertical ?? 0.0
            let y = screenRect.origin.y + 50 + overscanY
            self.setFrame(NSRect(x: x, y: y, width: keyboardWidth, height: keyboardHeight), display: true)
        }
        
        self.orderFrontRegardless()
    }
    
    func hide() {
        self.orderOut(nil)
    }
}
