import Foundation
import AppKit
import HotKey

/// Manager for registering and handling global hotkeys using HotKey library
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var captureAreaHotKey: HotKey?
    private var captureFullscreenHotKey: HotKey?
    private var showHistoryHotKey: HotKey?
    private var showClipboardHistoryHotKey: HotKey?
    
    // Callbacks for capture actions
    var onCaptureArea: (() -> Void)?
    var onCaptureFullscreen: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onShowClipboardHistory: (() -> Void)?
    
    // UserDefaults keys for custom shortcuts
    static let captureAreaKeyCode = "shortcut_captureArea_keyCode"
    static let captureAreaModifiers = "shortcut_captureArea_modifiers"
    static let captureFullscreenKeyCode = "shortcut_captureFullscreen_keyCode"
    static let captureFullscreenModifiers = "shortcut_captureFullscreen_modifiers"
    static let showHistoryKeyCode = "shortcut_showHistory_keyCode"
    static let showHistoryModifiers = "shortcut_showHistory_modifiers"
    static let showClipboardHistoryKeyCode = "shortcut_clipboardHistory_keyCode"
    static let showClipboardHistoryModifiers = "shortcut_clipboardHistory_modifiers"
    
    /// Default shortcuts
    struct ShortcutDefault {
        let keyString: String
        let modifierRawValue: UInt
        
        var key: Key? { Key(string: keyString) }
        var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierRawValue) }
    }
    
    static let defaults: [String: ShortcutDefault] = [
        "captureArea": ShortcutDefault(keyString: "1", modifierRawValue: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        "captureFullscreen": ShortcutDefault(keyString: "3", modifierRawValue: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        "showHistory": ShortcutDefault(keyString: "4", modifierRawValue: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        "clipboardHistory": ShortcutDefault(keyString: "v", modifierRawValue: NSEvent.ModifierFlags([.shift, .command]).rawValue),
    ]
    
    private init() {}
    
    /// Get saved key for an action, falling back to default
    func getKey(for action: String) -> Key? {
        let keyCodeKey = "shortcut_\(action)_keyCode"
        if let saved = UserDefaults.standard.string(forKey: keyCodeKey) {
            return Key(string: saved)
        }
        return Self.defaults[action]?.key
    }
    
    /// Get saved modifiers for an action, falling back to default
    func getModifiers(for action: String) -> NSEvent.ModifierFlags {
        let modKey = "shortcut_\(action)_modifiers"
        let saved = UserDefaults.standard.object(forKey: modKey)
        if let rawValue = saved as? UInt {
            return NSEvent.ModifierFlags(rawValue: rawValue)
        }
        return Self.defaults[action]?.modifiers ?? [.shift, .command]
    }
    
    /// Save a custom shortcut
    func saveShortcut(action: String, keyString: String, modifiers: NSEvent.ModifierFlags) {
        UserDefaults.standard.set(keyString, forKey: "shortcut_\(action)_keyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "shortcut_\(action)_modifiers")
        // Re-register all hotkeys
        registerHotkeys()
    }
    
    /// Get display string for a shortcut
    func shortcutDisplayString(for action: String) -> String {
        let modifiers = getModifiers(for: action)
        let key = getKey(for: action)
        
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if let key = key {
            parts.append(key.description)
        }
        return parts.joined()
    }
    
    /// Register all global hotkeys
    func registerHotkeys() {
        // Unregister existing
        unregisterHotkeys()
        
        // Capture Area
        if let key = getKey(for: "captureArea") {
            let mods = getModifiers(for: "captureArea")
            captureAreaHotKey = HotKey(key: key, modifiers: mods)
            captureAreaHotKey?.keyDownHandler = { [weak self] in
                self?.onCaptureArea?()
            }
        }
        
        // Capture Fullscreen
        if let key = getKey(for: "captureFullscreen") {
            let mods = getModifiers(for: "captureFullscreen")
            captureFullscreenHotKey = HotKey(key: key, modifiers: mods)
            captureFullscreenHotKey?.keyDownHandler = { [weak self] in
                self?.onCaptureFullscreen?()
            }
        }
        
        // Show History
        if let key = getKey(for: "showHistory") {
            let mods = getModifiers(for: "showHistory")
            showHistoryHotKey = HotKey(key: key, modifiers: mods)
            showHistoryHotKey?.keyDownHandler = { [weak self] in
                self?.onShowHistory?()
            }
        }
        
        // Show Clipboard History
        if let key = getKey(for: "clipboardHistory") {
            let mods = getModifiers(for: "clipboardHistory")
            showClipboardHistoryHotKey = HotKey(key: key, modifiers: mods)
            showClipboardHistoryHotKey?.keyDownHandler = { [weak self] in
                self?.onShowClipboardHistory?()
            }
        }
    }
    
    /// Unregister all global hotkeys
    func unregisterHotkeys() {
        captureAreaHotKey = nil
        captureFullscreenHotKey = nil
        showHistoryHotKey = nil
        showClipboardHistoryHotKey = nil
    }
    
    deinit {
        unregisterHotkeys()
    }
}
