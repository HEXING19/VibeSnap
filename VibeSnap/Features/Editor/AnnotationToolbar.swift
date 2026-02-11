import AppKit

/// Main annotation window with floating toolbar and properties panel
class AnnotationToolbar: NSWindow {
    private var canvas: CanvasView?
    private var floatingToolbar: FloatingToolbarWindow?
    private var floatingProperties: FloatingPropertiesWindow?
    
    private(set) var capturedImage: NSImage?
    private(set) var capturedRect: CGRect = .zero
    
    // Callbacks
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?

    var onCancel: (() -> Void)?
    
    init() {
        // Initial size - will be updated when showing image
        let initialSize = CGSize(width: 800, height: 600)
        let screenRect = NSScreen.main?.visibleFrame ?? CGRect.zero
        
        let windowRect = CGRect(
            x: screenRect.midX - initialSize.width / 2,
            y: screenRect.midY - initialSize.height / 2,
            width: initialSize.width,
            height: initialSize.height
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupFloatingPanels()
    }
    
    private func setupWindow() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
        self.isReleasedWhenClosed = false
    }
    
    // Allow this borderless window to become key (needed for text input)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    private func setupFloatingPanels() {
        // Create floating toolbar
        floatingToolbar = FloatingToolbarWindow()
        floatingToolbar?.onToolSelected = { [weak self] tool in
            self?.canvas?.currentTool = tool
            self?.floatingProperties?.updateForTool(tool)
        }
        floatingToolbar?.onColorChanged = { [weak self] color in
            self?.canvas?.setColor(color)
        }
        floatingToolbar?.onUndo = { [weak self] in
            self?.canvas?.undo()
        }
        floatingToolbar?.onRedo = { [weak self] in
            self?.canvas?.redo()
        }
        floatingToolbar?.onCopy = { [weak self] in
            self?.copyToClipboard()
        }
        floatingToolbar?.onSave = { [weak self] in
            self?.saveImage()
        }

        floatingToolbar?.onCancel = { [weak self] in
            self?.cancel()
        }
        
        // Create floating properties panel
        floatingProperties = FloatingPropertiesWindow()
        floatingProperties?.onLineWidthChanged = { [weak self] width in
            self?.canvas?.setLineWidth(width)
        }
        floatingProperties?.onOpacityChanged = { [weak self] opacity in
            self?.canvas?.setOpacity(opacity)
        }
        floatingProperties?.onCornerRadiusChanged = { [weak self] radius in
            self?.canvas?.setCornerRadius(radius)
        }
        floatingProperties?.onColorChanged = { [weak self] color in
            self?.canvas?.setColor(color)
        }
        floatingProperties?.onFilledChanged = { [weak self] filled in
            self?.canvas?.setFilled(filled)
        }
        
        // Observe window movement to update floating windows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }
    
