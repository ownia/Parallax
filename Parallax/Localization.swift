import Foundation

/// Localization helper function
func L(_ key: String) -> String {
    let preferredLanguage = Locale.preferredLanguages.first ?? "en"
    let isChineseSimplified = preferredLanguage.hasPrefix("zh-Hans") || preferredLanguage.hasPrefix("zh-CN")
    
    let strings: [String: [String: String]] = [
        "menu.translate": ["en": "Translate Screen (⌃⇧T)", "zh": "翻译屏幕 (⌃⇧T)"],
        "menu.targetLanguage": ["en": "Target Language", "zh": "目标语言"],
        "menu.translationMode": ["en": "Translation Mode", "zh": "翻译模式"],
        "menu.mode.online": ["en": "Online (API)", "zh": "在线 (API)"],
        "menu.mode.offline": ["en": "Offline (Apple)", "zh": "离线 (Apple)"],
        "menu.selectDisplay": ["en": "Select Display", "zh": "选择显示器"],
        "menu.about": ["en": "About", "zh": "关于"],
        "menu.quit": ["en": "Quit", "zh": "退出"],
        
        "about.title": ["en": "Parallax", "zh": "Parallax"],
        "about.version": ["en": "Version:", "zh": "版本:"],
        "about.description": [
            "en": "Native macOS screen translation app\n\nFeatures:\n• OCR using Apple Vision\n• Auto translate to target language\n• Global hotkey Ctrl+Shift+T\n• Multi-display support",
            "zh": "macOS 原生屏幕翻译应用\n\n功能:\n• 使用 Apple Vision 进行 OCR 识别\n• 自动翻译为目标语言\n• 全局快捷键 Ctrl+Shift+T\n• 多显示器支持"
        ],
        "about.copyright": ["en": "© 2026 Parallax", "zh": "© 2026 Parallax"],
        "about.ok": ["en": "OK", "zh": "确定"],
        
        "status.ready": ["en": "Ready. Press Ctrl+Shift+T to translate", "zh": "就绪，按 Ctrl+Shift+T 触发翻译"],
        "status.capturing": ["en": "Capturing screen...", "zh": "正在截取屏幕..."],
        "status.ocr": ["en": "Running OCR...", "zh": "正在进行 OCR..."],
        "status.translating": ["en": "Translating...", "zh": "正在翻译..."],
        "status.done": ["en": "Translation complete", "zh": "翻译完成"],
        "status.failed.capture": ["en": "Screen capture failed", "zh": "截屏失败"],
        "status.failed.permission": ["en": "Screen recording permission required", "zh": "需要屏幕录制权限"],
        
        "error.permission.title": ["en": "Permission Required", "zh": "需要权限"],
        "error.permission.message": [
            "en": "Parallax needs screen recording permission to capture screen content.\n\nPlease go to System Settings → Privacy & Security → Screen Recording and enable Parallax.",
            "zh": "Parallax 需要屏幕录制权限来截取屏幕内容。\n\n请前往「系统设置 → 隐私与安全性 → 屏幕录制」并启用 Parallax。"
        ],
        "error.permission.openSettings": ["en": "Open Settings", "zh": "打开设置"],
        "error.permission.cancel": ["en": "Cancel", "zh": "取消"],
        
        "error.translation.title": ["en": "Translation Warning", "zh": "翻译警告"],
        "error.translation.message": ["en": "Some text could not be translated. Please check your network connection.", "zh": "部分文本翻译失败，请检查网络连接。"],
        "error.ocr.empty": ["en": "No text detected on screen", "zh": "未检测到屏幕上的文字"],
        
        "offline.download.title": ["en": "Download Language Pack", "zh": "下载语言包"],
        "offline.download.message": ["en": "The language pack for offline translation is not installed.\n\nPlease go to System Settings → General → Language & Region → Translation Languages to download.", "zh": "离线翻译所需的语言包尚未安装。\n\n请前往「系统设置 → 通用 → 语言与地区 → 翻译语言」下载。"],
        "offline.download.openSettings": ["en": "Open Settings", "zh": "打开设置"],
        "offline.download.useOnline": ["en": "Use Online", "zh": "使用在线翻译"],
        "offline.download.cancel": ["en": "Cancel", "zh": "取消"]
    ]
    
    let lang = isChineseSimplified ? "zh" : "en"
    return strings[key]?[lang] ?? strings[key]?["en"] ?? key
}
