import SwiftUI
import AppKit
import Combine

@Observable
final class LauncherViewModel {
    // Launcher state
    var sections: [LauncherSection] = []
    var focusedPosition: FocusPosition = FocusPosition(sectionIndex: 0, itemIndex: 0)
    var backgroundAccentColor: Color = .blue
    
    // Add Item sheet state
    var isAddingItem: Bool = false
    var addTargetSectionID: UUID? = nil
    
    // Calibration state
    var isCalibrating: Bool = false
    var isControllerSettingsVisible: Bool = false
    var overscanHorizontal: CGFloat = 0.0
    var overscanVertical: CGFloat = 0.0
    
    // Live gamepad diagnostics
    var isControllerConnected: Bool = false
    var connectedControllerName: String = "None"
    var liveRightStickX: Float = 0.0
    var liveRightStickY: Float = 0.0
    
    // Apple TV tvOS Big Screen Extensions
    var liveLeftStickX: Float = 0.0
    var liveLeftStickY: Float = 0.0
    
    // Cinematic Player simulation
    var isCinematicPlayerVisible: Bool = false
    var playerProgress: Double = 0.0
    var playerVolume: Double = 0.8
    var isPlaying: Bool = false
    
    // Continuity Profile Switcher & AirPods
    var isProfileSwitcherVisible: Bool = false
    var profileFocusedIndex: Int = 0
    var currentProfileName: String = "seshak"
    var activeAirPods: String = "AirPods Pro (seshak)"
    
    // Continuity OS HUD Notifications
    var continuityNotificationText: String? = nil
    var continuityNotificationSubtext: String? = nil
    var continuityNotificationIcon: String = "person.crop.circle"
    var isPhoneKeyboardActive: Bool = false
    
    // Web Metadata RAM Streaming
    var webMetadataCache: [String: WebMetadata] = [:]
    
    // App Switcher state
    var isAppSwitcherVisible: Bool = false
    var appSwitcherItems: [AppSwitcherItem] = []
    var appSwitcherFocusedIndex: Int = 0
    
    // Virtual Keyboard state
    var isKeyboardVisible: Bool = false
    var keyboardPrompt: String = ""
    var virtualKeyboardText: String = ""
    var keyboardFocusedRow: Int = 0
    var keyboardFocusedCol: Int = 0
    private var onKeyboardSubmit: ((String) -> Void)? = nil
    private var onKeyboardCancel: (() -> Void)? = nil
    
    // Track which app we launched so we can watch for its termination
    private var launchedAppBundleID: String? = nil
    private var workspaceObservers: [NSObjectProtocol] = []
    
    // Dock Plist Watcher
    private var dockWatcherSource: DispatchSourceFileSystemObject?
    private var dockFileDescriptor: Int32 = -1
    
    // Settings configuration
    var fullscreenBehavior: String {
        get { UserDefaults.standard.string(forKey: "FullscreenBehavior") ?? "alwaysFullscreen" }
        set {
            UserDefaults.standard.set(newValue, forKey: "FullscreenBehavior")
            DiagnosticsManager.shared.log("FullscreenBehavior setting updated to: \(newValue)")
        }
    }
    
    var controllerSeizeMode: String {
        get { UserDefaults.standard.string(forKey: "ControllerSeizeMode") ?? "exclusive" }
        set {
            UserDefaults.standard.set(newValue, forKey: "ControllerSeizeMode")
            DiagnosticsManager.shared.log("ControllerSeizeMode setting updated to: \(newValue)")
            GameControllerManager.shared.stop()
            GameControllerManager.shared.start()
        }
    }
    
