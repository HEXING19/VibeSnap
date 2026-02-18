import AppKit

/// Floating properties panel window with macOS-style callout appearance
class FloatingPropertiesWindow: NSPanel {
    private var propertiesView: ToolPropertiesView?
    private var calloutBackground: CalloutBackgroundView?
    private var visualEffectView: NSVisualEffectView?
    
    static let arrowHeight: CGFloat = 8
    static let contentHeight: CGFloat = 44
    static let totalHeight: CGFloat = contentHeight + arrowHeight
    
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onOpacityChanged: ((CGFloat) -> Void)?
    var onCornerRadiusChanged: ((CGFloat) -> Void)?
    var onFilledChanged: ((Bool) -> Void)?
    
    init() {
        // Calculate size based on content
        let panelWidth: CGFloat = 420
        let panelHeight = FloatingPropertiesWindow.totalHeight
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
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
        
        // Create properties view positioned in the content area (above the arrow)
        let propsFrame = NSRect(
            x: 0,
            y: FloatingPropertiesWindow.arrowHeight,
            width: contentView!.bounds.width,
            height: FloatingPropertiesWindow.contentHeight
        )
        propertiesView = ToolPropertiesView(frame: propsFrame)
        propertiesView?.autoresizingMask = [.width]
        propertiesView?.onLineWidthChanged = { [weak self] width in
            self?.onLineWidthChanged?(width)
        }
        propertiesView?.onOpacityChanged = { [weak self] opacity in
            self?.onOpacityChanged?(opacity)
        }
        propertiesView?.onCornerRadiusChanged = { [weak self] radius in
            self?.onCornerRadiusChanged?(radius)
        }
        propertiesView?.onFilledChanged = { [weak self] filled in
            self?.onFilledChanged?(filled)
        }
        
        calloutBg.addSubview(propertiesView!)
    }
    
    func updateForTool(_ tool: AnnotationTool) {
        propertiesView?.updateForTool(tool)
        
        // Calculate required width based on visible controls
        let baseWidth: CGFloat = 24 // padding
        let propertyWidth: CGFloat = 20 + 4 + 80 + 8 // icon + spacing + slider + spacing
        let separatorWidth: CGFloat = 9
        let fillButtonWidth: CGFloat = 28 + 8
        
        var totalWidth: CGFloat = 0
        var hasProperties = true
        
        // Calculate width based on tool properties
        switch tool {
        case .rectangle:
            totalWidth = baseWidth + propertyWidth * 3 + separatorWidth * 2 + fillButtonWidth
            
        case .ellipse:
            totalWidth = baseWidth + propertyWidth * 2 + separatorWidth + fillButtonWidth
            
        case .line, .arrow, .freehand:
            totalWidth = baseWidth + propertyWidth * 2 + separatorWidth
            
        case .text, .callout, .number:
            // These tools have no properties - hide the window
            hasProperties = false
            
        case .mosaic, .magnifier, .highlighter, .blur:
            // These tools have no properties - hide the window
            hasProperties = false
        }
        
        // Show or hide window based on whether tool has properties
        if hasProperties {
            // Update window size and show
            var frame = self.frame
            frame.size.width = totalWidth
            self.setFrame(frame, display: true, animate: false)
            self.orderFront(nil)
        } else {
            // Hide window for tools with no properties
            self.orderOut(nil)
        }
    }
    
    func setArrowDirection(_ direction: CalloutArrowDirection) {
        calloutBackground?.arrowDirection = direction
        
        // Reposition properties view based on arrow direction
        let arrowH = FloatingPropertiesWindow.arrowHeight
        let contentH = FloatingPropertiesWindow.contentHeight
        switch direction {
        case .down:
            propertiesView?.frame = NSRect(x: 0, y: arrowH, width: frame.width, height: contentH)
        case .up:
            propertiesView?.frame = NSRect(x: 0, y: 0, width: frame.width, height: contentH)
        }
    }
    
    func positionRelativeTo(window: NSWindow, offset: CGPoint = CGPoint(x: 0, y: 120)) {
        let windowFrame = window.frame
        let x = windowFrame.midX - self.frame.width / 2 + offset.x
        // Position above the main window, below the toolbar
        let y = windowFrame.maxY + offset.y
        
        self.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

/// Tool properties view content (without window chrome)
class ToolPropertiesView: NSView {
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onOpacityChanged: ((CGFloat) -> Void)?
    var onCornerRadiusChanged: ((CGFloat) -> Void)?
    var onFilledChanged: ((Bool) -> Void)?
    
    private var lineWidthSlider: NSSlider?
    private var opacitySlider: NSSlider?
    private var cornerRadiusSlider: NSSlider?
    private var fillCheckbox: NSButton?
    
    private var lineWidthIcon: NSImageView?
    private var opacityIcon: NSImageView?
    private var cornerRadiusIcon: NSImageView?
    
    private var currentTool: AnnotationTool = .rectangle
    
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
        let iconSize: CGFloat = 20
        let sliderWidth: CGFloat = 80
        let spacing: CGFloat = 8
        var currentX = padding
        
        // Line width icon + slider
        let lineWidthIcon = NSImageView(frame: NSRect(x: currentX, y: (frame.height - iconSize) / 2, width: iconSize, height: iconSize))
        lineWidthIcon.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        lineWidthIcon.contentTintColor = NSColor(white: 0.3, alpha: 1.0)
        addSubview(lineWidthIcon)
        self.lineWidthIcon = lineWidthIcon
        currentX += iconSize + 4
        
        let lineWidthSlider = NSSlider(frame: NSRect(x: currentX, y: (frame.height - 16) / 2, width: sliderWidth, height: 16))
        lineWidthSlider.minValue = 1
        lineWidthSlider.maxValue = 10
        lineWidthSlider.doubleValue = 2
        lineWidthSlider.target = self
        lineWidthSlider.action = #selector(lineWidthChanged(_:))
        addSubview(lineWidthSlider)
        self.lineWidthSlider = lineWidthSlider
        currentX += sliderWidth + spacing
        
        // Separator
        let separator1 = NSBox(frame: NSRect(x: currentX, y: 8, width: 1, height: frame.height - 16))
        separator1.boxType = .separator
        addSubview(separator1)
        currentX += 9
        
        // Opacity icon + slider
        let opacityIcon = NSImageView(frame: NSRect(x: currentX, y: (frame.height - iconSize) / 2, width: iconSize, height: iconSize))
        opacityIcon.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)
        opacityIcon.contentTintColor = NSColor(white: 0.3, alpha: 1.0)
        addSubview(opacityIcon)
        self.opacityIcon = opacityIcon
        currentX += iconSize + 4
        
        let opacitySlider = NSSlider(frame: NSRect(x: currentX, y: (frame.height - 16) / 2, width: sliderWidth, height: 16))
        opacitySlider.minValue = 0.1
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged(_:))
        addSubview(opacitySlider)
        self.opacitySlider = opacitySlider
        currentX += sliderWidth + spacing
        
