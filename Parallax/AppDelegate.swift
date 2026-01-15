import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayController: OverlayWindowController!
    var isProcessing = false
    var languageMenu: NSMenu!
    var translationModeMenu: NSMenu!
    
    /// Cached OCR results for re-translation when switching modes
    private var lastOCRResults: [TextBlock]?
    private var lastTargetLanguage: String?
    
    /// Cached menu bar icon to avoid redrawing every time
    private lazy var normalIcon: NSImage? = createMenuBarIcon()
    private lazy var processingIcon: NSImage? = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Processing")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar icon
        setupStatusItem()
        
        // Create overlay controller
        overlayController = OverlayWindowController()
        
        // Register global hotkey (Ctrl+Shift+T)
        HotKeyManager.shared.registerCtrlShiftT { [weak self] in
            self?.toggleTranslation()
        }
        
        // Delay permission check to avoid layout recursion warning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkScreenCapturePermission()
        }
        
        print("[+] \(L("status.ready"))")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = normalIcon ?? NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "Screen Translator")
        }
        
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L("menu.translate"), action: #selector(toggleTranslation), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Target language submenu
        let languageItem = NSMenuItem(title: L("menu.targetLanguage"), action: nil, keyEquivalent: "")
        languageMenu = createLanguageMenu()
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        
        // Translation mode submenu
        let modeItem = NSMenuItem(title: L("menu.translationMode"), action: nil, keyEquivalent: "")
        translationModeMenu = createTranslationModeMenu()
        modeItem.submenu = translationModeMenu
        menu.addItem(modeItem)
        
        // Display selection submenu (multi-monitor support)
        let displayItem = NSMenuItem(title: L("menu.selectDisplay"), action: nil, keyEquivalent: "")
        displayItem.submenu = createDisplayMenu()
        menu.addItem(displayItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func createLanguageMenu() -> NSMenu {
        let menu = NSMenu()
        
        for lang in Settings.supportedLanguages {
            let item = NSMenuItem(
                title: "\(lang.localizedName) (\(lang.name))",
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.representedObject = lang.code
            item.target = self
            
            if lang.code == Settings.shared.targetLanguage {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        return menu
    }
    
    private func createDisplayMenu() -> NSMenu {
        let menu = NSMenu()
        let screens = NSScreen.screens
        
        for (index, screen) in screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(
                title: "\(index + 1). \(name)",
                action: #selector(selectDisplay(_:)),
                keyEquivalent: ""
            )
            item.tag = index
            item.target = self
            
            if index == Settings.shared.selectedDisplayIndex {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        return menu
    }
    
    private func createTranslationModeMenu() -> NSMenu {
        let menu = NSMenu()
        
        let onlineItem = NSMenuItem(
            title: L("menu.mode.online"),
            action: #selector(selectTranslationMode(_:)),
            keyEquivalent: ""
        )
        onlineItem.representedObject = TranslationMode.online
        onlineItem.target = self
        onlineItem.state = Settings.shared.translationMode == .online ? .on : .off
        menu.addItem(onlineItem)
        
        let offlineItem = NSMenuItem(
            title: L("menu.mode.offline"),
            action: #selector(selectTranslationMode(_:)),
            keyEquivalent: ""
        )
        offlineItem.representedObject = TranslationMode.offline
        offlineItem.target = self
        
        // Offline mode only available on macOS 15+
        if TranslationService.isOfflineAvailable {
            offlineItem.state = Settings.shared.translationMode == .offline ? .on : .off
        } else {
            offlineItem.isEnabled = false
            offlineItem.title = L("menu.mode.offline") + " (macOS 15+)"
        }
        menu.addItem(offlineItem)
        
        return menu
    }
    
    @objc func selectTranslationMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? TranslationMode else { return }
        
        Settings.shared.translationMode = mode
        
        // Update menu checkmarks
        for item in translationModeMenu.items {
            item.state = (item.representedObject as? TranslationMode) == mode ? .on : .off
        }
        
        // Invalidate offline session when switching modes
        TranslationService.shared.invalidateOfflineSession()
        
        print("[*] Translation mode changed to: \(mode == .online ? "Online (API)" : "Offline (Apple)")")
        
        // Re-translate if overlay is visible
        if overlayController.isVisible, let ocrResults = lastOCRResults, let targetLang = lastTargetLanguage {
            retranslateWithNewMode(ocrResults: ocrResults, targetLang: targetLang)
        }
    }
    
    /// Re-translate existing OCR results with new translation mode
    private func retranslateWithNewMode(ocrResults: [TextBlock], targetLang: String) {
        guard !isProcessing else { return }
        
        isProcessing = true
        updateMenuBarIcon(processing: true)
        
        print("[*] Re-translating with new mode...")
        TranslationService.shared.translate(blocks: ocrResults, to: targetLang) { [weak self] translatedResults, success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.updateMenuBarIcon(processing: false)
                
                // Check if translation was cancelled
                let wasCancelled = !success && translatedResults.count == ocrResults.count &&
                    zip(translatedResults, ocrResults).allSatisfy { $0.text == $1.text }
                
                if wasCancelled {
                    print("[*] Re-translation cancelled")
                    return
                }
                
                // Update overlay with new translations
                self.overlayController.updateTranslations(translatedResults)
                print("[+] Re-translation done")
            }
        }
    }
    
    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let langCode = sender.representedObject as? String else { return }
        
        Settings.shared.targetLanguage = langCode
        
        for item in languageMenu.items {
            item.state = (item.representedObject as? String) == langCode ? .on : .off
        }
        
        // Invalidate offline session when language changes
        TranslationService.shared.invalidateOfflineSession()
        
        print("[*] Target language changed to: \(Settings.shared.targetLanguageName)")
    }
    
    @objc func selectDisplay(_ sender: NSMenuItem) {
        let index = sender.tag
        Settings.shared.selectedDisplayIndex = index
        
        // Update menu checkmarks
        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == index ? .on : .off
            }
        }
        
        print("[*] Selected display: \(index + 1)")
    }
    
    /// Create menu bar icon (called once, result is cached)
    private func createMenuBarIcon() -> NSImage? {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        
        // Draw document icon
        let docPath = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 10, height: 14), xRadius: 1, yRadius: 1)
        NSColor.labelColor.setStroke()
        docPath.lineWidth = 1.2
        docPath.stroke()
        
        // Draw text lines
        NSColor.labelColor.setStroke()
        for y in [5.0, 8.0, 11.0] {
            let linePath = NSBezierPath()
            linePath.move(to: NSPoint(x: 4, y: y))
            linePath.line(to: NSPoint(x: 10, y: y))
            linePath.lineWidth = 1
            linePath.stroke()
        }
        
        // Draw magnifying glass
        let glassPath = NSBezierPath(ovalIn: NSRect(x: 10, y: 6, width: 6, height: 6))
        glassPath.lineWidth = 1.2
        glassPath.stroke()
        
        let handlePath = NSBezierPath()
        handlePath.move(to: NSPoint(x: 14.5, y: 7.5))
        handlePath.line(to: NSPoint(x: 17, y: 5))
        handlePath.lineWidth = 1.5
        handlePath.lineCapStyle = .round
        handlePath.stroke()
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    @objc func toggleTranslation() {
        if overlayController.isVisible {
            overlayController.hide()
        } else {
            performTranslation()
        }
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = L("about.title")
        alert.informativeText = """
        \(L("about.version")) \(AppInfo.version)
        
        \(L("about.description"))
        
        \(L("about.copyright"))
        """
        alert.alertStyle = .informational
        
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            alert.icon = icon
        } else {
            alert.icon = NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: nil)
        }
        
        alert.addButton(withTitle: L("about.ok"))
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Permission Check
    
    private func checkScreenCapturePermission() {
        let hasPermission = CGPreflightScreenCaptureAccess()
        if !hasPermission {
            CGRequestScreenCaptureAccess()
        }
    }
    
    private func showPermissionError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L("error.permission.title")
            alert.informativeText = L("error.permission.message")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("error.permission.openSettings"))
            alert.addButton(withTitle: L("error.permission.cancel"))
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func showError(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("about.ok"))
            
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    // MARK: - Translation Flow
    
    private func performTranslation() {
        guard !isProcessing else { return }
        
        guard CGPreflightScreenCaptureAccess() else {
            showPermissionError()
            return
        }
        
        isProcessing = true
        updateMenuBarIcon(processing: true)
        
        let targetLang = Settings.shared.targetLanguage
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("[*] \(L("status.capturing"))")
            
            let captureToken = PerformanceProfiler.shared.begin(.screenCapture)
            guard let screenshot = self.captureScreen() else {
                PerformanceProfiler.shared.end(captureToken)
                print("[!] \(L("status.failed.capture"))")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.updateMenuBarIcon(processing: false)
                    self.showError(title: L("status.failed.capture"), message: L("error.permission.message"))
                }
                return
            }
            captureToken?.addMetadata(key: "displayID", value: self.getSelectedScreen().deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "unknown")
            PerformanceProfiler.shared.end(captureToken)
            
            print("[*] \(L("status.ocr"))")
            let ocrResults = OCRService.shared.recognizeText(in: screenshot)
            print("[+] OCR detected \(ocrResults.count) text blocks")
            
            if ocrResults.isEmpty {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.updateMenuBarIcon(processing: false)
                    self.showError(title: L("error.ocr.empty"), message: "")
                }
                return
            }
            
            print("[*] \(L("status.translating")) -> \(Settings.shared.targetLanguageName)")
            TranslationService.shared.translate(blocks: ocrResults, to: targetLang) { [weak self] translatedResults, success in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.updateMenuBarIcon(processing: false)
                    
                    // Check if translation was cancelled (returned original blocks unchanged)
                    let wasCancelled = !success && translatedResults.count == ocrResults.count &&
                        zip(translatedResults, ocrResults).allSatisfy { $0.text == $1.text }
                    
                    if wasCancelled {
                        print("[*] Translation cancelled")
                        return
                    }
                    
                    // Save OCR results for re-translation when switching modes
                    self.lastOCRResults = ocrResults
                    self.lastTargetLanguage = targetLang
                    
                    self.overlayController.show(with: translatedResults, on: self.getSelectedScreen())
                    print("[+] \(L("status.done"))")
                    
                    if !success {
                        print("[!] Some translations failed")
                    }
                }
            }
        }
    }
    
    /// Update menu bar icon state
    private func updateMenuBarIcon(processing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem.button else { return }
            
            // Use cached icons to avoid recreating
            if processing {
                button.image = self.processingIcon
            } else {
                button.image = self.normalIcon ?? NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "Screen Translator")
            }
        }
    }
    
    // MARK: - Screen Capture
    
    private func getSelectedScreen() -> NSScreen {
        let screens = NSScreen.screens
        let index = Settings.shared.selectedDisplayIndex
        
        if index < screens.count {
            return screens[index]
        }
        return NSScreen.main ?? screens[0]
    }
    
    private func captureScreen() -> CGImage? {
        let screen = getSelectedScreen()
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return CGDisplayCreateImage(displayID)
    }
}