    func show(with image: NSImage, rect: CGRect) {
        capturedImage = image
        capturedRect = rect
        
        // Calculate window size based on image
        let windowSize = calculateWindowSize(for: image)
        
        // Position window
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - windowSize.width / 2
            let y = screenRect.midY - windowSize.height / 2
            
            self.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: windowSize), display: false)
        }
        
        // Create content view
        let contentView = NSView(frame: CGRect(origin: .zero, size: windowSize))
        contentView.wantsLayer = true
        
        // Add subtle background with rounded corners
        let backgroundLayer = CALayer()
        backgroundLayer.frame = contentView.bounds
        backgroundLayer.backgroundColor = NSColor(white: 0.95, alpha: 0.98).cgColor
        backgroundLayer.cornerRadius = 8
        backgroundLayer.borderWidth = 1
        backgroundLayer.borderColor = NSColor(white: 0.8, alpha: 1.0).cgColor
        contentView.layer?.addSublayer(backgroundLayer)
        
        // Create canvas
        let canvasFrame = CGRect(
            x: 0,
            y: 0,
            width: windowSize.width,
            height: windowSize.height
        )
        canvas = CanvasView(frame: canvasFrame, image: image)
        canvas?.autoresizingMask = [.width, .height]
        contentView.addSubview(canvas!)
        
        self.contentView = contentView
        
        // Show floating windows
        floatingToolbar?.makeKeyAndOrderFront(nil)
        floatingProperties?.makeKeyAndOrderFront(nil)
        
        // Position floating windows
        updateFloatingWindowPositions()
        
        // Select default tool
        floatingToolbar?.selectTool(.rectangle)
        floatingProperties?.updateForTool(.rectangle)
        canvas?.currentTool = .rectangle
        
        // Animate in
        self.alphaValue = 0
        floatingToolbar?.alphaValue = 0
        floatingProperties?.alphaValue = 0
        
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
            self.floatingToolbar?.animator().alphaValue = 1
            self.floatingProperties?.animator().alphaValue = 1
        }
    }
    
    private func calculateWindowSize(for image: NSImage) -> CGSize {
        guard let screen = NSScreen.main else {
            return CGSize(width: 800, height: 600)
        }
        
        let screenSize = screen.visibleFrame.size
        
        // Max canvas size (80% of screen for better visibility with floating windows)
        let maxWidth = screenSize.width * 0.8
        let maxHeight = screenSize.height * 0.8
        
        // Calculate scaled image size
        let imageSize = image.size
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1.0)
        
        // Use actual scaled size without artificial minimums
        let canvasWidth = imageSize.width * scale
        let canvasHeight = imageSize.height * scale
        
        return CGSize(
            width: canvasWidth,
            height: canvasHeight
        )
    }
    
    @objc private func windowDidMove() {
        updateFloatingWindowPositions()
    }
    
    private func updateFloatingWindowPositions() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let toolbarHeight: CGFloat = 48
        let propertiesHeight: CGFloat = 44
        let spacing: CGFloat = 10
        
        // Check if toolbar would go off-screen above
        let toolbarTopY = windowFrame.maxY + spacing + toolbarHeight
        let propertiesTopY = toolbarTopY + spacing + propertiesHeight
        
        if propertiesTopY > screenFrame.maxY {
            // Position below the main window instead
            let toolbarY = windowFrame.minY - spacing - toolbarHeight
            let propertiesY = toolbarY - spacing - propertiesHeight
            
            if let toolbar = floatingToolbar {
                let toolbarX = windowFrame.midX - toolbar.frame.width / 2
                toolbar.setFrameOrigin(CGPoint(x: toolbarX, y: toolbarY))
            }
            if let properties = floatingProperties {
                let propertiesX = windowFrame.midX - properties.frame.width / 2
                properties.setFrameOrigin(CGPoint(x: propertiesX, y: propertiesY))
            }
        } else {
            // Default: position above the main window
            floatingToolbar?.positionRelativeTo(window: self, offset: CGPoint(x: 0, y: spacing))
            floatingProperties?.positionRelativeTo(window: self, offset: CGPoint(x: 0, y: spacing + toolbarHeight + spacing))
        }
    }
    
    
    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
            self.floatingToolbar?.animator().alphaValue = 0
            self.floatingProperties?.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.floatingToolbar?.orderOut(nil)
            self.floatingProperties?.orderOut(nil)
        })
    }
    
    func copyToClipboard() {
        guard let image = canvas?.getFinalImage() ?? capturedImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        hide()
        onCopy?()
    }
    
    func saveImage() {
        guard let image = canvas?.getFinalImage() ?? capturedImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        savePanel.nameFieldStringValue = "VibeSnap_\(dateFormatter.string(from: Date())).png"
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
            self?.hide()
            self?.onSave?()
        }
    }
    

    
    func cancel() {
        hide()
        onCancel?()
    }
}

/// Unified view containing toolbar, canvas, and action buttons
class UnifiedAnnotationView: NSView {
    weak var toolbar: AnnotationToolbar?
    private var toolsToolbar: AnnotationToolsToolbar?
    private var propertiesPanel: ToolPropertiesPanel?
    private var canvas: CanvasView?
    
    private let toolbarHeight: CGFloat = 60
    private let propertiesPanelHeight: CGFloat = 44
    
