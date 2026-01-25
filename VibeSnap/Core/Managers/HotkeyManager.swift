import Foundation
import AppKit
import HotKey

/// Manager for registering and handling global hotkeys using HotKey library
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var captureAreaHotKey: HotKey?
    private var captureWindowHotKey: HotKey?
    private var captureFullscreenHotKey: HotKey?
    private var showHistoryHotKey: HotKey?
    
    // Callbacks for capture actions
    var onCaptureArea: (() -> Void)?
    var onCaptureWindow: (() -> Void)?
    var onCaptureFullscreen: (() -> Void)?
    var onShowHistory: (() -> Void)?
    
    private init() {}
    
    /// Register all global hotkeys
    func registerHotkeys() {
        // ⇧⌘1 - Capture Area
        captureAreaHotKey = HotKey(key: .one, modifiers: [.shift, .command])
        captureAreaHotKey?.keyDownHandler = { [weak self] in
            self?.onCaptureArea?()
        }
        
        // ⇧⌘2 - Capture Window
        captureWindowHotKey = HotKey(key: .two, modifiers: [.shift, .command])
        captureWindowHotKey?.keyDownHandler = { [weak self] in
            self?.onCaptureWindow?()
        }
        
        // ⇧⌘3 - Capture Fullscreen
        captureFullscreenHotKey = HotKey(key: .three, modifiers: [.shift, .command])
        captureFullscreenHotKey?.keyDownHandler = { [weak self] in
            self?.onCaptureFullscreen?()
        }
        
        // ⇧⌘4 - Show History
        showHistoryHotKey = HotKey(key: .four, modifiers: [.shift, .command])
        showHistoryHotKey?.keyDownHandler = { [weak self] in
            self?.onShowHistory?()
        }
    }
    
    /// Unregister all global hotkeys
    func unregisterHotkeys() {
        captureAreaHotKey = nil
        captureWindowHotKey = nil
        captureFullscreenHotKey = nil
        showHistoryHotKey = nil
    }
    
    deinit {
        unregisterHotkeys()
    }
}
