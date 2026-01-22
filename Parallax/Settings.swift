import Foundation

/// Translation mode: online (Google API) or offline (Apple Translation)
enum TranslationMode: String {
    case online = "online"
    case offline = "offline"
}

class Settings {
    static let shared = Settings()
    
    private let defaults = UserDefaults.standard
    private let targetLanguageKey = "targetLanguage"
    private let selectedDisplayKey = "selectedDisplayIndex"
    private let translationModeKey = "translationMode"
    private let useMetalAccelerationKey = "useMetalAcceleration"
    
    // Supported target languages
    static let supportedLanguages: [(code: String, name: String, localizedName: String)] = [
        ("zh", "Chinese", "中文"),
        ("en", "English", "English"),
        ("ja", "Japanese", "日本語"),
        ("ko", "Korean", "한국어"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("es", "Spanish", "Español"),
        ("ru", "Russian", "Русский"),
        ("pt", "Portuguese", "Português"),
        ("it", "Italian", "Italiano"),
        ("ar", "Arabic", "العربية"),
        ("th", "Thai", "ไทย"),
        ("vi", "Vietnamese", "Tiếng Việt")
    ]
    
    private init() {}
    
    var targetLanguage: String {
        get {
            defaults.string(forKey: targetLanguageKey) ?? "zh"
        }
        set {
            defaults.set(newValue, forKey: targetLanguageKey)
        }
    }
    
    var targetLanguageName: String {
        let lang = Settings.supportedLanguages.first { $0.code == targetLanguage }
        return lang?.localizedName ?? "中文"
    }
    
    var selectedDisplayIndex: Int {
        get {
            defaults.integer(forKey: selectedDisplayKey)
        }
        set {
            defaults.set(newValue, forKey: selectedDisplayKey)
        }
    }
    
    var translationMode: TranslationMode {
        get {
            if let rawValue = defaults.string(forKey: translationModeKey),
               let mode = TranslationMode(rawValue: rawValue) {
                return mode
            }
            return .online // Default to online mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: translationModeKey)
        }
    }
    
    var useMetalAcceleration: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: useMetalAccelerationKey) == nil {
                return true
            }
            return defaults.bool(forKey: useMetalAccelerationKey)
        }
        set {
            defaults.set(newValue, forKey: useMetalAccelerationKey)
        }
    }
}

// App info from bundle
struct AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