    init(frame frameRect: NSRect, toolbar: AnnotationToolbar, image: NSImage) {
        self.toolbar = toolbar
        super.init(frame: frameRect)
        setupView(image: image)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupView(image: NSImage) {
        wantsLayer = true
        
        // Create subtle gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            NSColor(white: 0.10, alpha: 1.0).cgColor,
            NSColor(white: 0.08, alpha: 1.0).cgColor,
            NSColor(white: 0.10, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(gradientLayer, at: 0)
        
        // Top toolbar with annotation tools
        let toolbarFrame = CGRect(
            x: 0,
            y: bounds.height - toolbarHeight,
            width: bounds.width,
            height: toolbarHeight
        )
        toolsToolbar = AnnotationToolsToolbar(frame: toolbarFrame)
        toolsToolbar?.autoresizingMask = [.width, .minYMargin]
        toolsToolbar?.onToolSelected = { [weak self] tool in
            self?.canvas?.currentTool = tool
            self?.propertiesPanel?.updateForTool(tool)
        }
        toolsToolbar?.onColorChanged = { [weak self] color in
            self?.canvas?.setColor(color)
        }
        toolsToolbar?.onUndo = { [weak self] in
            self?.canvas?.undo()
        }
        toolsToolbar?.onRedo = { [weak self] in
            self?.canvas?.redo()
        }
        addSubview(toolsToolbar!)
        
        // Properties panel below toolbar
        let propertiesFrame = CGRect(
            x: 0,
            y: bounds.height - toolbarHeight - propertiesPanelHeight,
            width: bounds.width,
            height: propertiesPanelHeight
        )
        propertiesPanel = ToolPropertiesPanel(frame: propertiesFrame)
        propertiesPanel?.autoresizingMask = [.width, .minYMargin]
        propertiesPanel?.onLineWidthChanged = { [weak self] width in
            self?.canvas?.setLineWidth(width)
        }
        propertiesPanel?.onOpacityChanged = { [weak self] opacity in
            self?.canvas?.setOpacity(opacity)
        }
        propertiesPanel?.onCornerRadiusChanged = { [weak self] radius in
            self?.canvas?.setCornerRadius(radius)
        }
        propertiesPanel?.onColorChanged = { [weak self] color in
            self?.canvas?.setColor(color)
        }
        propertiesPanel?.onFilledChanged = { [weak self] filled in
            self?.canvas?.setFilled(filled)
        }
        addSubview(propertiesPanel!)
        
        // Middle canvas with image - with subtle border
        let canvasFrame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - toolbarHeight - propertiesPanelHeight
        )
        canvas = CanvasView(frame: canvasFrame, image: image)
        canvas?.autoresizingMask = [.width, .height]
        canvas?.wantsLayer = true
        canvas?.layer?.borderWidth = 1
        canvas?.layer?.borderColor = NSColor(white: 0.2, alpha: 0.5).cgColor
        addSubview(canvas!)
    }
    
    func getFinalImage() -> NSImage? {
        return canvas?.renderFinalImage()
    }
}


/// Top toolbar with annotation tools - macOS Preview style
class AnnotationToolsToolbar: NSView {
    var onToolSelected: ((AnnotationTool) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    
    private var toolButtons: [NSButton] = []
    private var selectedToolIndex: Int = 0
    private var containerView: NSView?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }
    
    private func setupToolbar() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create centered container with light background (macOS native style)
        let toolCount = 10
        let buttonSize: CGFloat = 32
        let buttonSpacing: CGFloat = 8  // Increased spacing
        let containerWidth = CGFloat(toolCount) * buttonSize + CGFloat(toolCount - 1) * buttonSpacing + 32
        let containerHeight: CGFloat = 48
        
