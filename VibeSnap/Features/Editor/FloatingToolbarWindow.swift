import AppKit

/// Color grid view shown inside the popover
class ColorGridView: NSView {
    var onColorSelected: ((NSColor) -> Void)?
    
    private let colors: [NSColor] = [
        // Row 1 - Reds/Pinks
        .systemRed, .systemPink, NSColor(red: 1, green: 0.2, blue: 0.6, alpha: 1),
        NSColor(red: 0.8, green: 0, blue: 0.2, alpha: 1),
        NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1),
        NSColor(red: 0.6, green: 0, blue: 0.2, alpha: 1),
        // Row 2 - Oranges/Yellows
        .systemOrange, .systemYellow,
        NSColor(red: 1, green: 0.6, blue: 0, alpha: 1),
        NSColor(red: 1, green: 0.8, blue: 0, alpha: 1),
        NSColor(red: 0.8, green: 0.6, blue: 0, alpha: 1),
        NSColor(red: 1, green: 0.5, blue: 0.2, alpha: 1),
        // Row 3 - Greens
        .systemGreen, .systemMint,
        NSColor(red: 0, green: 0.7, blue: 0.3, alpha: 1),
        NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1),
        NSColor(red: 0, green: 0.5, blue: 0.2, alpha: 1),
        NSColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1),
        // Row 4 - Blues/Purples
        .systemBlue, .systemIndigo, .systemPurple,
        NSColor(red: 0, green: 0.5, blue: 1, alpha: 1),
        NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1),
        NSColor(red: 0.6, green: 0.4, blue: 1, alpha: 1),
        // Row 5 - Neutrals
        .black, NSColor(white: 0.2, alpha: 1), NSColor(white: 0.4, alpha: 1),
        NSColor(white: 0.6, alpha: 1), NSColor(white: 0.8, alpha: 1), .white
    ]
    
    private let cols = 6
    private let cellSize: CGFloat = 28
    private let padding: CGFloat = 8
    private let spacing: CGFloat = 4
    
    override var intrinsicContentSize: NSSize {
        let rows = CGFloat((colors.count + cols - 1) / cols)
        let w = padding * 2 + CGFloat(cols) * cellSize + CGFloat(cols - 1) * spacing
        let h = padding * 2 + rows * cellSize + (rows - 1) * spacing
        return NSSize(width: w, height: h)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for (i, color) in colors.enumerated() {
            let rect = rectFor(index: i)
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            color.setFill()
            path.fill()
            NSColor(white: 0, alpha: 0.15).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }
    }
    
    private func rectFor(index: Int) -> NSRect {
        let col = CGFloat(index % cols)
        let row = CGFloat(index / cols)
        let rows = CGFloat((colors.count + cols - 1) / cols)
        // Flip row so row 0 is at top
        let flippedRow = rows - 1 - row
        return NSRect(
            x: padding + col * (cellSize + spacing),
            y: padding + flippedRow * (cellSize + spacing),
            width: cellSize,
            height: cellSize
        )
    }
    
    // Allow first-click activation so color selection works immediately
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for (i, _) in colors.enumerated() {
            if rectFor(index: i).contains(loc) {
                onColorSelected?(colors[i])
                return
            }
        }
    }
}

/// Custom color button that shows an NSPopover color grid attached to the button
class ColorPickerButton: NSButton {
    var currentColor: NSColor = .systemRed {
        didSet { needsDisplay = true }
    }
    var onColorChanged: ((NSColor) -> Void)?
    
