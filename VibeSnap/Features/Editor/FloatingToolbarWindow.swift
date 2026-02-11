import AppKit

/// Floating toolbar window with macOS-style glassmorphism
class FloatingToolbarWindow: NSPanel {
    private var toolsView: AnnotationToolsView?
    
    var onToolSelected: ((AnnotationTool) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?
    
    init() {
        // Calculate size based on content
        let toolbarWidth: CGFloat = 720  // Wide enough for 10 tools + controls + action buttons
        let toolbarHeight: CGFloat = 48
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: toolbarWidth, height: toolbarHeight),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        // Window properties
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        
        // Create visual effect view for glassmorphism
        let visualEffect = NSVisualEffectView(frame: contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        
        // Add subtle border
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor(white: 0.0, alpha: 0.1).cgColor
        
        contentView?.addSubview(visualEffect)
        
        // Create tools view
        toolsView = AnnotationToolsView(frame: visualEffect.bounds)
        toolsView?.autoresizingMask = [.width, .height]
        toolsView?.onToolSelected = { [weak self] tool in
            self?.onToolSelected?(tool)
        }
        toolsView?.onColorChanged = { [weak self] color in
            self?.onColorChanged?(color)
        }
        toolsView?.onUndo = { [weak self] in
            self?.onUndo?()
        }
        toolsView?.onRedo = { [weak self] in
            self?.onRedo?()
        }
        toolsView?.onCopy = { [weak self] in
            self?.onCopy?()
        }
        toolsView?.onSave = { [weak self] in
            self?.onSave?()
        }
        toolsView?.onDone = { [weak self] in
            self?.onDone?()
        }
        toolsView?.onCancel = { [weak self] in
            self?.onCancel?()
        }
        
        visualEffect.addSubview(toolsView!)
    }
    
    func selectTool(_ tool: AnnotationTool) {
        toolsView?.selectTool(tool)
    }
    
    func positionRelativeTo(window: NSWindow, offset: CGPoint = CGPoint(x: 0, y: 60)) {
        let windowFrame = window.frame
        let x = windowFrame.midX - self.frame.width / 2 + offset.x
        // Position above the main window
        let y = windowFrame.maxY + offset.y
        
        self.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

/// Annotation tools view content (without window chrome)
class AnnotationToolsView: NSView {
    var onToolSelected: ((AnnotationTool) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?
    
    private var toolButtons: [NSButton] = []
    private var selectedToolIndex: Int = 0
    private var colorWell: NSColorWell?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        let padding: CGFloat = 12
        let buttonSize: CGFloat = 28
        let spacing: CGFloat = 8
        var currentX = padding
        
        // Tool definitions matching reference image
        let tools: [(AnnotationTool, String)] = [
            (.rectangle, "rectangle"),
            (.ellipse, "circle"),
            (.line, "line.diagonal"),
            (.arrow, "arrow.up.right"),
            (.freehand, "scribble.variable"),
            (.callout, "text.bubble"),
            (.text, "textformat"),
            (.number, "1.circle"),
            (.mosaic, "checkerboard.rectangle"),
            (.magnifier, "magnifyingglass")
        ]
        
        // Create tool buttons
        for (_, (tool, icon)) in tools.enumerated() {
            let button = createToolButton(
                icon: icon,
                tag: tool.rawValue,
                frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize)
            )
            button.target = self
            button.action = #selector(toolButtonClicked(_:))
            addSubview(button)
            toolButtons.append(button)
            currentX += buttonSize + spacing
        }
        
        // Add separator
        currentX += 4
        let separator = NSBox(frame: NSRect(x: currentX, y: 8, width: 1, height: frame.height - 16))
        separator.boxType = .separator
        addSubview(separator)
        currentX += 9
        
        // Color well
        let colorWell = NSColorWell(frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize))
        colorWell.color = .systemRed
        colorWell.isBordered = false
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        addSubview(colorWell)
        self.colorWell = colorWell
        currentX += buttonSize + spacing
        
        // Undo button
        let undoButton = createToolButton(
            icon: "arrow.uturn.backward",
            tag: -1,
            frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize)
        )
        undoButton.target = self
        undoButton.action = #selector(undoClicked)
        addSubview(undoButton)
        currentX += buttonSize + 4
        
        // Redo button
        let redoButton = createToolButton(
            icon: "arrow.uturn.forward",
            tag: -2,
            frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize)
        )
        redoButton.target = self
        redoButton.action = #selector(redoClicked)
        addSubview(redoButton)
        currentX += buttonSize + 4
        
        // Add separator before action buttons
        currentX += 4
        let separator2 = NSBox(frame: NSRect(x: currentX, y: 8, width: 1, height: frame.height - 16))
        separator2.boxType = .separator
        addSubview(separator2)
        currentX += 9
        
        // Action buttons: Copy, Save, Done, Cancel (icon-only)
        let actionButtons: [(String, String, Int)] = [
            ("doc.on.doc", "Copy", -10),
            ("square.and.arrow.down", "Save", -11),
            ("checkmark.circle", "Done", -12),
            ("xmark.circle", "Cancel", -13)
        ]
        
        for (icon, tooltip, tag) in actionButtons {
            let actionBtn = createToolButton(
                icon: icon,
                tag: tag,
                frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize)
            )
            actionBtn.target = self
            actionBtn.action = #selector(actionButtonClicked(_:))
            actionBtn.toolTip = tooltip
            addSubview(actionBtn)
            currentX += buttonSize + spacing
        }
        
        // Select first tool by default
        selectTool(.rectangle)
    }
    
    private func createToolButton(icon: String, tag: Int, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        button.tag = tag
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        
        // Hover effect
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
        
        return button
    }
    
    @objc private func toolButtonClicked(_ sender: NSButton) {
        guard let tool = AnnotationTool(rawValue: sender.tag) else { return }
        selectTool(tool)
        onToolSelected?(tool)
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
    }
    
    @objc private func undoClicked() {
        onUndo?()
    }
    
    @objc private func redoClicked() {
        onRedo?()
    }
    
    @objc private func actionButtonClicked(_ sender: NSButton) {
        switch sender.tag {
        case -10: onCopy?()
        case -11: onSave?()
        case -12: onDone?()
        case -13: onCancel?()
        default: break
        }
    }
    
    func selectTool(_ tool: AnnotationTool) {
        // Deselect all buttons
        for button in toolButtons {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        }
        
        // Select the clicked button
        if let index = toolButtons.firstIndex(where: { $0.tag == tool.rawValue }) {
            let button = toolButtons[index]
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            button.contentTintColor = .controlAccentColor
            selectedToolIndex = index
        }
    }
}
