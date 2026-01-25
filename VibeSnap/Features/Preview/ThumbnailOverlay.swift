import AppKit
import SwiftUI

/// Floating thumbnail overlay that appears after screenshot capture
class ThumbnailOverlay: NSWindow {
    private var thumbnailView: ThumbnailContentView?
    private var autoHideTimer: Timer?
    private let autoHideDuration: TimeInterval = 5.0
    
    var capturedImage: NSImage?
    var capturedRect: CGRect = .zero
    
    // Callbacks
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onEdit: (() -> Void)?
    var onClose: (() -> Void)?
    var onDragComplete: (() -> Void)?
    
    init() {
        let thumbnailSize = CGSize(width: 240, height: 180)
        let screenRect = NSScreen.main?.visibleFrame ?? CGRect.zero
        let windowRect = CGRect(
            x: screenRect.maxX - thumbnailSize.width - 20,
            y: screenRect.minY + 20,
            width: thumbnailSize.width,
            height: thumbnailSize.height
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContentView()
    }
    
    private func setupWindow() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
    }
    
    private func setupContentView() {
        thumbnailView = ThumbnailContentView(frame: self.frame, overlay: self)
        self.contentView = thumbnailView
    }
    
    func show(with image: NSImage, rect: CGRect) {
        capturedImage = image
        capturedRect = rect
        thumbnailView?.updateImage(image)
        
        // Animate in
        self.alphaValue = 0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
        
        startAutoHideTimer()
    }
    
    func hide() {
        stopAutoHideTimer()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
    
    private func startAutoHideTimer() {
        stopAutoHideTimer()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDuration, repeats: false) { [weak self] _ in
            self?.autoSaveAndHide()
        }
    }
    
    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    private func autoSaveAndHide() {
        // Save to default location silently
        saveToDefaultLocation()
        hide()
    }
    
    func copyToClipboard() {
        guard let image = capturedImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        hide()
        onCopy?()
    }
    
    func saveToDefaultLocation() {
        guard let image = capturedImage else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "VibeSnap_\(dateFormatter.string(from: Date())).png"
        
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }
        
        onSave?()
    }
    
    func saveAs() {
        guard let image = capturedImage else { return }
        stopAutoHideTimer()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "screenshot.png"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
            self?.hide()
        }
    }
    
    func pin() {
        guard let image = capturedImage else { return }
        stopAutoHideTimer()
        hide()
        onPin?()
        
        // Create pinned window
        DispatchQueue.main.async {
            let pinnedWindow = PinnedImageWindow(image: image, frame: self.capturedRect)
            pinnedWindow.show()
        }
    }
    
    func edit() {
        guard let image = capturedImage else { return }
        stopAutoHideTimer()
        hide()
        onEdit?()
        
        // Open editor window
        DispatchQueue.main.async {
            let editorWindow = EditorWindow(image: image)
            editorWindow.onSave = { [weak self] editedImage in
                // Show new thumbnail with edited image
                self?.capturedImage = editedImage
                self?.show(with: editedImage, rect: self?.capturedRect ?? .zero)
            }
            editorWindow.show()
        }
    }
    
    override func close() {
        stopAutoHideTimer()
        hide()
        onClose?()
    }
    
    // Reset timer when user interacts
    func resetTimer() {
        startAutoHideTimer()
    }
}

/// The visual content view for the thumbnail overlay
class ThumbnailContentView: NSView {
    weak var overlay: ThumbnailOverlay?
    private var imageView: NSImageView?
    private var buttonsView: NSView?
    private var isHovering = false
    
    init(frame frameRect: NSRect, overlay: ThumbnailOverlay) {
        self.overlay = overlay
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        
        // Glassmorphism effect
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)
        
        // Image view
        imageView = NSImageView(frame: bounds.insetBy(dx: 8, dy: 8))
        imageView?.imageScaling = .scaleProportionallyUpOrDown
        imageView?.autoresizingMask = [.width, .height]
        addSubview(imageView!)
        
        // Buttons container (hidden by default)
        setupButtonsView()
        
        // Track mouse for hover
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        
        // Enable dragging
        registerForDraggedTypes([.png, .fileURL])
    }
    
    private func setupButtonsView() {
        buttonsView = NSView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: 40))
        buttonsView?.wantsLayer = true
        buttonsView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        buttonsView?.isHidden = true
        buttonsView?.autoresizingMask = [.width]
        
        let buttonTitles = ["Copy", "Save", "Pin", "Edit", "✕"]
        let buttonWidth: CGFloat = bounds.width / CGFloat(buttonTitles.count)
        
        for (index, title) in buttonTitles.enumerated() {
            let button = NSButton(frame: CGRect(x: CGFloat(index) * buttonWidth, y: 0, width: buttonWidth, height: 40))
            button.title = title
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.contentTintColor = .white
            button.tag = index
            button.target = self
            button.action = #selector(buttonClicked(_:))
            buttonsView?.addSubview(button)
        }
        
        addSubview(buttonsView!)
    }
    
    @objc private func buttonClicked(_ sender: NSButton) {
        overlay?.resetTimer()
        
        switch sender.tag {
        case 0: overlay?.copyToClipboard()
        case 1: overlay?.saveAs()
        case 2: overlay?.pin()
        case 3: overlay?.edit()
        case 4: overlay?.close()
        default: break
        }
    }
    
    func updateImage(_ image: NSImage) {
        imageView?.image = image
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        buttonsView?.isHidden = false
        overlay?.resetTimer()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        buttonsView?.isHidden = true
    }
    
    // MARK: - Drag and Drop
    
    override func mouseDown(with event: NSEvent) {
        guard let image = overlay?.capturedImage else { return }
        
        // Start drag operation
        let draggingItem = NSDraggingItem(pasteboardWriter: image)
        draggingItem.setDraggingFrame(bounds, contents: image)
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}

extension ThumbnailContentView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            overlay?.hide()
            overlay?.onDragComplete?()
        }
    }
}
