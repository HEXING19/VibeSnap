import AppKit
import ScreenCaptureKit

/// Full-screen overlay window for screenshot capture
final class OverlayWindow: NSWindow {
    private var overlayView: OverlayView?
    var onCaptureComplete: ((NSImage, CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private(set) var targetScreen: NSScreen
    
    init(screen: NSScreen) {
        self.targetScreen = screen
        
        // Use the designated initializer without screen parameter
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow(for: screen)
        setupOverlayView(for: screen)
    }
    
    private func setupWindow(for screen: NSScreen) {
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // Set frame to exactly match the target screen
        self.setFrame(screen.frame, display: true)
    }
    
    private func setupOverlayView(for screen: NSScreen) {
        overlayView = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        overlayView?.overlayWindow = self
        overlayView?.targetScreen = screen
        self.contentView = overlayView
    }
    
    func startCapture(mode: CaptureMode) {
        overlayView?.captureMode = mode
        overlayView?.startCapture()
        self.makeKeyAndOrderFront(nil)
    }
    
    func completeCapture(image: NSImage, rect: CGRect) {
        self.orderOut(nil)
        onCaptureComplete?(image, rect)
    }
    
    func cancelCapture() {
        self.orderOut(nil)
        onCancel?()
    }
}

enum CaptureMode {
    case area
    case window
    case fullscreen
}

/// The main overlay view that handles mouse events and drawing
class OverlayView: NSView {
    weak var overlayWindow: OverlayWindow?
    var captureMode: CaptureMode = .area
    var targetScreen: NSScreen?
    
    // Selection state
    private var isSelecting = false
    private var selectionStart: CGPoint = .zero
    private var selectionRect: CGRect = .zero
    
    // Window detection
    private var detectedWindows: [SCWindow] = []
    private var hoveredWindow: SCWindow?
    private var isCommandPressed = false
    
    // Loupe view
    private var loupeView: LoupeView?
    
    // Visual constants
    private let dimmingOpacity: CGFloat = 0.15
    private let highlightColor = NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0) // Electric Blue
    private let highlightBorderWidth: CGFloat = 2.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLoupeView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLoupeView()
    }
    
    private func setupLoupeView() {
        loupeView = LoupeView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        loupeView?.isHidden = true
        if let loupe = loupeView {
            addSubview(loupe)
        }
    }
    
