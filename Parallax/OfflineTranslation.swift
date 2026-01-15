import Foundation
import SwiftUI
import Translation

// MARK: - Offline Translation Extension (macOS 15+)

/// Keep strong reference to active helper to prevent deallocation
@available(macOS 15.0, *)
private var activeTranslationHelper: OfflineTranslationHelper?

@available(macOS 15.0, *)
extension TranslationService {
    
    func translateOffline(blocks: [TextBlock], to targetLang: String, completion: @escaping ([TextBlock], Bool) -> Void) {
        let targetLanguage = languageFromCode(targetLang)
        let sourceLanguage = guessSourceLanguage(for: targetLang)
        
        // Check language availability first
        Task {
            let availability = LanguageAvailability()
            let status = await availability.status(from: sourceLanguage, to: targetLanguage)
            
            await MainActor.run {
                switch status {
                case .installed:
                    // Language pack ready, proceed with translation
                    self.startOfflineTranslation(
                        blocks: blocks,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        targetLangCode: targetLang,
                        completion: completion
                    )
                    
                case .supported:
                    // Language pack needs to be downloaded, show download prompt
                    self.showLanguageDownloadPrompt(
                        blocks: blocks,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        targetLangCode: targetLang,
                        completion: completion
                    )
                    
                case .unsupported:
                    // Language pair not supported, fallback to online
                    print("[!] Language pair not supported for offline translation, falling back to online")
                    self.translateOnline(blocks: blocks, to: targetLang, completion: completion)
                    
                @unknown default:
                    self.translateOnline(blocks: blocks, to: targetLang, completion: completion)
                }
            }
        }
    }
    
    func startOfflineTranslation(
        blocks: [TextBlock],
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        targetLangCode: String,
        completion: @escaping ([TextBlock], Bool) -> Void
    ) {
        DispatchQueue.main.async {
            let helper = OfflineTranslationHelper(
                blocks: blocks,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                targetLangCode: targetLangCode,
                service: self
            ) { results, success in
                activeTranslationHelper = nil
                completion(results, success)
            }
            activeTranslationHelper = helper
            helper.start()
        }
    }
    
    private func showLanguageDownloadPrompt(
        blocks: [TextBlock],
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        targetLangCode: String,
        completion: @escaping ([TextBlock], Bool) -> Void
    ) {
        // Show download UI using SwiftUI
        let helper = LanguageDownloadHelper(
            blocks: blocks,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            targetLangCode: targetLangCode,
            service: self,
            completion: completion
        )
        helper.start()
    }
    
    /// Guess source language based on target language
    private func guessSourceLanguage(for targetLang: String) -> Locale.Language {
        if targetLang == "zh" {
            return Locale.Language(identifier: "en")
        } else {
            return Locale.Language(identifier: "zh-Hans")
        }
    }
    
    func languageFromCode(_ code: String) -> Locale.Language {
        switch code {
        case "zh": return Locale.Language(identifier: "zh-Hans")
        case "en": return Locale.Language(identifier: "en")
        case "ja": return Locale.Language(identifier: "ja")
        case "ko": return Locale.Language(identifier: "ko")
        case "fr": return Locale.Language(identifier: "fr")
        case "de": return Locale.Language(identifier: "de")
        case "es": return Locale.Language(identifier: "es")
        case "ru": return Locale.Language(identifier: "ru")
        case "pt": return Locale.Language(identifier: "pt")
        case "it": return Locale.Language(identifier: "it")
        case "ar": return Locale.Language(identifier: "ar")
        case "th": return Locale.Language(identifier: "th")
        case "vi": return Locale.Language(identifier: "vi")
        default: return Locale.Language(identifier: code)
        }
    }
}

// MARK: - Language Download Helper

@available(macOS 15.0, *)
private class LanguageDownloadHelper {
    let blocks: [TextBlock]
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let targetLangCode: String
    weak var service: TranslationService?
    let completion: ([TextBlock], Bool) -> Void
    
    private var window: NSWindow?
    
    init(blocks: [TextBlock],
         sourceLanguage: Locale.Language,
         targetLanguage: Locale.Language,
         targetLangCode: String,
         service: TranslationService,
         completion: @escaping ([TextBlock], Bool) -> Void) {
        self.blocks = blocks
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.targetLangCode = targetLangCode
        self.service = service
        self.completion = completion
    }
    
    func start() {
        // Show alert to guide user to download language pack
        let alert = NSAlert()
        alert.messageText = L("offline.download.title")
        alert.informativeText = L("offline.download.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("offline.download.openSettings"))
        alert.addButton(withTitle: L("offline.download.useOnline"))
        alert.addButton(withTitle: L("offline.download.cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Open System Settings -> General -> Language & Region
            if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
            // Cancel this translation, user will retry after downloading
            completion(blocks, false)
            
        case .alertSecondButtonReturn:
            // Use online translation
            service?.translateOnline(blocks: blocks, to: targetLangCode, completion: completion)
            
        default:
            // Cancel - return original blocks
            completion(blocks, false)
        }
    }
}

// MARK: - Offline Translation Helper

@available(macOS 15.0, *)
private class OfflineTranslationHelper {
    let blocks: [TextBlock]
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let targetLangCode: String
    weak var service: TranslationService?
    let completion: ([TextBlock], Bool) -> Void
    
    private var window: NSWindow?
    
    init(blocks: [TextBlock],
         sourceLanguage: Locale.Language,
         targetLanguage: Locale.Language,
         targetLangCode: String,
         service: TranslationService,
         completion: @escaping ([TextBlock], Bool) -> Void) {
        self.blocks = blocks
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.targetLangCode = targetLangCode
        self.service = service
        self.completion = completion
    }
    
    func start() {
        let helperView = TranslationHelperView(
            blocks: blocks,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            targetLangCode: targetLangCode,
            service: service
        ) { [weak self] results, success in
            DispatchQueue.main.async {
                self?.completion(results, success)
                self?.cleanup()
            }
        }
        
        let hostingView = NSHostingView(rootView: helperView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        
        // Create off-screen window to host SwiftUI view
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)
        
        self.window = window
    }
    
    private func cleanup() {
        window?.close()
        window = nil
    }
}

// MARK: - SwiftUI Helper View

@available(macOS 15.0, *)
private struct TranslationHelperView: View {
    let blocks: [TextBlock]
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let targetLangCode: String
    weak var service: TranslationService?
    let completion: ([TextBlock], Bool) -> Void
    
    @State private var configuration: TranslationSession.Configuration?
    @State private var hasStarted = false
    
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                configuration = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
            }
            .translationTask(configuration) { session in
                await performTranslation(session: session)
            }
    }
    
    @MainActor
    private func performTranslation(session: TranslationSession) async {
        var translatedBlocks: [TextBlock] = []
        var hasError = false
        
        for block in blocks {
            let trimmedText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.isEmpty {
                translatedBlocks.append(block)
                continue
            }
            
            let cacheKey = "\(trimmedText)_\(targetLangCode)_offline"
            
            // Check cache
            if let cached = service?.getCached(key: cacheKey) {
                translatedBlocks.append(TextBlock(rect: block.rect, text: cached))
                continue
            }
            
            do {
                let response = try await session.translate(trimmedText)
                let translatedText = response.targetText
                
                service?.addToCache(key: cacheKey, value: translatedText)
                translatedBlocks.append(TextBlock(rect: block.rect, text: translatedText))
            } catch {
                print("[!] Offline translation error: \(error)")
                translatedBlocks.append(block)
                hasError = true
            }
        }
        
        completion(translatedBlocks, !hasError)
    }
}
