import AppKit

/// Floating properties panel window with macOS-style glassmorphism
class FloatingPropertiesWindow: NSPanel {
    private var propertiesView: ToolPropertiesView?
    
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onOpacityChanged: ((CGFloat) -> Void)?
    var onCornerRadiusChanged: ((CGFloat) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onFilledChanged: ((Bool) -> Void)?
    
    init() {
        // Calculate size based on content
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 44
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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
        
        // Create properties view
        propertiesView = ToolPropertiesView(frame: visualEffect.bounds)
        propertiesView?.autoresizingMask = [.width, .height]
        propertiesView?.onLineWidthChanged = { [weak self] width in
            self?.onLineWidthChanged?(width)
        }
        propertiesView?.onOpacityChanged = { [weak self] opacity in
            self?.onOpacityChanged?(opacity)
        }
        propertiesView?.onCornerRadiusChanged = { [weak self] radius in
            self?.onCornerRadiusChanged?(radius)
        }
        propertiesView?.onColorChanged = { [weak self] color in
            self?.onColorChanged?(color)
        }
        propertiesView?.onFilledChanged = { [weak self] filled in
            self?.onFilledChanged?(filled)
        }
        
        visualEffect.addSubview(propertiesView!)
    }
    
    func updateForTool(_ tool: AnnotationTool) {
        propertiesView?.updateForTool(tool)
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
    var onColorChanged: ((NSColor) -> Void)?
    var onFilledChanged: ((Bool) -> Void)?
    
    private var colorWell: NSColorWell?
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
        
        // Color well
        let colorWell = NSColorWell(frame: NSRect(x: currentX, y: (frame.height - 28) / 2, width: 28, height: 28))
        colorWell.color = .systemRed
        colorWell.isBordered = false
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        addSubview(colorWell)
        self.colorWell = colorWell
        currentX += 28 + spacing + 4
        
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
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
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
