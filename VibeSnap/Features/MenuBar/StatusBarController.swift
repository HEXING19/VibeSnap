import AppKit
import SwiftUI

// Notification names for capture actions
extension Notification.Name {
    static let captureArea = Notification.Name("com.vibesnap.captureArea")
    static let captureWindow = Notification.Name("com.vibesnap.captureWindow")
    static let captureFullscreen = Notification.Name("com.vibesnap.captureFullscreen")
    static let showHistory = Notification.Name("com.vibesnap.showHistory")
    static let showSettings = Notification.Name("com.vibesnap.showSettings")
}

/// Controller for the menu bar status item
class StatusBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the viewfinder icon
            // Load custom icon from Resources
            if let imagePath = Bundle.module.path(forResource: "MenuBarIcon", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                image.size = NSSize(width: 18, height: 18) // Standard menu bar icon size
                image.isTemplate = false
                button.image = image
            } else if let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "VibeSnap") {
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Capture Area
        let captureAreaItem = NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: "1")
        captureAreaItem.keyEquivalentModifierMask = [.shift, .command]
        captureAreaItem.target = self
        menu.addItem(captureAreaItem)
        
        // Capture Window
        let captureWindowItem = NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "2")
        captureWindowItem.keyEquivalentModifierMask = [.shift, .command]
        captureWindowItem.target = self
        menu.addItem(captureWindowItem)
        
        // Capture Fullscreen
        let captureFullscreenItem = NSMenuItem(title: "Capture Fullscreen", action: #selector(captureFullscreen), keyEquivalent: "3")
        captureFullscreenItem.keyEquivalentModifierMask = [.shift, .command]
        captureFullscreenItem.target = self
        menu.addItem(captureFullscreenItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // History
        let historyItem = NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: "4")
        historyItem.keyEquivalentModifierMask = [.shift, .command]
        historyItem.target = self
        menu.addItem(historyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit VibeSnap", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // Menu is automatically shown due to statusItem?.menu being set
    }
    
    @objc private func captureArea() {
        NotificationCenter.default.post(name: .captureArea, object: nil)
    }
    
    @objc private func captureWindow() {
        NotificationCenter.default.post(name: .captureWindow, object: nil)
    }
    
    @objc private func captureFullscreen() {
        NotificationCenter.default.post(name: .captureFullscreen, object: nil)
    }
    
    @objc private func showHistory() {
        NotificationCenter.default.post(name: .showHistory, object: nil)
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