    func startCapture() {
        // Remove old tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // Add tracking area for mouse movement detection
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        
        // Load available windows for window detection
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.detectedWindows = content.windows.filter { 
                        $0.isOnScreen && 
                        $0.frame.width > 50 && 
                        $0.frame.height > 50 &&
                        $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                    }
                    // Sort windows by layer (front to back)
                    self.detectedWindows.sort { $0.windowLayer > $1.windowLayer }
                }
            } catch {
                print("Failed to get windows: \(error)")
            }
        }
        
        // Reset state
        isSelecting = false
        selectionRect = .zero
        hoveredWindow = nil
        
        // Start tracking
        self.window?.makeFirstResponder(self)
        self.needsDisplay = true
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw dimming overlay
        NSColor.black.withAlphaComponent(dimmingOpacity).setFill()
        bounds.fill()
        
        // Draw selection or hovered window highlight
        if captureMode == .window, let window = hoveredWindow {
            drawWindowHighlight(window)
        } else if isSelecting && selectionRect.width > 0 && selectionRect.height > 0 {
            drawSelectionRect()
        }
    }
    
    private func drawWindowHighlight(_ window: SCWindow) {
        let windowRect = convertScreenToView(window.frame)
        
        // Clear the window area (remove dimming)
        NSColor.clear.setFill()
        NSBezierPath(rect: windowRect).fill()
        
        // Draw highlight border
        highlightColor.setStroke()
        let borderPath = NSBezierPath(rect: windowRect.insetBy(dx: -1, dy: -1))
        borderPath.lineWidth = highlightBorderWidth
        borderPath.stroke()
    }
    
    private func drawSelectionRect() {
        // Clear selection area (remove dimming)
        NSColor.clear.setFill()
        NSBezierPath(rect: selectionRect).fill()
        
        // Draw border
        highlightColor.setStroke()
        let borderPath = NSBezierPath(rect: selectionRect)
        borderPath.lineWidth = highlightBorderWidth
        borderPath.stroke()
        
        // Draw size indicator
        drawSizeIndicator()
    }
    
    private func drawSizeIndicator() {
        let sizeString = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let size = sizeString.size(withAttributes: attributes)
        let textRect = CGRect(
            x: selectionRect.midX - size.width / 2 - 4,
            y: selectionRect.minY - size.height - 8,
            width: size.width + 8,
            height: size.height + 4
        )
        
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        
        sizeString.draw(at: CGPoint(x: textRect.minX + 4, y: textRect.minY + 2), withAttributes: attributes)
    }
    
    private func convertScreenToView(_ screenRect: CGRect) -> CGRect {
        // SCWindow.frame uses screen coordinates where (0,0) is bottom-left of main screen
        // NSView uses coordinates relative to its window where (0,0) is bottom-left
        
        guard let screen = targetScreen else { return screenRect }
        
        // Convert from global screen coordinates to screen-relative coordinates
        let viewX = screenRect.origin.x - screen.frame.origin.x
        let viewY = screenRect.origin.y - screen.frame.origin.y
        
        return CGRect(x: viewX, y: viewY, width: screenRect.width, height: screenRect.height)
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if captureMode == .window, let window = hoveredWindow {
            // Capture the hovered window
            captureWindow(window)
        } else {
            // Start area selection
            isSelecting = true
            selectionStart = location
            selectionRect = CGRect(origin: location, size: .zero)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isSelecting else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        
        // Calculate selection rect
        let minX = min(selectionStart.x, location.x)
        let minY = min(selectionStart.y, location.y)
        let width = abs(location.x - selectionStart.x)
        let height = abs(location.y - selectionStart.y)
        
        selectionRect = CGRect(x: minX, y: minY, width: width, height: height)
        
        // Update loupe position
        updateLoupePosition(at: location)
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isSelecting else { return }
        isSelecting = false
        loupeView?.isHidden = true
        
        if selectionRect.width > 10 && selectionRect.height > 10 {
            captureArea(selectionRect)
        } else {
            needsDisplay = true
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if captureMode == .window {
            updateHoveredWindow(at: location)
        }
        
        updateLoupePosition(at: location)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            overlayWindow?.cancelCapture()
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        isCommandPressed = event.modifierFlags.contains(.command)
        if captureMode == .window {
            // Re-calculate hovered window with new modifier state
            let location = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            updateHoveredWindow(at: location)
        }
    }
    
    // MARK: - Window Detection
    
    private func updateHoveredWindow(at point: CGPoint) {
        let screenPoint = convertViewToScreen(point)
        
        // Find window under cursor
        var newHoveredWindow: SCWindow?
        
        if isCommandPressed {
            // Layer penetration: skip top window
            let windowsUnderCursor = detectedWindows.filter { $0.frame.contains(screenPoint) }
            if windowsUnderCursor.count > 1 {
                newHoveredWindow = windowsUnderCursor[1] // Get second window
            }
        } else {
            newHoveredWindow = detectedWindows.first { $0.frame.contains(screenPoint) }
        }
        
        if newHoveredWindow?.windowID != hoveredWindow?.windowID {
            hoveredWindow = newHoveredWindow
            needsDisplay = true
        }
    }
    
    private func convertViewToScreen(_ point: CGPoint) -> CGPoint {
        // Convert view coordinates back to screen coordinates
        guard let screen = targetScreen else { return point }
        
        let screenX = point.x + screen.frame.origin.x
        let screenY = point.y + screen.frame.origin.y
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    // MARK: - Loupe
    
    private func updateLoupePosition(at point: CGPoint) {
        guard let loupe = loupeView else { return }
        
        loupe.isHidden = false
        loupe.frame.origin = CGPoint(
            x: point.x + 20,
            y: point.y + 20
        )
        loupe.updateMagnification(at: point)
    }
    
    // MARK: - Capture Actions
    
    private func captureArea(_ rect: CGRect) {
        let screenRect = convertViewToScreenRect(rect)
        
        // Hide overlay to provide visual feedback
        overlayWindow?.orderOut(nil)
        
        CaptureManager.shared.captureArea(rect: screenRect) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self?.overlayWindow?.completeCapture(image: image, rect: screenRect)
                case .failure(let error):
                    print("Capture failed: \(error)")
                    self?.overlayWindow?.cancelCapture()
                }
            }
        }
    }
    
    private func captureWindow(_ window: SCWindow) {
        // Hide overlay to provide visual feedback
        overlayWindow?.orderOut(nil)
        
        CaptureManager.shared.captureWindow(window: window) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self?.overlayWindow?.completeCapture(image: image, rect: window.frame)
                case .failure(let error):
                    print("Capture failed: \(error)")
                    self?.overlayWindow?.cancelCapture()
                }
            }
        }
    }
    
    private func convertViewToScreenRect(_ rect: CGRect) -> CGRect {
        // Convert view coordinates to NSScreen coordinates
        // The NSScreen to SCDisplay conversion will be done in CaptureManager
        guard let screen = targetScreen else { return rect }
        
        // View coordinates are relative to the window (which matches the screen)
        // NSScreen coordinates are global
        // Both use bottom-left origin with Y increasing upward
        
        let nsScreenX = rect.origin.x + screen.frame.origin.x
        let nsScreenY = rect.origin.y + screen.frame.origin.y
        
        return CGRect(
            x: nsScreenX,
            y: nsScreenY,
            width: max(1, rect.width),
            height: max(1, rect.height)
        )
    }
}