        containerView = NSView(frame: CGRect(
            x: (frame.width - containerWidth) / 2,
            y: (frame.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        ))
        containerView?.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        containerView?.wantsLayer = true
        
        // Light translucent background (macOS native style)
        containerView?.layer?.backgroundColor = NSColor(white: 0.95, alpha: 0.92).cgColor
        containerView?.layer?.cornerRadius = 12
        containerView?.layer?.borderWidth = 0.5
        containerView?.layer?.borderColor = NSColor(white: 0.75, alpha: 0.6).cgColor
        
        // Add subtle shadow
        containerView?.shadow = NSShadow()
        containerView?.layer?.shadowColor = NSColor.black.cgColor
        containerView?.layer?.shadowOpacity = 0.2
        containerView?.layer?.shadowOffset = CGSize(width: 0, height: -3)
        containerView?.layer?.shadowRadius = 12
        
        addSubview(containerView!)
        
        // All 10 tools matching the reference image exactly in order
        let tools: [(AnnotationTool, String, String)] = [
            (.rectangle, "rectangle", "矩形"),
            (.ellipse, "circle", "椭圆"),
            (.line, "line.diagonal", "直线"),
            (.arrow, "arrow.up.right", "箭头"),
            (.freehand, "scribble.variable", "自由绘制"),
            (.callout, "text.bubble", "标注气泡"),
            (.text, "textformat", "文字"),
            (.number, "1.circle", "序号"),
            (.mosaic, "checkerboard.rectangle", "马赛克"),
            (.magnifier, "magnifyingglass", "放大镜")
        ]
        
        var xOffset: CGFloat = 16
        
        for (index, tool) in tools.enumerated() {
            let button = createToolButton(icon: tool.1, tooltip: tool.2, tag: tool.0.rawValue, index: index)
            button.frame = CGRect(x: xOffset, y: (containerHeight - buttonSize) / 2, width: buttonSize, height: buttonSize)
            containerView?.addSubview(button)
            toolButtons.append(button)
            xOffset += buttonSize + buttonSpacing
        }
        
        // Select first tool (rectangle) by default
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.selectTool(at: 0)
        }
    }
    
    private func createToolButton(icon: String, tooltip: String, tag: Int, index: Int) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.tag = tag
        button.target = self
        button.action = #selector(toolClicked(_:))
        button.toolTip = tooltip
        
        // Use accessibilityIdentifier to store the index
        button.cell?.tag = index
        
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            button.image = image.withSymbolConfiguration(config)
            button.contentTintColor = NSColor(white: 0.25, alpha: 1.0)  // Dark gray icons
        }
        
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.imagePosition = .imageOnly
        
        return button
    }
    
    @objc private func toolClicked(_ sender: NSButton) {
        // Find the button index
        if let index = toolButtons.firstIndex(of: sender) {
            selectTool(at: index)
        }
        
        if let tool = AnnotationTool(rawValue: sender.tag) {
            onToolSelected?(tool)
        }
    }
    
    private func selectTool(at index: Int) {
        selectedToolIndex = index
        
        // Update all buttons appearance
        for (i, btn) in toolButtons.enumerated() {
            if i == index {
                // Selected state - light blue background
                btn.layer?.backgroundColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.15).cgColor
                btn.contentTintColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            } else {
                // Normal state
                btn.layer?.backgroundColor = NSColor.clear.cgColor
                btn.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
            }
        }
        
        // Trigger the callback to actually set the tool
        if index < toolButtons.count, let tool = AnnotationTool(rawValue: toolButtons[index].tag) {
            onToolSelected?(tool)
        }
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
    }
}

/// Tool Properties Panel - displays adjustable properties for the current tool
class ToolPropertiesPanel: NSView {
    // Callbacks for property changes
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onOpacityChanged: ((CGFloat) -> Void)?
    var onCornerRadiusChanged: ((CGFloat) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onFilledChanged: ((Bool) -> Void)?
    
    // UI Components
    private var containerView: NSView?
    private var lineWidthSlider: NSSlider?
    private var lineWidthLabel: NSTextField?
    private var opacitySlider: NSSlider?
    private var opacityLabel: NSTextField?
    private var cornerRadiusSlider: NSSlider?
    private var cornerRadiusLabel: NSTextField?
    private var colorWell: NSColorWell?
    private var fillCheckbox: NSButton?
    
    private var currentTool: AnnotationTool = .rectangle
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPanel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanel()
    }
    
