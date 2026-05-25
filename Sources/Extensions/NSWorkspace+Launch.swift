import AppKit

extension NSWorkspace {
    func launchItem(_ itemString: String, bundleID: String? = nil, completion: @escaping (Bool) -> Void) {
        DiagnosticsManager.shared.log("Attempting to launch item: \(itemString) with bundleID: \(bundleID ?? "None")")
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = true // Force a new separate process instance!

        // 1. Check if it's a website URL
        if itemString.lowercased().hasPrefix("http://") || itemString.lowercased().hasPrefix("https://") {
            if let url = URL(string: itemString) {
                // Find default browser to open this URL
                if let browserURL = self.urlForApplication(toOpen: url) {
                    let browserName = browserURL.lastPathComponent.lowercased()
                    DiagnosticsManager.shared.log("Default browser found: \(browserURL.path) (Name: \(browserName))")
                    
                    // Implement browser-specific command-line arguments to force independent profile sandbox instances
                    if browserName.contains("chrome") {
                        let profilePath = getProfilePath(for: "Chrome", itemString: itemString)
                        config.arguments = [
                            "--new-window",
                            "--user-data-dir=\(profilePath)",
                            itemString
                        ]
                        DiagnosticsManager.shared.log("Launching Google Chrome with profile: \(profilePath)")
                    } else if browserName.contains("firefox") {
                        let profilePath = getProfilePath(for: "Firefox", itemString: itemString)
                        config.arguments = [
                            "--new-instance",
                            "-profile",
                            profilePath,
                            itemString
                        ]
                        DiagnosticsManager.shared.log("Launching Firefox with profile: \(profilePath)")
                    } else {
                        // Safari / fallback default
                        config.arguments = [itemString]
                    }
                    
                    self.openApplication(at: browserURL, configuration: config) { app, error in
                        if let runningApp = app {
                            DiagnosticsManager.shared.log("Browser launched successfully (PID: \(runningApp.processIdentifier)). Initializing AX fullscreen.")
                            // Check if fullscreen behavior setting allows fullscreen
                            let behavior = UserDefaults.standard.string(forKey: "FullscreenBehavior") ?? "alwaysFullscreen"
                            if behavior != "windowed" {
                                GlobalInputSimulator.shared.makeApplicationFullscreen(app: runningApp)
                            }
                        }
                        if let err = error {
                            DiagnosticsManager.shared.log("Error launching browser: \(err.localizedDescription)")
                        }
                        completion(error == nil)
                    }
                } else {
                    DiagnosticsManager.shared.log("Unable to find default application to open URL. Falling back to simple open.")
                    self.open(url)
                    completion(true)
                }
                return
            }
        }

        // 2. If bundle identifier is provided, prefer launching by bundle ID
        if let bid = bundleID, !bid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let appURL = self.urlForApplication(withBundleIdentifier: bid) {
                DiagnosticsManager.shared.log("Located application via bundle ID: \(bid) at \(appURL.path)")
                self.openApplication(at: appURL, configuration: config) { app, error in
                    if let runningApp = app {
                        DiagnosticsManager.shared.log("Application \(bid) launched (PID: \(runningApp.processIdentifier)). Initializing AX fullscreen.")
                        let behavior = UserDefaults.standard.string(forKey: "FullscreenBehavior") ?? "alwaysFullscreen"
                        if behavior != "windowed" {
                            GlobalInputSimulator.shared.makeApplicationFullscreen(app: runningApp)
                        }
                    }
                    if let err = error {
                        DiagnosticsManager.shared.log("Error launching application \(bid): \(err.localizedDescription)")
                    }
                    completion(error == nil)
                }
                return
            }
        }

        // 3. Fallback: try opening path as local file URL
        let path = itemString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            let fileURL = path.hasPrefix("file://") ? URL(string: path) : URL(fileURLWithPath: path)
            if let fUrl = fileURL {
                DiagnosticsManager.shared.log("Launching fallback local file URL: \(fUrl.path)")
                self.openApplication(at: fUrl, configuration: config) { app, error in
                    if let runningApp = app {
                        DiagnosticsManager.shared.log("Local application launched (PID: \(runningApp.processIdentifier)). Initializing AX fullscreen.")
                        let behavior = UserDefaults.standard.string(forKey: "FullscreenBehavior") ?? "alwaysFullscreen"
                        if behavior != "windowed" {
                            GlobalInputSimulator.shared.makeApplicationFullscreen(app: runningApp)
                        }
                    }
                    if let err = error {
                        DiagnosticsManager.shared.log("Error launching local path: \(err.localizedDescription)")
                    }
                    completion(error == nil)
                }
                return
            }
        }
        
        DiagnosticsManager.shared.log("Launch item failed: empty path/url")
        completion(false)
    }

    private func getProfilePath(for browserName: String, itemString: String) -> String {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacLauncher")
            .appendingPathComponent("Profiles")
            .appendingPathComponent(browserName)
        
        // Clean URL string to make a safe directory name
        let safeName = itemString.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
            .prefix(30)
        
        let profileDir = appSupportDir.appendingPathComponent(String(safeName))
        try? fileManager.createDirectory(at: profileDir, withIntermediateDirectories: true, attributes: nil)
        return profileDir.path
    }
}