        // Separator
        let separator2 = NSBox(frame: NSRect(x: currentX, y: 8, width: 1, height: frame.height - 16))
        separator2.boxType = .separator
        addSubview(separator2)
        currentX += 9
        
        // Corner radius icon + slider (hidden by default)
        let cornerRadiusIcon = NSImageView(frame: NSRect(x: currentX, y: (frame.height - iconSize) / 2, width: iconSize, height: iconSize))
        cornerRadiusIcon.image = NSImage(systemSymbolName: "square.dashed", accessibilityDescription: nil)
        cornerRadiusIcon.contentTintColor = NSColor(white: 0.3, alpha: 1.0)
        cornerRadiusIcon.isHidden = true
        addSubview(cornerRadiusIcon)
        self.cornerRadiusIcon = cornerRadiusIcon
        
        let cornerRadiusSlider = NSSlider(frame: NSRect(x: currentX + iconSize + 4, y: (frame.height - 16) / 2, width: sliderWidth, height: 16))
        cornerRadiusSlider.minValue = 0
        cornerRadiusSlider.maxValue = 20
        cornerRadiusSlider.doubleValue = 0
        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(cornerRadiusChanged(_:))
        cornerRadiusSlider.isHidden = true
        addSubview(cornerRadiusSlider)
        self.cornerRadiusSlider = cornerRadiusSlider
        
        // Fill toggle button (icon-only, hidden by default)
        let btnSize: CGFloat = 28
        let fillCheckbox = NSButton(frame: NSRect(x: currentX, y: (frame.height - btnSize) / 2, width: btnSize, height: btnSize))
        fillCheckbox.setButtonType(.toggle)
        fillCheckbox.bezelStyle = .regularSquare
        fillCheckbox.isBordered = false
        fillCheckbox.title = ""
        fillCheckbox.state = .off
        fillCheckbox.target = self
        fillCheckbox.action = #selector(fillChanged(_:))
        fillCheckbox.isHidden = true
        fillCheckbox.toolTip = "填充"
        fillCheckbox.wantsLayer = true
        fillCheckbox.layer?.cornerRadius = 6
        
        // Use unfilled square icon (will toggle visually)
        if let img = NSImage(systemSymbolName: "square", accessibilityDescription: "填充") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            fillCheckbox.image = img.withSymbolConfiguration(config)
        }
        if let altImg = NSImage(systemSymbolName: "square.fill", accessibilityDescription: "取消填充") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            fillCheckbox.alternateImage = altImg.withSymbolConfiguration(config)
        }
        fillCheckbox.imagePosition = .imageOnly
        fillCheckbox.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        
        addSubview(fillCheckbox)
        self.fillCheckbox = fillCheckbox
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
    
    @objc private func fillChanged(_ sender: NSButton) {
        onFilledChanged?(sender.state == .on)
    }
    
    func updateForTool(_ tool: AnnotationTool) {
        currentTool = tool
        
        // Show/hide controls based on tool
        switch tool {
        case .rectangle, .ellipse:
            lineWidthIcon?.isHidden = false
            lineWidthSlider?.isHidden = false
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = (tool != .rectangle)
            cornerRadiusSlider?.isHidden = (tool != .rectangle)
            fillCheckbox?.isHidden = false
            
        case .line, .arrow:
            lineWidthIcon?.isHidden = false
            lineWidthSlider?.isHidden = false
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = true
            cornerRadiusSlider?.isHidden = true
            fillCheckbox?.isHidden = true
            
        case .freehand:
            lineWidthIcon?.isHidden = false
            lineWidthSlider?.isHidden = false
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = true
            cornerRadiusSlider?.isHidden = true
            fillCheckbox?.isHidden = true
            
        case .text, .callout:
            lineWidthIcon?.isHidden = true
            lineWidthSlider?.isHidden = true
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = true
            cornerRadiusSlider?.isHidden = true
            fillCheckbox?.isHidden = true
            
        case .number:
            lineWidthIcon?.isHidden = true
            lineWidthSlider?.isHidden = true
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = true
            cornerRadiusSlider?.isHidden = true
            fillCheckbox?.isHidden = true
            
        case .mosaic, .magnifier, .highlighter, .blur:
            lineWidthIcon?.isHidden = true
            lineWidthSlider?.isHidden = true
            opacityIcon?.isHidden = false
            opacitySlider?.isHidden = false
            cornerRadiusIcon?.isHidden = true
            cornerRadiusSlider?.isHidden = true
            fillCheckbox?.isHidden = true
        }
    }
}