    private func setupPanel() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create container with light translucent background (macOS native style)
        let containerHeight: CGFloat = 40
        let containerWidth: CGFloat = 420
        containerView = NSView(frame: CGRect(
            x: (frame.width - containerWidth) / 2,
            y: (frame.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        ))
        containerView?.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        containerView?.wantsLayer = true
        containerView?.layer?.backgroundColor = NSColor(white: 0.95, alpha: 0.92).cgColor
        containerView?.layer?.cornerRadius = 10
        containerView?.layer?.borderWidth = 0.5
        containerView?.layer?.borderColor = NSColor(white: 0.75, alpha: 0.6).cgColor
        
        // Add subtle shadow
        containerView?.shadow = NSShadow()
        containerView?.layer?.shadowColor = NSColor.black.cgColor
        containerView?.layer?.shadowOpacity = 0.2
        containerView?.layer?.shadowOffset = CGSize(width: 0, height: -2)
        containerView?.layer?.shadowRadius = 10
        
        addSubview(containerView!)
        
        var xOffset: CGFloat = 16
        
        // Color Picker (no label, just the color well)
        colorWell = NSColorWell(frame: CGRect(x: xOffset, y: 8, width: 24, height: 24))
        colorWell?.color = .systemRed
        colorWell?.target = self
        colorWell?.action = #selector(colorChanged(_:))
        colorWell?.wantsLayer = true
        colorWell?.layer?.cornerRadius = 4
        colorWell?.layer?.borderWidth = 0.5
        colorWell?.layer?.borderColor = NSColor(white: 0.6, alpha: 0.5).cgColor
        containerView?.addSubview(colorWell!)
        xOffset += 32
        
        // Pattern icon (for line style - using SF Symbol)
        let patternIcon = NSImageView(frame: CGRect(x: xOffset, y: 10, width: 20, height: 20))
        if let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            patternIcon.image = image.withSymbolConfiguration(config)
            patternIcon.contentTintColor = NSColor(white: 0.4, alpha: 1.0)
        }
        containerView?.addSubview(patternIcon)
        xOffset += 24
        
        // Line Width Slider (no label)
        lineWidthSlider = NSSlider(frame: CGRect(x: xOffset, y: 10, width: 90, height: 20))
        lineWidthSlider?.minValue = 1
        lineWidthSlider?.maxValue = 20
        lineWidthSlider?.doubleValue = 3
        lineWidthSlider?.target = self
        lineWidthSlider?.action = #selector(lineWidthChanged(_:))
        lineWidthSlider?.controlSize = .small
        containerView?.addSubview(lineWidthSlider!)
        xOffset += 100
        
        // Separator line
        let separator1 = NSView(frame: CGRect(x: xOffset, y: 8, width: 1, height: 24))
        separator1.wantsLayer = true
        separator1.layer?.backgroundColor = NSColor(white: 0.7, alpha: 0.5).cgColor
        containerView?.addSubview(separator1)
        xOffset += 10
        
        // Opacity Slider (no label)
        opacitySlider = NSSlider(frame: CGRect(x: xOffset, y: 10, width: 90, height: 20))
        opacitySlider?.minValue = 0.1
        opacitySlider?.maxValue = 1.0
        opacitySlider?.doubleValue = 1.0
        opacitySlider?.target = self
        opacitySlider?.action = #selector(opacityChanged(_:))
        opacitySlider?.controlSize = .small
        containerView?.addSubview(opacitySlider!)
        xOffset += 100
        
        // Separator line
        let separator2 = NSView(frame: CGRect(x: xOffset, y: 8, width: 1, height: 24))
        separator2.wantsLayer = true
        separator2.layer?.backgroundColor = NSColor(white: 0.7, alpha: 0.5).cgColor
        containerView?.addSubview(separator2)
        xOffset += 10
        
        // Corner Radius Slider (no label, hidden by default)
        cornerRadiusSlider = NSSlider(frame: CGRect(x: xOffset, y: 10, width: 60, height: 20))
        cornerRadiusSlider?.minValue = 0
        cornerRadiusSlider?.maxValue = 30
        cornerRadiusSlider?.doubleValue = 0
        cornerRadiusSlider?.target = self
        cornerRadiusSlider?.action = #selector(cornerRadiusChanged(_:))
        cornerRadiusSlider?.controlSize = .small
        cornerRadiusSlider?.isHidden = true
        containerView?.addSubview(cornerRadiusSlider!)
        