    private var popover: NSPopover?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    // Allow first-click activation so color button works on non-key panels
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    private func setupButton() {
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 6
        self.toolTip = "选择颜色"
        self.target = self
        self.action = #selector(buttonClicked)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw color circle
        let inset: CGFloat = 4
        let colorRect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(ovalIn: colorRect)
        currentColor.setFill()
        path.fill()
        
        // Draw border
        NSColor(white: 0.0, alpha: 0.3).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
    
    @objc private func buttonClicked() {
        if let existing = popover, existing.isShown {
            existing.close()
            self.popover = nil
            return
        }
        
        let gridView = ColorGridView(frame: .zero)
        gridView.frame = NSRect(origin: .zero, size: gridView.intrinsicContentSize)
        gridView.onColorSelected = { [weak self] color in
            guard let self = self else { return }
            self.currentColor = color
            self.onColorChanged?(color)
            self.popover?.close()
            self.popover = nil
        }
        
        let vc = NSViewController()
        vc.view = gridView
        
        let pop = NSPopover()
        pop.contentViewController = vc
        pop.contentSize = gridView.intrinsicContentSize
        pop.behavior = .semitransient
        pop.animates = true
        self.popover = pop
        
        pop.show(relativeTo: self.bounds, of: self, preferredEdge: .minY)
    }
    
    deinit {
        popover?.close()
    }
}

/// Arrow direction for the callout background
enum CalloutArrowDirection {
    case down  // Arrow points downward (toolbar above canvas)
    case up    // Arrow points upward (toolbar below canvas)
}

/// Custom view that draws a callout-shaped background (rounded rect + triangular arrow)
class CalloutBackgroundView: NSView {
    var arrowDirection: CalloutArrowDirection = .down {
        didSet { needsDisplay = true; updateMask() }
    }
    
    private let cornerRadius: CGFloat = 12
    private let arrowWidth: CGFloat = 16
    private let arrowHeight: CGFloat = 8
    