    // Keyboard Layout (Apple TV style)
    let keyboardLayout: [[String]] = [
        ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"],
        ["N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"],
        ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m"],
        ["n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"],
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "_", "/"],
        [".", ":", "@", "#", "$", "%", "&", "*", "(", ")", "+", "=", "?"],
        ["Space", "Backspace", "Clear", "Cancel", "Done"]
    ]

    var lastGridPosition: FocusPosition = FocusPosition(sectionIndex: 0, itemIndex: 0)

    var focusedItem: LauncherItem? {
        guard focusedPosition.sectionIndex >= 0, focusedPosition.sectionIndex < sections.count else { return nil }
        let section = sections[focusedPosition.sectionIndex]
        guard focusedPosition.itemIndex >= 0, focusedPosition.itemIndex < section.items.count else { return nil }
        return section.items[focusedPosition.itemIndex]
    }

    var topShelfItem: LauncherItem? {
        let pos = (focusedPosition.sectionIndex >= 0) ? focusedPosition : lastGridPosition
        guard pos.sectionIndex >= 0, pos.sectionIndex < sections.count else { return nil }
        let sec = sections[pos.sectionIndex]
        guard pos.itemIndex >= 0, pos.itemIndex < sec.items.count else { return nil }
        return sec.items[pos.itemIndex]
    }

    init() {
        load()
        self.overscanHorizontal = CGFloat(UserDefaults.standard.double(forKey: "overscanHorizontal"))
        self.overscanVertical = CGFloat(UserDefaults.standard.double(forKey: "overscanVertical"))
        observeWorkspace()
    }
    
    deinit {
        stopWatchingDockPlist()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - Workspace Observation (Auto-return when launched app quits)
    
    private func observeWorkspace() {
        // Watch for app terminations
        let terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            
            // If the app that quit is one we launched, bring launcher back
            if let launchedID = self.launchedAppBundleID, app.bundleIdentifier == launchedID {
                self.launchedAppBundleID = nil
                self.returnToLauncher()
            }
        }
        workspaceObservers.append(terminateObserver)
        
        // Watch for app deactivations — if the launched app loses focus to something else, clear tracking
        let deactivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            // No action needed, but could be used for future enhancements
            _ = self
        }
        workspaceObservers.append(deactivateObserver)
    }
    
    func returnToLauncher() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
    
    // MARK: - Navigation Control
    
    let profiles = ["seshak", "John", "Guest"]

    private func moveProfileFocus(_ direction: MoveDirection) {
        switch direction {
        case .up:
            if profileFocusedIndex > 0 {
                profileFocusedIndex -= 1
            } else {
                profileFocusedIndex = profiles.count - 1
            }
        case .down:
            if profileFocusedIndex < profiles.count - 1 {
                profileFocusedIndex += 1
            } else {
                profileFocusedIndex = 0
            }
        default:
            break
        }
    }

    private func activateProfileFocused() {
        let selectedProfile = profiles[profileFocusedIndex]
        currentProfileName = selectedProfile
        activeAirPods = "AirPods Pro (\(selectedProfile))"
        withAnimation(.easeInOut(duration: 0.25)) {
            isProfileSwitcherVisible = false
        }
        showContinuityNotification(text: "Profile Switched", subtext: "Logged in as \(selectedProfile) - AirPods Connected", icon: "person.crop.circle")
    }

    func moveFocus(_ direction: MoveDirection) {
        if isCinematicPlayerVisible {
            return
        }
        
        if isProfileSwitcherVisible {
            moveProfileFocus(direction)
            return
        }

        if isKeyboardVisible {
            moveKeyboardFocus(direction)
            return
        }
        
        if isAppSwitcherVisible {
            moveAppSwitcherFocus(direction)
            return
        }
        
        if isCalibrating {
            moveCalibration(direction)
            return
        }
        
        guard !sections.isEmpty else { return }
        
        // Handle Top Shelf focus
        if focusedPosition.sectionIndex == -1 {
            switch direction {
            case .left:
                if focusedPosition.itemIndex > 0 {
                    focusedPosition.itemIndex -= 1
                } else {
                    focusedPosition.itemIndex = 1
                }
            case .right:
                if focusedPosition.itemIndex < 1 {
                    focusedPosition.itemIndex += 1
                } else {
                    focusedPosition.itemIndex = 0
                }
            case .down:
                let targetSecIdx = 0
                let targetSec = sections[targetSecIdx]
                let targetItemIdx = min(lastGridPosition.itemIndex, targetSec.items.count)
                focusedPosition = FocusPosition(sectionIndex: targetSecIdx, itemIndex: targetItemIdx)
                if let item = focusedItem {
                    updateAccent(for: item)
                }
            case .up:
                let targetSecIdx = sections.count - 1
                let targetSec = sections[targetSecIdx]
                let targetItemIdx = min(lastGridPosition.itemIndex, targetSec.items.count)
                focusedPosition = FocusPosition(sectionIndex: targetSecIdx, itemIndex: targetItemIdx)
                if let item = focusedItem {
                    updateAccent(for: item)
                }
            }
            return
        }
        
        var nextSectionIndex = focusedPosition.sectionIndex
        var nextItemIndex = focusedPosition.itemIndex
        
        switch direction {
        case .right:
            let currentSection = sections[nextSectionIndex]
            if nextItemIndex < currentSection.items.count {
                nextItemIndex += 1
            } else {
                nextItemIndex = 0
            }
        case .left:
            let currentSection = sections[nextSectionIndex]
            if nextItemIndex > 0 {
                nextItemIndex -= 1
            } else {
                nextItemIndex = currentSection.items.count
            }
        case .down:
            if nextSectionIndex < sections.count - 1 {
                nextSectionIndex += 1
            } else {
                lastGridPosition = focusedPosition
                focusedPosition = FocusPosition(sectionIndex: -1, itemIndex: 0)
                withAnimation(.easeInOut(duration: 0.8)) {
                    backgroundAccentColor = Color.gray
                }
                return
            }
            let targetSection = sections[nextSectionIndex]
            nextItemIndex = min(nextItemIndex, targetSection.items.count)
        case .up:
            if nextSectionIndex > 0 {
                nextSectionIndex -= 1
            } else {
                lastGridPosition = focusedPosition
                focusedPosition = FocusPosition(sectionIndex: -1, itemIndex: 0)
                withAnimation(.easeInOut(duration: 0.8)) {
                    backgroundAccentColor = Color.gray
                }
                return
            }
            let targetSection = sections[nextSectionIndex]
            nextItemIndex = min(nextItemIndex, targetSection.items.count)
        }
        
        let newPos = FocusPosition(sectionIndex: nextSectionIndex, itemIndex: nextItemIndex)
        if newPos != focusedPosition {
            focusedPosition = newPos
            if let item = focusedItem {
                updateAccent(for: item)
            } else {
                withAnimation(.easeInOut(duration: 0.8)) {
                    backgroundAccentColor = Color.gray
                }
            }
        }
    }
    
    func activateFocused() {
        if isCinematicPlayerVisible {
            isPlaying.toggle()
            return
        }
        
        if isProfileSwitcherVisible {
            activateProfileFocused()
            return
        }

        if isKeyboardVisible {
            activateKeyboardFocusedKey()
            return
        }
        
        if isAppSwitcherVisible {
            activateAppSwitcherFocusedApp()
            return
        }
        
        if isCalibrating {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCalibrating = false
            }
            saveOverscan()
            return
        }
        
        if focusedPosition.sectionIndex == -1 {
            guard let item = topShelfItem else { return }
            if focusedPosition.itemIndex == 0 {
                if item.name.lowercased().contains("youtube") || item.name.lowercased().contains("trailer") || item.itemType == .website {
                    openCinematicPlayer()
                } else {
                    launchItem(item)
                }
            } else {
                showContinuityNotification(text: "Favorites Updated", subtext: "\(item.name) added to Favorites shelf", icon: "star.fill")
            }
            return
        }
        
        guard focusedPosition.sectionIndex >= 0, focusedPosition.sectionIndex < sections.count else { return }
        let section = sections[focusedPosition.sectionIndex]
        
        if focusedPosition.itemIndex == section.items.count {
            addTargetSectionID = section.id
            isAddingItem = true
        } else {
            launchFocusedItem()
        }
    }
    
    func cancelOrBack() {
        if isCinematicPlayerVisible {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCinematicPlayerVisible = false
                isPlaying = false
            }
            return
        }
        
        if isProfileSwitcherVisible {
            withAnimation(.easeInOut(duration: 0.25)) {
                isProfileSwitcherVisible = false
            }
            return
        }

        if isKeyboardVisible {
            cancelKeyboard()
            return
        }
        
        if isAppSwitcherVisible {
            withAnimation(.easeInOut(duration: 0.25)) {
                isAppSwitcherVisible = false
            }
            return
        }
        
        if isCalibrating {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCalibrating = false
            }
            saveOverscan()
            return
        }
        
        if isAddingItem {
            isAddingItem = false
            return
        }
        
        if focusedPosition.sectionIndex == -1 {
            let targetSecIdx = 0
            let targetSec = sections[targetSecIdx]
            let targetItemIdx = min(lastGridPosition.itemIndex, targetSec.items.count)
            focusedPosition = FocusPosition(sectionIndex: targetSecIdx, itemIndex: targetItemIdx)
            if let item = focusedItem {
                updateAccent(for: item)
            }
            return
        }
    }
    
    // MARK: - Virtual Keyboard Logic
    
    func showKeyboard(initialText: String, prompt: String, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        virtualKeyboardText = initialText
        keyboardPrompt = prompt
        onKeyboardSubmit = onSubmit
        onKeyboardCancel = onCancel
        keyboardFocusedRow = 0
        keyboardFocusedCol = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            isKeyboardVisible = true
            isPhoneKeyboardActive = true
        }
        showContinuityNotification(text: "iPhone Keyboard", subtext: "Keyboard input active on iPhone", icon: "keyboard.iphone")
        
        DispatchQueue.main.async {
            GlobalVirtualKeyboardWindow.shared.show()
        }
    }
    
    func toggleVirtualKeyboard() {
        if isKeyboardVisible {
            cancelKeyboard()
        } else {
            showKeyboard(initialText: "", prompt: "Type Here") { text in
                if !text.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        GlobalInputSimulator.shared.simulateTyping(text)
                    }
                }
            } onCancel: {}
        }
    }
    
    private func moveKeyboardFocus(_ direction: MoveDirection) {
        let maxRow = keyboardLayout.count - 1
        var nextRow = keyboardFocusedRow
        var nextCol = keyboardFocusedCol
        
        switch direction {
        case .up:
            if nextRow > 0 {
                nextRow -= 1
            } else {
                nextRow = maxRow
            }
        case .down:
            if nextRow < maxRow {
                nextRow += 1
            } else {
                nextRow = 0
            }
        case .left:
            if nextCol > 0 {
                nextCol -= 1
            } else {
                nextCol = keyboardLayout[nextRow].count - 1
            }
        case .right:
            let maxCol = keyboardLayout[nextRow].count - 1
            if nextCol < maxCol {
                nextCol += 1
            } else {
                nextCol = 0
            }
        }
        
        keyboardFocusedRow = nextRow
        let maxColInNewRow = keyboardLayout[nextRow].count - 1
        keyboardFocusedCol = min(nextCol, maxColInNewRow)
    }
    
    private func activateKeyboardFocusedKey() {
        let key = keyboardLayout[keyboardFocusedRow][keyboardFocusedCol]
        switch key {
        case "Space":
            virtualKeyboardText += " "
        case "Backspace":
            if !virtualKeyboardText.isEmpty {
                virtualKeyboardText.removeLast()
            }
        case "Clear":
            virtualKeyboardText = ""
        case "Cancel":
            cancelKeyboard()
        case "Done":
            submitKeyboard()
        default:
            virtualKeyboardText += key
        }
    }
    
    func submitKeyboard() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isKeyboardVisible = false
            isPhoneKeyboardActive = false
        }
        onKeyboardSubmit?(virtualKeyboardText)
        DispatchQueue.main.async {
            GlobalVirtualKeyboardWindow.shared.hide()
        }
    }
    
    private func cancelKeyboard() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isKeyboardVisible = false
            isPhoneKeyboardActive = false
        }
        onKeyboardCancel?()
        DispatchQueue.main.async {
            GlobalVirtualKeyboardWindow.shared.hide()
        }
    }
    
    // MARK: - Cinematic Player and Web Metadata & Continuity Helpers
    
    private var playerTimer: AnyCancellable?
    private var notificationTimer: AnyCancellable?
    
    func openCinematicPlayer() {
        playerProgress = 0.0
        isPlaying = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isCinematicPlayerVisible = true
        }
        showContinuityNotification(text: "Now Playing", subtext: "Cinematic media playback started", icon: "play.tv.fill")
        
        playerTimer?.cancel()
        playerTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isCinematicPlayerVisible && self.isPlaying {
                    if self.playerProgress < 1.0 {
                        self.playerProgress += 0.005
                    } else {
                        self.playerProgress = 0.0
                    }
                }
            }
    }
    
    func scrubTimeline(by amount: Double) {
        isPlaying = false
        playerProgress = min(max(playerProgress + amount, 0.0), 1.0)
    }
    
    func adjustVolume(by amount: Double) {
        playerVolume = min(max(playerVolume + amount, 0.0), 1.0)
    }
    
    func showContinuityNotification(text: String, subtext: String, icon: String) {
        continuityNotificationText = text
        continuityNotificationSubtext = subtext
        continuityNotificationIcon = icon
        
        notificationTimer?.cancel()
        notificationTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.continuityNotificationText = nil
                    self.continuityNotificationSubtext = nil
                }
                self.notificationTimer?.cancel()
            }
    }
    
    func fetchWebMetadata(for urlString: String) {
        if webMetadataCache[urlString] != nil {
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        webMetadataCache[urlString] = WebMetadata(title: url.host ?? urlString, description: "Loading metadata...", logoURL: nil, cachedImage: nil)
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10.0
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return
                }
                
                guard let html = String(data: data, encoding: .utf8) else { return }
                
                var title = url.host ?? urlString
                if let titleRange = html.range(of: "<title>(.*?)</title>", options: [.regularExpression, .caseInsensitive]) {
                    let fullMatch = html[titleRange]
                    title = fullMatch.replacingOccurrences(of: "<title>", with: "", options: .caseInsensitive)
                        .replacingOccurrences(of: "</title>", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                var description = "No description available."
                let descPatterns = [
                    #"<meta[^>]*property=["']og:description["'][^>]*content=["'](.*?)["']"#,
                    #"<meta[^>]*content=["'](.*?)["'][^>]*property=["']og:description["']"#,
                    #"<meta[^>]*name=["']description["'][^>]*content=["'](.*?)["']"#,
                    #"<meta[^>]*content=["'](.*?)["'][^>]*name=["']description["']"#
                ]
                for pattern in descPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                       let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)) {
                        if let range = Range(match.range(at: 1), in: html) {
                            description = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                }
                
                var iconURLString: String? = nil
                let iconPatterns = [
                    #"<meta[^>]*property=["']og:image["'][^>]*content=["'](.*?)["']"#,
                    #"<meta[^>]*content=["'](.*?)["'][^>]*property=["']og:image["']"#,
                    #"<link[^>]*rel=["']apple-touch-icon["'][^>]*href=["'](.*?)["']"#,
                    #"<link[^>]*href=["'](.*?)["'][^>]*rel=["']apple-touch-icon["']"#,
                    #"<link[^>]*rel=["']shortcut icon["'][^>]*href=["'](.*?)["']"#,
                    #"<link[^>]*rel=["']icon["'][^>]*href=["'](.*?)["']"#
                ]
                
                for pattern in iconPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                       let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)) {
                        if let range = Range(match.range(at: 1), in: html) {
                            iconURLString = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                }
                
                var resolvedIconURL: URL? = nil
                if let iconStr = iconURLString {
                    if iconStr.hasPrefix("http://") || iconStr.hasPrefix("https://") {
                        resolvedIconURL = URL(string: iconStr)
                    } else if iconStr.hasPrefix("//") {
                        resolvedIconURL = URL(string: "https:" + iconStr)
                    } else {
                        if let base = URL(string: urlString) {
                            resolvedIconURL = URL(string: iconStr, relativeTo: base)
                        }
                    }
                }
                
                if resolvedIconURL == nil {
                    if let base = URL(string: urlString) {
                        resolvedIconURL = URL(string: "/favicon.ico", relativeTo: base)
                    }
                }
                
                var loadedImage: NSImage? = nil
                if let resolvedURL = resolvedIconURL {
                    let (imgData, imgResponse) = try await URLSession.shared.data(from: resolvedURL)
                    if let httpImgResponse = imgResponse as? HTTPURLResponse, httpImgResponse.statusCode == 200 {
                        loadedImage = NSImage(data: imgData)
                    }
                }
                
                let metadata = WebMetadata(
                    title: title,
                    description: description,
                    logoURL: resolvedIconURL?.absoluteString,
                    cachedImage: loadedImage
                )
                
                await MainActor.run {
                    self.webMetadataCache[urlString] = metadata
                }
            } catch {
                print("Failed to fetch web metadata for \(urlString): \(error)")
                await MainActor.run {
                    self.webMetadataCache[urlString] = WebMetadata(
                        title: url.host ?? urlString,
                        description: "Failed to load website details.",
                        logoURL: nil,
                        cachedImage: nil
                    )
                }
            }
        }
    }
    
    private func launchItem(_ item: LauncherItem) {
        launchedAppBundleID = item.iconBundleID
        NSWorkspace.shared.launchItem(item.url, bundleID: item.iconBundleID) { success in
            if success {
                DiagnosticsManager.shared.log("Successfully launched item: \(item.name)")
            } else {
                DiagnosticsManager.shared.log("Failed to launch item: \(item.name)")
            }
        }
    }

    
    // MARK: - App Switcher Logic
    
    func toggleAppSwitcher() {
        GlobalInputSimulator.shared.triggerOSAppSwitcher()
    }
    
    func refreshAppSwitcherItems() {
        let currentApps = NSWorkspace.shared.runningApplications
        let filteredRunning = currentApps.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        
        var newItems: [AppSwitcherItem] = filteredRunning.map { app in
            let path = app.bundleURL?.path ?? ""
            let icon = app.icon
            return AppSwitcherItem(
                id: "\(app.processIdentifier)",
                name: app.localizedName ?? "Unknown App",
                iconEmoji: nil,
                isRunning: true,
                bundleID: app.bundleIdentifier ?? "",
                pathOrUrl: path,
                runningApp: app,
                cachedIcon: icon
            )
        }
        
        // Add closed launcher apps/games
        for section in sections {
            for launcherItem in section.items {
                guard launcherItem.itemType == .app || launcherItem.itemType == .game else { continue }
                
                let isRunning = filteredRunning.contains { app in
                    guard let bundleID = launcherItem.iconBundleID else { return false }
                    return app.bundleIdentifier == bundleID
                }
                
                if !isRunning {
                    let path = launcherItem.url
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    newItems.append(AppSwitcherItem(
                        id: launcherItem.id.uuidString,
                        name: launcherItem.name,
                        iconEmoji: launcherItem.iconEmoji,
                        isRunning: false,
                        bundleID: launcherItem.iconBundleID ?? "",
                        pathOrUrl: path,
                        runningApp: nil,
                        cachedIcon: icon
                    ))
                }
            }
        }
        
        self.appSwitcherItems = newItems
    }
    
    private func moveAppSwitcherFocus(_ direction: MoveDirection) {
        guard !appSwitcherItems.isEmpty else { return }
        switch direction {
        case .left:
            if appSwitcherFocusedIndex > 0 {
                appSwitcherFocusedIndex -= 1
            }
        case .right:
            if appSwitcherFocusedIndex < appSwitcherItems.count - 1 {
                appSwitcherFocusedIndex += 1
            }
        default:
            break
        }
    }
    
    private func activateAppSwitcherFocusedApp() {
        activateAppSwitcherItem(at: appSwitcherFocusedIndex)
    }
    
    func activateAppSwitcherItem(at index: Int) {
        guard index >= 0, index < appSwitcherItems.count else { return }
        let item = appSwitcherItems[index]
        
        if item.isRunning, let app = item.runningApp {
            launchedAppBundleID = app.bundleIdentifier
            app.activate(options: [.activateAllWindows])
        } else {
            // Launch closed app
            launchedAppBundleID = item.bundleID
            
            NSWorkspace.shared.launchItem(item.pathOrUrl, bundleID: item.bundleID.isEmpty ? nil : item.bundleID) { success in
                if success {
                    DiagnosticsManager.shared.log("Successfully launched app switcher item: \(item.name)")
                } else {
                    DiagnosticsManager.shared.log("Failed to launch app switcher item: \(item.name)")
                }
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isAppSwitcherVisible = false
        }
    }
    
    func terminateAppInSwitcher(at index: Int) {
        guard index >= 0, index < appSwitcherItems.count else { return }
        let item = appSwitcherItems[index]
        guard item.isRunning, let app = item.runningApp else { return }
        
        app.forceTerminate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshAppSwitcherItems()
            if let self = self {
                self.appSwitcherFocusedIndex = min(self.appSwitcherFocusedIndex, max(0, self.appSwitcherItems.count - 1))
            }
        }
    }
    
    // MARK: - Calibration Logic
    
    private func moveCalibration(_ direction: MoveDirection) {
        switch direction {
        case .up:
            overscanVertical = min(overscanVertical + 5, 120)
        case .down:
            overscanVertical = max(overscanVertical - 5, 0)
        case .left:
            overscanHorizontal = min(overscanHorizontal + 5, 120)
        case .right:
            overscanHorizontal = max(overscanHorizontal - 5, 0)
        }
    }
    
    func saveOverscan() {
        UserDefaults.standard.set(Double(overscanHorizontal), forKey: "overscanHorizontal")
        UserDefaults.standard.set(Double(overscanVertical), forKey: "overscanVertical")
    }

    // MARK: - App Launch (Always Fullscreen)
    
    private func launchFocusedItem() {
        guard let item = focusedItem else { return }
        
        launchedAppBundleID = item.iconBundleID
        
        NSWorkspace.shared.launchItem(item.url, bundleID: item.iconBundleID) { success in
            if success {
                DiagnosticsManager.shared.log("Successfully launched item: \(item.name)")
            } else {
                DiagnosticsManager.shared.log("Failed to launch item: \(item.name)")
            }
        }
    }
    
    func updateAccent(for item: LauncherItem) {
        if let color = Color(hex: item.accentHex) {
            withAnimation(.easeInOut(duration: 1.4)) {
                backgroundAccentColor = color
            }
        }
    }
    
    // MARK: - Mutation & CRUD
    
    func addItem(_ item: LauncherItem, toSectionID sectionID: UUID) {
        if let idx = sections.firstIndex(where: { $0.id == sectionID }) {
            sections[idx].items.append(item)
            save()
        }
    }
    
    func removeItem(id: UUID, fromSectionID sectionID: UUID) {
        if let idx = sections.firstIndex(where: { $0.id == sectionID }) {
            sections[idx].items.removeAll(where: { $0.id == id })
            save()
            
            if focusedPosition.sectionIndex == idx {
                let maxItems = sections[idx].items.count
                focusedPosition.itemIndex = min(focusedPosition.itemIndex, maxItems)
            }
        }
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let data = try JSONEncoder().encode(sections)
            UserDefaults.standard.set(data, forKey: "LauncherSections")
        } catch {
            print("Failed to save sections: \(error)")
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "LauncherSections"),
           let decoded = try? JSONDecoder().decode([LauncherSection].self, from: data) {
            self.sections = decoded
        } else {
            self.sections = LauncherViewModel.defaults()
        }
        // Always refresh scanned system applications!
        refreshInstalledApplicationsSection()
        // Always refresh Dock applications!
        refreshDockApplicationsSection()
        // Start watching the dock plist for changes!
        startWatchingDockPlist()
    }
    
    func scanInstalledApplications() -> [LauncherItem] {
        var items: [LauncherItem] = []
        let fileManager = FileManager.default
        
        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]
        
        // Scan the folders
        for dir in appDirs {
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for file in files {
                guard file.hasSuffix(".app") else { continue }
                let appPath = (dir as NSString).appendingPathComponent(file)
                let appName = (file as NSString).deletingPathExtension
                
                // Read bundle plist to get bundle ID
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                guard fileManager.fileExists(atPath: plistPath),
                      let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                      let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                      let bundleID = plist["CFBundleIdentifier"] as? String else {
                    continue
                }
                
                // Avoid duplicates
                if items.contains(where: { $0.iconBundleID == bundleID }) { continue }
                
                // Filter out install helper/system broker apps
                guard !bundleID.hasPrefix("com.apple.install") && !bundleID.hasPrefix("com.apple.Safari.SandboxBroker") else { continue }
                
                items.append(LauncherItem(
                    name: appName,
                    iconEmoji: "📱",
                    iconBundleID: bundleID,
                    accentHex: "#1E7CF0",
                    url: appPath,
                    itemType: .app
                ))
            }
        }
        
        // Sort items by name so they look clean in the grid
        return items.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
    }
    
    func refreshInstalledApplicationsSection() {
        let scanned = scanInstalledApplications()
        guard !scanned.isEmpty else { return }
        
        if let idx = sections.firstIndex(where: { $0.label == "Installed Applications" }) {
            sections[idx].items = scanned
        } else {
            let newSection = LauncherSection(label: "Installed Applications", type: .app, items: scanned)
            sections.append(newSection)
        }
    }

    func scanDockApplications() -> [LauncherItem] {
        var items: [LauncherItem] = []
        let plistPath = ("~/Library/Preferences/com.apple.dock.plist" as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: plistPath) else {
            DiagnosticsManager.shared.log("Dock plist file not found at: \(plistPath)")
            return items
        }
        
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            DiagnosticsManager.shared.log("Failed to parse com.apple.dock.plist or persistent-apps key missing.")
            return items
        }
        
        DiagnosticsManager.shared.log("Parsing \(persistentApps.count) Dock persistent apps.")
        for appDict in persistentApps {
            if let tileType = appDict["tile-type"] as? String, tileType != "file-tile" {
                continue
            }
            
            guard let tileData = appDict["tile-data"] as? [String: Any] else { continue }
            guard let fileLabel = tileData["file-label"] as? String else { continue }
            
            let bundleID = tileData["bundle-identifier"] as? String
            
            var appPath: String? = nil
            if let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String {
                if urlString.hasPrefix("file://") {
                    if let url = URL(string: urlString) {
                        appPath = url.path
                    }
                } else {
                    appPath = urlString
                }
            }
            
            guard let path = appPath, FileManager.default.fileExists(atPath: path) else { continue }
            guard path.hasSuffix(".app") || path.hasSuffix(".bundle") else { continue }
            
            items.append(LauncherItem(
                name: fileLabel,
                iconEmoji: "📱",
                iconBundleID: bundleID ?? "",
                accentHex: "#FF2D55",
                url: path,
                itemType: .app
            ))
        }
        DiagnosticsManager.shared.log("Successfully scanned \(items.count) Dock applications.")
        return items
    }

    func refreshDockApplicationsSection() {
        let dockApps = scanDockApplications()
        guard !dockApps.isEmpty else { return }
        
        if let idx = sections.firstIndex(where: { $0.label == "Dock Shortcuts" }) {
            sections[idx].items = dockApps
        } else {
            let newSection = LauncherSection(label: "Dock Shortcuts", type: .app, items: dockApps)
            sections.insert(newSection, at: 0)
        }
    }

    private func startWatchingDockPlist() {
        let plistPath = ("~/Library/Preferences/com.apple.dock.plist" as NSString).expandingTildeInPath
        let fd = open(plistPath, O_EVTONLY)
        guard fd >= 0 else { return }
        
        dockFileDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main)
        
        source.setEventHandler { [weak self] in
            DiagnosticsManager.shared.log("Dock plist changed event detected. Reloading Dock Shortcuts.")
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self?.stopWatchingDockPlist()
                self?.refreshDockApplicationsSection()
                self?.startWatchingDockPlist()
            } else {
                self?.refreshDockApplicationsSection()
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        dockWatcherSource = source
    }
    
    private func stopWatchingDockPlist() {
        dockWatcherSource?.cancel()
        dockWatcherSource = nil
        dockFileDescriptor = -1
    }
    
    // MARK: - Defaults
    
    static func defaults() -> [LauncherSection] {
        return [
            LauncherSection(label: "Most Used Shortcuts", type: .app, items: [
                LauncherItem(name: "Calculator", iconEmoji: "🧮", iconBundleID: "com.apple.calculator", accentHex: "#FF9F0A", url: "/System/Applications/Calculator.app", itemType: .app, subtitle: "Recently Open • Active"),
                LauncherItem(name: "Terminal", iconEmoji: "💻", iconBundleID: "com.apple.Terminal", accentHex: "#30D158", url: "/System/Applications/Utilities/Terminal.app", itemType: .app, subtitle: "CommandLine Tool"),
                LauncherItem(name: "YouTube", iconEmoji: "📺", accentHex: "#FF0000", url: "https://www.youtube.com", itemType: .website, subtitle: "Media Stream • 4K Video"),
                LauncherItem(name: "Chess", iconEmoji: "♟️", iconBundleID: "com.apple.Chess", accentHex: "#BF5AF2", url: "/System/Applications/Chess.app", itemType: .game, subtitle: "Active • 2 Achievements"),
                LauncherItem(name: "System Settings", iconEmoji: "⚙️", iconBundleID: "com.apple.systempreferences", accentHex: "#8E8E93", url: "/System/Applications/System Settings.app", itemType: .app, subtitle: "Settings Config")
            ]),
            LauncherSection(label: "Web Shortcuts", type: .website, items: [
                LauncherItem(name: "Google", iconEmoji: "🔍", accentHex: "#4285F4", url: "https://www.google.com", itemType: .website, subtitle: "Web Search Engine"),
                LauncherItem(name: "YouTube", iconEmoji: "📺", accentHex: "#FF0000", url: "https://www.youtube.com", itemType: .website, subtitle: "Media Stream • 4K Video"),
                LauncherItem(name: "GitHub", iconEmoji: "🐙", accentHex: "#24292F", url: "https://github.com", itemType: .website, subtitle: "Code Hosting Repository"),
                LauncherItem(name: "Netflix", iconEmoji: "🎬", accentHex: "#E50914", url: "https://www.netflix.com", itemType: .website, subtitle: "Netflix TV streaming")
            ]),
            LauncherSection(label: "Games & Entertainment", type: .game, items: [
                LauncherItem(name: "Chess", iconEmoji: "♟️", iconBundleID: "com.apple.Chess", accentHex: "#BF5AF2", url: "/System/Applications/Chess.app", itemType: .game, subtitle: "Active • 2 Achievements"),
                LauncherItem(name: "Apple Arcade", iconEmoji: "🕹️", accentHex: "#FF2D55", url: "https://arcade.apple.com", itemType: .game, subtitle: "Join Arcade Hub"),
                LauncherItem(name: "Game Center", iconEmoji: "🎯", accentHex: "#007AFF", url: "/System/Library/CoreServices/Game Center.app", itemType: .game, subtitle: "John and 3 online")
            ])
        ]
    }
}

enum MoveDirection {
    case up, down, left, right
}

struct AppSwitcherItem: Identifiable, Hashable {
    let id: String
    let name: String
    let iconEmoji: String?
    let isRunning: Bool
    let bundleID: String
    let pathOrUrl: String
    let runningApp: NSRunningApplication?
    let cachedIcon: NSImage?
    
    var icon: NSImage? {
        cachedIcon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppSwitcherItem, rhs: AppSwitcherItem) -> Bool {
        return lhs.id == rhs.id
    }
}