        // Fill toggle button (icon-only, hidden by default)
        let fillBtnSize: CGFloat = 28
        fillCheckbox = NSButton(frame: CGRect(x: xOffset, y: (40 - fillBtnSize) / 2, width: fillBtnSize, height: fillBtnSize))
        fillCheckbox?.setButtonType(.toggle)
        fillCheckbox?.bezelStyle = .regularSquare
        fillCheckbox?.isBordered = false
        fillCheckbox?.title = ""
        fillCheckbox?.target = self
        fillCheckbox?.action = #selector(fillChanged(_:))
        fillCheckbox?.isHidden = true
        fillCheckbox?.toolTip = "填充"
        fillCheckbox?.wantsLayer = true
        fillCheckbox?.layer?.cornerRadius = 6
        
        // Use unfilled square icon (will toggle visually)
        if let img = NSImage(systemSymbolName: "square", accessibilityDescription: "填充") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            fillCheckbox?.image = img.withSymbolConfiguration(config)
        }
        if let altImg = NSImage(systemSymbolName: "square.fill", accessibilityDescription: "取消填充") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            fillCheckbox?.alternateImage = altImg.withSymbolConfiguration(config)
        }
        fillCheckbox?.imagePosition = .imageOnly
        fillCheckbox?.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        containerView?.addSubview(fillCheckbox!)
        
        // Update visibility for default tool
        updateForTool(.rectangle)
    }
    
    private func createLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor(white: 0.3, alpha: 1.0)
        return label
    }
    
    func updateForTool(_ tool: AnnotationTool) {
        currentTool = tool
        
        // Show/hide controls based on tool
        let showLineWidth = [.rectangle, .ellipse, .line, .arrow, .freehand, .callout].contains(tool)
        let showCornerRadius = [.rectangle, .callout].contains(tool)
        let showFill = [.rectangle, .ellipse].contains(tool)
        
        // Only show/hide sliders and controls (no labels in new design)
        lineWidthSlider?.isHidden = !showLineWidth
        cornerRadiusSlider?.isHidden = !showCornerRadius
        fillCheckbox?.isHidden = !showFill
    }
    
    @objc private func lineWidthChanged(_ sender: NSSlider) {
        onLineWidthChanged?(CGFloat(sender.doubleValue))
    }
    
    @objc private func opacityChanged(_ sender: NSSlider) {
        onOpacityChanged?(CGFloat(sender.doubleValue))
    }
    
    @objc private func cornerRadiusChanged(_ sender: NSSlider) {
        onCornerRadiusChanged?(CGFloat(sender.doubleValue))
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
    }
    
    @objc private func fillChanged(_ sender: NSButton) {
        onFilledChanged?(sender.state == .on)
    }
}

/// Custom button with hover effects
class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Add hover glow
            if layer?.sublayers?.first(where: { $0 is CAGradientLayer }) == nil {
                layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
            }
        }
        
        // Scale up slightly
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.15
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.05
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(scaleAnimation, forKey: "hoverScale")
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Remove hover glow if not selected
            if layer?.sublayers?.first(where: { $0 is CAGradientLayer }) == nil {
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        // Scale back to normal
        layer?.removeAnimation(forKey: "hoverScale")
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.15
        scaleAnimation.fromValue = 1.05
        scaleAnimation.toValue = 1.0
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer?.add(scaleAnimation, forKey: "hoverScaleOut")
    }
}

/// Bottom action buttons bar - Professional UI with glassmorphism
class ActionButtonsBar: NSView {
    weak var toolbar: AnnotationToolbar?
    private var visualEffectView: NSVisualEffectView?
    
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?
    
    init(frame frameRect: NSRect, toolbar: AnnotationToolbar? = nil) {
        self.toolbar = toolbar
        super.init(frame: frameRect)
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButtons()
    }
    
