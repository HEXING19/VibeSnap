import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var permissionsManager = PermissionsManager.shared
    private var hotkeyManager = HotkeyManager.shared
    private var captureManager = CaptureManager.shared
    private var clipboardManager = ClipboardManager.shared
    
    // Capture UI
    private var overlayWindows: [OverlayWindow] = []
    private var annotationToolbar: AnnotationToolbar?
    private var thumbnailOverlay: ThumbnailOverlay?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar
        statusBarController = StatusBarController()
        
        // Initialize overlay windows for each screen
        createOverlayWindows()
        annotationToolbar = AnnotationToolbar()
        thumbnailOverlay = ThumbnailOverlay()
        
        // Set up capture callbacks
        setupCaptureCallbacks()
        
        // Set up notification observers for menu actions
        setupNotificationObservers()
        
        // Check screen capture permissions on first launch
        checkPermissions()
        
        // Register global hotkeys
        setupHotkeys()
        
        // Observe screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenConfigurationChanged() {
        // Recreate overlay windows when screen configuration changes
        createOverlayWindows()
    }
    
    private func createOverlayWindows() {
        // Close existing windows
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        
        // Create a new overlay window for each screen
        for screen in NSScreen.screens {
            let overlayWindow = OverlayWindow(screen: screen)
            overlayWindows.append(overlayWindow)
        }
        
        // Set up callbacks for all windows
        setupCaptureCallbacks()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCaptureArea),
            name: .captureArea, object: nil
        )

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCaptureFullscreen),
            name: .captureFullscreen, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowHistory),
            name: .showHistory, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowSettings),
            name: .showSettings, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowClipboardHistory),
            name: .showClipboardHistory, object: nil
        )
    }
    
    @objc private func handleCaptureArea() {
        startAreaCapture()
    }
    

    
    @objc private func handleCaptureFullscreen() {
        startFullscreenCapture()
    }
    
    @objc private func handleShowHistory() {
        showHistoryPanel()
    }
    
    @objc private func handleShowSettings() {
        SettingsWindowController.shared.showSettings()
    }
    
    @objc private func handleShowClipboardHistory() {
        showClipboardHistoryPanel()
    }
    
    private func setupCaptureCallbacks() {
        for overlayWindow in overlayWindows {
            overlayWindow.onCaptureComplete = { [weak self] image, rect in
                // Close all overlay windows
                self?.closeAllOverlays()
                // Show annotation toolbar for user to choose action
                self?.showAnnotationToolbar(image: image, rect: rect)
            }
            
            overlayWindow.onCancel = { [weak self] in
                // Close all overlay windows
                self?.closeAllOverlays()
            }
        }
        
        // Setup annotation toolbar callbacks
        annotationToolbar?.onCopy = { [weak self] in
            // Image already copied in toolbar, just save to history
            if let image = self?.annotationToolbar?.capturedImage,
               let rect = self?.annotationToolbar?.capturedRect {
                HistoryManager.shared.addToHistory(image: image, rect: rect)
            }
        }
        
        annotationToolbar?.onSave = { [weak self] in
            // Image already saved in toolbar, just save to history
            if let image = self?.annotationToolbar?.capturedImage,
               let rect = self?.annotationToolbar?.capturedRect {
                HistoryManager.shared.addToHistory(image: image, rect: rect)
            }
        }
        
        

        
        annotationToolbar?.onCancel = {
            // User cancelled, do nothing
        }
    }
    
    private func closeAllOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
    }
    
    private func showAnnotationToolbar(image: NSImage, rect: CGRect) {
        annotationToolbar?.show(with: image, rect: rect)
    }
    
    private func showThumbnail(image: NSImage, rect: CGRect) {
        // Save to history
        HistoryManager.shared.addToHistory(image: image, rect: rect)
        
        thumbnailOverlay?.show(with: image, rect: rect)
    }
    
    private func checkPermissions() {
        if !permissionsManager.hasScreenCapturePermission {
            permissionsManager.requestScreenCapturePermission { granted in
                if !granted {
                    self.showPermissionAlert()
                }
            }
        }
    }
    
    private func setupHotkeys() {
        hotkeyManager.onCaptureArea = { [weak self] in
            self?.startAreaCapture()
        }

        hotkeyManager.onCaptureFullscreen = { [weak self] in
            self?.startFullscreenCapture()
        }
        hotkeyManager.onShowHistory = { [weak self] in
            self?.showHistoryPanel()
        }
        hotkeyManager.onShowClipboardHistory = { [weak self] in
            self?.showClipboardHistoryPanel()
        }
        hotkeyManager.registerHotkeys()
    }
    
    private func showHistoryPanel() {
        ScreenshotHistoryWindowController.shared.togglePanel()
    }
    
    private func showClipboardHistoryPanel() {
        ClipboardHistoryWindowController.shared.togglePanel()
    }
    
    private func startAreaCapture() {
        guard permissionsManager.hasScreenCapturePermission else {
            showPermissionAlert()
            return
        }
        overlayWindows.forEach { $0.startCapture(mode: .area) }
    }
    

    
    private func startFullscreenCapture() {
        guard permissionsManager.hasScreenCapturePermission else {
            showPermissionAlert()
            return
        }
        
        captureManager.captureFullscreen { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    let screenRect = NSScreen.main?.frame ?? .zero
                    self?.showThumbnail(image: image, rect: screenRect)
                case .failure(let error):
                    print("Capture failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "VibeSnap needs Screen Recording permission to capture screenshots. Please enable it in System Settings > Privacy & Security > Screen Recording."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
