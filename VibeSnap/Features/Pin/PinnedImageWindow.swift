import AppKit

/// Pinned image window that floats on top of all windows
class PinnedImageWindow: NSWindow {
    private var imageView: NSImageView?
    private var isMouseThrough = false
    private let minOpacity: CGFloat = 0.1
    private let maxOpacity: CGFloat = 1.0
    
    init(image: NSImage, frame: CGRect) {
        // Calculate window size based on image aspect ratio
        let maxSize: CGFloat = 400
        var windowSize = image.size
        
        if windowSize.width > maxSize || windowSize.height > maxSize {
            let scale = min(maxSize / windowSize.width, maxSize / windowSize.height)
            windowSize = CGSize(width: windowSize.width * scale, height: windowSize.height * scale)
        }
        
        let screenRect = NSScreen.main?.frame ?? CGRect.zero
        let windowRect = CGRect(
            x: screenRect.midX - windowSize.width / 2,
            y: screenRect.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupImageView(image: image)
        setupGestures()
    }
    
    private func setupWindow() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    private func setupImageView(image: NSImage) {
        let contentView = PinnedContentView(frame: self.frame.size)
        contentView.pinnedWindow = self
        self.contentView = contentView
        
        imageView = NSImageView(frame: NSRect(origin: .zero, size: self.frame.size))
        imageView?.image = image
        imageView?.imageScaling = .scaleProportionallyUpOrDown
        imageView?.wantsLayer = true
        imageView?.layer?.cornerRadius = 8
        imageView?.layer?.masksToBounds = true
        imageView?.autoresizingMask = [.width, .height]
        
        contentView.addSubview(imageView!)
    }
    
    private func setupGestures() {
        // Double-click to toggle mouse through
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        self.contentView?.addGestureRecognizer(doubleClickGesture)
    }
    
    func show() {
        self.alphaValue = 0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1
        }
    }
    
    @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        toggleMouseThrough()
    }
    
    func toggleMouseThrough() {
        isMouseThrough.toggle()
        self.ignoresMouseEvents = isMouseThrough
        
        // Visual feedback
        if isMouseThrough {
            self.alphaValue = 0.6
            // Show brief indicator
            showMouseThroughIndicator(enabled: true)
        } else {
            self.alphaValue = 1.0
            showMouseThroughIndicator(enabled: false)
        }
    }
    
    private func showMouseThroughIndicator(enabled: Bool) {
        // Brief visual feedback for mode change
        let indicator = NSTextField(labelWithString: enabled ? "🔓 Click Through" : "🔒 Normal")
        indicator.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        indicator.textColor = .white
        indicator.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        indicator.isBezeled = false
        indicator.drawsBackground = true
        indicator.alignment = .center
        indicator.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: 24)
        
        self.contentView?.addSubview(indicator)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            indicator.removeFromSuperview()
        }
    }
    
    func adjustOpacity(delta: CGFloat) {
        let newOpacity = max(minOpacity, min(maxOpacity, self.alphaValue + delta))
        self.alphaValue = newOpacity
    }
    
    override func close() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// Content view for pinned window that handles scroll events
class PinnedContentView: NSView {
    weak var pinnedWindow: PinnedImageWindow?
    
    init(frame size: CGSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Adjust opacity with scroll wheel
        let delta = event.deltaY * 0.02
        pinnedWindow?.adjustOpacity(delta: delta)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            pinnedWindow?.close()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(with: event)
    }
    
    private func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Toggle Click Through", action: #selector(toggleClickThrough), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Close", action: #selector(closeWindow), keyEquivalent: ""))
        
        for item in menu.items {
            item.target = self
        }
        
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    
    @objc private func toggleClickThrough() {
        pinnedWindow?.toggleMouseThrough()
    }
    
    @objc private func closeWindow() {
        pinnedWindow?.close()
    }
}