    private func setupButtons() {
        wantsLayer = true
        
        // Glassmorphism background
        visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView?.autoresizingMask = [.width, .height]
        visualEffectView?.material = .hudWindow
        visualEffectView?.state = .active
        visualEffectView?.blendingMode = .behindWindow
        visualEffectView?.wantsLayer = true
        visualEffectView?.layer?.cornerRadius = 0
        addSubview(visualEffectView!)
        
        // Subtle gradient overlay
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            NSColor(white: 0.12, alpha: 0.95).cgColor,
            NSColor(white: 0.15, alpha: 0.95).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        layer?.insertSublayer(gradientLayer, at: 0)
        
        let buttonConfigs: [(title: String, icon: String, tag: Int, style: ButtonStyle)] = [
            ("Copy", "doc.on.doc", 0, .secondary),
            ("Save", "square.and.arrow.down", 1, .secondary),
            ("Done", "checkmark.circle", 2, .success),
            ("Cancel", "xmark.circle", 3, .danger)
        ]
        
        let buttonWidth: CGFloat = 90
        let buttonHeight: CGFloat = 38
        let spacing: CGFloat = 14
        let totalWidth = CGFloat(buttonConfigs.count) * buttonWidth + CGFloat(buttonConfigs.count - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        let startY = (bounds.height - buttonHeight) / 2
        
        for (index, config) in buttonConfigs.enumerated() {
            let x = startX + CGFloat(index) * (buttonWidth + spacing)
            let button = createButton(
                title: config.title,
                icon: config.icon,
                frame: CGRect(x: x, y: startY, width: buttonWidth, height: buttonHeight),
                tag: config.tag,
                style: config.style
            )
            addSubview(button)
        }
    }
    
    private enum ButtonStyle {
        case secondary
        case success
        case danger
    }
    
    private func createButton(title: String, icon: String, frame: CGRect, tag: Int, style: ButtonStyle) -> ActionButton {
        let button = ActionButton(frame: frame)
        button.tag = tag
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.toolTip = title
        
        // Configure icon
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft
        }
        
        button.title = title
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.bezelStyle = .rounded
        button.isBordered = true
        
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1.5
        
        // Style based on button type
        switch style {
        case .secondary:
            button.layer?.backgroundColor = NSColor(white: 0.25, alpha: 0.5).cgColor
            button.layer?.borderColor = NSColor(white: 0.4, alpha: 0.3).cgColor
            button.contentTintColor = NSColor(white: 0.95, alpha: 1.0)
            button.hoverBackgroundColor = NSColor(white: 0.3, alpha: 0.6)
            
        case .success:
            let greenColor = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
            button.layer?.backgroundColor = greenColor.withAlphaComponent(0.25).cgColor
            button.layer?.borderColor = greenColor.withAlphaComponent(0.5).cgColor
            button.contentTintColor = NSColor(red: 0.4, green: 0.95, blue: 0.55, alpha: 1.0)
            button.hoverBackgroundColor = greenColor.withAlphaComponent(0.35)
            
        case .danger:
            let redColor = NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
            button.layer?.backgroundColor = redColor.withAlphaComponent(0.2).cgColor
            button.layer?.borderColor = redColor.withAlphaComponent(0.4).cgColor
            button.contentTintColor = NSColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1.0)
            button.hoverBackgroundColor = redColor.withAlphaComponent(0.3)
        }
        
        return button
    }
    
    @objc private func buttonClicked(_ sender: NSButton) {
        // Add click animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.1
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.95
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sender.layer?.add(scaleAnimation, forKey: "clickScale")
        
        switch sender.tag {
        case 0: onCopy?()
        case 1: onSave?()
        case 2: onDone?()
        case 3: onCancel?()
        default: break
        }
    }
}

/// Custom action button with hover effects
class ActionButton: NSButton {
    private var trackingArea: NSTrackingArea?
    var hoverBackgroundColor: NSColor = NSColor(white: 0.3, alpha: 0.6)
    private var originalBackgroundColor: CGColor?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        if originalBackgroundColor == nil {
            originalBackgroundColor = layer?.backgroundColor
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer?.backgroundColor = hoverBackgroundColor.cgColor
        }
        
        // Subtle scale up
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.2
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.03
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(scaleAnimation, forKey: "hoverScale")
        
        // Glow effect
        layer?.shadowColor = contentTintColor?.cgColor
        layer?.shadowRadius = 8
        layer?.shadowOpacity = 0.4
        layer?.shadowOffset = .zero
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if let original = originalBackgroundColor {
                layer?.backgroundColor = original
            }
        }
        
        // Scale back to normal
        layer?.removeAnimation(forKey: "hoverScale")
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.2
        scaleAnimation.fromValue = 1.03
        scaleAnimation.toValue = 1.0
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer?.add(scaleAnimation, forKey: "hoverScaleOut")
        
        // Remove glow
        layer?.shadowOpacity = 0
    }
}