    /// The rect area excluding the arrow (where content should be placed)
    var contentRect: NSRect {
        switch arrowDirection {
        case .down:
            return NSRect(x: 0, y: arrowHeight, width: bounds.width, height: bounds.height - arrowHeight)
        case .up:
            return NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - arrowHeight)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    private func calloutPath() -> NSBezierPath {
        let rect = contentRect
        let path = NSBezierPath()
        let midX = bounds.midX
        let halfArrow = arrowWidth / 2
        
        switch arrowDirection {
        case .down:
            // Start at bottom-left of rounded rect, go clockwise
            path.move(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            
            // Bottom edge → arrow
            path.line(to: NSPoint(x: midX - halfArrow, y: rect.minY))
            path.line(to: NSPoint(x: midX, y: 0))  // Arrow tip
            path.line(to: NSPoint(x: midX + halfArrow, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            
            // Bottom-right corner
            path.appendArc(withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                          radius: cornerRadius, startAngle: 270, endAngle: 0)
            // Right edge
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            // Top-right corner
            path.appendArc(withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                          radius: cornerRadius, startAngle: 0, endAngle: 90)
            // Top edge
            path.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            // Top-left corner
            path.appendArc(withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                          radius: cornerRadius, startAngle: 90, endAngle: 180)
            // Left edge
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius))
            // Bottom-left corner
            path.appendArc(withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                          radius: cornerRadius, startAngle: 180, endAngle: 270)
            
        case .up:
            // Start at bottom-left of rounded rect, go clockwise
            path.move(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            // Bottom edge
            path.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            // Bottom-right corner
            path.appendArc(withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                          radius: cornerRadius, startAngle: 270, endAngle: 0)
            // Right edge
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            // Top-right corner
            path.appendArc(withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                          radius: cornerRadius, startAngle: 0, endAngle: 90)
            // Top edge → arrow
            path.line(to: NSPoint(x: midX + halfArrow, y: rect.maxY))
            path.line(to: NSPoint(x: midX, y: bounds.maxY))  // Arrow tip
            path.line(to: NSPoint(x: midX - halfArrow, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            // Top-left corner
            path.appendArc(withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                          radius: cornerRadius, startAngle: 90, endAngle: 180)
            // Left edge
            path.line(to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius))
            // Bottom-left corner
            path.appendArc(withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                          radius: cornerRadius, startAngle: 180, endAngle: 270)
        }
        
        path.close()
        return path
    }
    
    func updateMask() {
        let maskLayer = CAShapeLayer()
        maskLayer.path = calloutPath().cgPath
        layer?.mask = maskLayer
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw subtle border along the callout shape
        let path = calloutPath()
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    
    override func layout() {
        super.layout()
        updateMask()
    }
}

/// Floating toolbar window with macOS-style callout appearance
class FloatingToolbarWindow: NSPanel {
    private var toolsView: AnnotationToolsView?
    private var calloutBackground: CalloutBackgroundView?
    private var visualEffectView: NSVisualEffectView?
    
    static let arrowHeight: CGFloat = 8
    static let contentHeight: CGFloat = 48
    static let totalHeight: CGFloat = contentHeight + arrowHeight
    
    var onToolSelected: ((AnnotationTool) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?

    var onCancel: (() -> Void)?
    
    init() {
        // Calculate dynamic size based on content
        let padding: CGFloat = 12
        let buttonSize: CGFloat = 28
        let spacing: CGFloat = 8
        let separatorWidth: CGFloat = 9
        
        // 10 tool buttons
        let toolsWidth = CGFloat(10) * buttonSize + CGFloat(9) * spacing
        
        // Color button + undo + redo
        let controlsWidth = buttonSize + spacing + buttonSize + 4 + buttonSize + 4
        
        // Action buttons (Copy, Save, Cancel)
        let actionsWidth = buttonSize * 3 + spacing * 3
        
        // Total width - balanced padding on both sides
        let toolbarWidth = padding + toolsWidth + separatorWidth + controlsWidth + separatorWidth + actionsWidth + padding
        let toolbarHeight = FloatingToolbarWindow.totalHeight
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: toolbarWidth, height: toolbarHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    // Allow panel to receive mouse events without activating
    override var canBecomeKey: Bool { false }
    
    private func setupWindow() {
        // Window properties
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        self.becomesKeyOnlyIfNeeded = true
        
        // Create callout background view (fills the entire window)
        let calloutBg = CalloutBackgroundView(frame: contentView!.bounds)
        calloutBg.autoresizingMask = [.width, .height]
        calloutBg.arrowDirection = .down
        contentView?.addSubview(calloutBg)
        self.calloutBackground = calloutBg
        
        // Create visual effect view for glassmorphism, placed inside callout
        let visualEffect = NSVisualEffectView(frame: calloutBg.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        calloutBg.addSubview(visualEffect)
        self.visualEffectView = visualEffect
        
        // Create tools view positioned in the content area (above the arrow)
        let toolsFrame = NSRect(
            x: 0,
            y: FloatingToolbarWindow.arrowHeight,
            width: contentView!.bounds.width,
            height: FloatingToolbarWindow.contentHeight
        )
        toolsView = AnnotationToolsView(frame: toolsFrame)
        toolsView?.autoresizingMask = [.width]
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

        toolsView?.onCancel = { [weak self] in
            self?.onCancel?()
        }
        
        calloutBg.addSubview(toolsView!)
    }
    
    func selectTool(_ tool: AnnotationTool) {
        toolsView?.selectTool(tool)
    }
    
    func setArrowDirection(_ direction: CalloutArrowDirection) {
        calloutBackground?.arrowDirection = direction
        
        // Reposition tools view based on arrow direction
        let arrowH = FloatingToolbarWindow.arrowHeight
        let contentH = FloatingToolbarWindow.contentHeight
        switch direction {
        case .down:
            toolsView?.frame = NSRect(x: 0, y: arrowH, width: frame.width, height: contentH)
        case .up:
            toolsView?.frame = NSRect(x: 0, y: 0, width: frame.width, height: contentH)
        }
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

    var onCancel: (() -> Void)?
    
    private var toolButtons: [NSButton] = []
    private var selectedToolIndex: Int = 0
    private var colorWell: ColorPickerButton?
    
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
        
        // Color picker button (replaces NSColorWell for better compatibility with non-key panels)
        let colorButton = ColorPickerButton(frame: NSRect(x: currentX, y: (frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize))
        colorButton.currentColor = .systemRed
        colorButton.onColorChanged = { [weak self] color in
            self?.onColorChanged?(color)
        }
        addSubview(colorButton)
        self.colorWell = colorButton
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
        
        // Action buttons: Copy, Save, Cancel (icon-only)
        let actionButtons: [(String, String, Int)] = [
            ("doc.on.doc", "Copy", -10),
            ("square.and.arrow.down", "Save", -11),
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
    
    func setColor(_ color: NSColor) {
        colorWell?.currentColor = color
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
