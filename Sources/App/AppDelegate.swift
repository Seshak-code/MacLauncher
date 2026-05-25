import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give SwiftUI a moment to create the window
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            
            // Setup fullscreen-friendly behaviors
            window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
            window.backgroundColor = NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)
            window.isOpaque = true
            
            // Auto fullscreen on start — slightly delayed so window is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Only set presentation options when we actually have a fullscreen window
        // Setting hideDock/hideMenuBar when not fullscreen can cause visual glitches
        guard let window = NSApp.windows.first,
              window.styleMask.contains(.fullScreen) else {
            return
        }
        
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar
        ]
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Restore Dock and Menubar when launching websites/other apps
        NSApp.presentationOptions = []
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }
}
