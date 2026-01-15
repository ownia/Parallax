import AppKit
import Carbon.HIToolbox

/// Global hotkey manager
class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?
    
    private init() {}
    
    deinit {
        unregister()
    }
    
    /// Register a global hotkey
    /// - Parameters:
    ///   - keyCode: Key code
    ///   - modifiers: Modifier keys
    ///   - callback: Callback when hotkey is triggered
    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback
        
        // Hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5354_5254) // "STRT"
        hotKeyID.id = 1
        
        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.callback?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        guard status == noErr else {
            print("[!] Failed to install event handler: \(status)")
            return
        }
        
        // Register hotkey
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            print("[!] Failed to register hotkey: \(registerStatus)")
        }
    }
    
    /// Register Ctrl+Shift+T hotkey
    func registerCtrlShiftT(callback: @escaping () -> Void) {
        let modifiers = UInt32(controlKey | shiftKey)
        let keyCode: UInt32 = 17 // T key
        register(keyCode: keyCode, modifiers: modifiers, callback: callback)
    }
    
    /// Unregister hotkey
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        callback = nil
    }
}
