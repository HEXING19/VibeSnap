import AppKit

/// Custom NSPanel subclass that can become key window (required for keyboard input)
class TextInputPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}

/// Canvas view for drawing annotations on the screenshot
class CanvasView: NSView, NSTextFieldDelegate {
    private var originalImage: NSImage
    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    
    var currentTool: AnnotationTool = .rectangle
    private var currentAnnotation: Annotation?
    private var currentColor: NSColor = .systemRed
    
    // Current tool properties
    var toolLineWidth: CGFloat = 3.0
    var toolOpacity: CGFloat = 1.0
    var toolCornerRadius: CGFloat = 0.0
    var toolFilled: Bool = false
    
    // Number tool counter
    private var numberCounter: Int = 1
    
    // Text input panel
    private var textInputPanel: TextInputPanel?
    private var textInputTag: Int = 0  // 1 = text, 2 = callout
    private var textInputLocation: CGPoint = .zero
    
    // Callback for property changes
    var onPropertiesNeeded: ((AnnotationTool) -> Void)?
    
    init(frame frameRect: NSRect, image: NSImage) {
        self.originalImage = image
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.originalImage = NSImage()
        super.init(coder: coder)
        setupView()
    }
    
    // Allow first mouse click to activate this window (important after screenshot)
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func setColor(_ color: NSColor) {
        currentColor = color
    }
    
    func setLineWidth(_ width: CGFloat) {
        toolLineWidth = width
    }
    
    func setOpacity(_ opacity: CGFloat) {
        toolOpacity = opacity
    }
    
    func setCornerRadius(_ radius: CGFloat) {
        toolCornerRadius = radius
    }
    
    func setFilled(_ filled: Bool) {
        toolFilled = filled
    }
    
    func resetNumberCounter() {
        numberCounter = 1
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw background image centered
        let imageRect = calculateImageRect()
        if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: imageRect)
        }
        
        // Draw all annotations
        for annotation in annotations {
            annotation.draw(in: context)
        }
        
        // Draw current annotation being drawn
        currentAnnotation?.draw(in: context)
    }
    
    private func calculateImageRect() -> CGRect {
        let imageSize = originalImage.size
        let viewSize = bounds.size
        
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        return CGRect(
            x: (viewSize.width - scaledSize.width) / 2,
            y: (viewSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
    
    // MARK: - Apply current properties to annotation
    
    private func applyCurrentProperties(to annotation: Annotation) {
        annotation.color = currentColor
        annotation.lineWidth = toolLineWidth
        annotation.opacity = toolOpacity
        annotation.cornerRadius = toolCornerRadius
        annotation.filled = toolFilled
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // Get color from parent toolbar if available
        if let toolbar = (superview as? EditorContentView)?.subviews.compactMap({ $0 as? EditorToolbar }).first {
            currentColor = toolbar.currentColor
        }
        
        switch currentTool {
        case .rectangle:
            let annotation = RectangleAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            currentAnnotation = annotation
            
        case .ellipse:
            let annotation = EllipseAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            currentAnnotation = annotation
            
        case .line:
            let annotation = LineAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            currentAnnotation = annotation
            
        case .arrow:
            let annotation = ArrowAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            currentAnnotation = annotation
            
        case .freehand:
            let annotation = FreehandAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.points = [location]
            currentAnnotation = annotation
            
        case .callout:
            showCalloutInput(at: location)
            return
            
        case .text:
            showTextInput(at: location)
            return
            
        case .number:
            let annotation = NumberAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.number = numberCounter
            annotation.startPoint = location
            
            // Save state for undo
            undoStack.append(annotations)
            redoStack.removeAll()
            annotations.append(annotation)
            numberCounter += 1
            needsDisplay = true
            return
            
        case .mosaic:
            let annotation = MosaicAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                annotation.sourceImage = cgImage
            }
            currentAnnotation = annotation
            
        case .magnifier:
            let annotation = MagnifierAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.startPoint = location
            annotation.endPoint = location
            annotation.radius = 60  // default radius, updated on drag
            if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                annotation.sourceImage = cgImage
            }
            currentAnnotation = annotation
            
        case .highlighter:
            let annotation = HighlighterAnnotation()
            annotation.color = currentColor
            annotation.points = [location]
            currentAnnotation = annotation
            
        case .blur:
            let annotation = BlurAnnotation()
            annotation.startPoint = location
            annotation.endPoint = location
            annotation.applyBlur(to: originalImage, rect: calculateImageRect())
            currentAnnotation = annotation
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if let highlighter = currentAnnotation as? HighlighterAnnotation {
            highlighter.points.append(location)
        } else if let freehand = currentAnnotation as? FreehandAnnotation {
            freehand.points.append(location)
        } else if let magnifier = currentAnnotation as? MagnifierAnnotation {
            // Drag sets the radius of the magnifier circle
            let dx = location.x - magnifier.startPoint.x
            let dy = location.y - magnifier.startPoint.y
            magnifier.radius = max(30, sqrt(dx * dx + dy * dy))
        } else {
            currentAnnotation?.endPoint = location
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let annotation = currentAnnotation else { return }
        
        // Save state for undo
        undoStack.append(annotations)
        redoStack.removeAll()
        
        annotations.append(annotation)
        currentAnnotation = nil
        needsDisplay = true
    }
    
    // MARK: - Text Input (NSPanel popup)
    
    /// Remove any existing text input panel
    private func removeTextInput() {
        textInputPanel?.close()
        textInputPanel = nil
        textInputTag = 0
    }
    
    private func showTextInput(at location: CGPoint) {
        removeTextInput()
        textInputTag = 1
        textInputLocation = location
        showTextInputPanel(at: location, placeholder: "输入文字...", fontSize: 18)
    }
    
    private func showCalloutInput(at location: CGPoint) {
        removeTextInput()
        textInputTag = 2
        textInputLocation = location
        showTextInputPanel(at: location, placeholder: "输入标注...", fontSize: 14)
    }
    
    private func showTextInputPanel(at location: CGPoint, placeholder: String, fontSize: CGFloat) {
        guard let mainWindow = self.window else { return }
        
        // Convert canvas location to screen coordinates
        let windowPoint = convert(location, to: nil)
        let screenPoint = mainWindow.convertPoint(toScreen: windowPoint)
        
        let panelWidth: CGFloat = 220
        let panelHeight: CGFloat = 36
        let panelRect = NSRect(
            x: screenPoint.x,
            y: screenPoint.y - panelHeight,
            width: panelWidth,
            height: panelHeight
        )
        
        // Create a TextInputPanel (custom subclass that can become key)
        let panel = TextInputPanel(
            contentRect: panelRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        
        // Background view
        let bg = NSView(frame: NSRect(origin: .zero, size: panelRect.size))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.white.cgColor
        bg.layer?.cornerRadius = 6
        bg.layer?.borderWidth = 1.5
        bg.layer?.borderColor = NSColor.systemBlue.cgColor
        bg.layer?.shadowColor = NSColor.black.cgColor
        bg.layer?.shadowOpacity = 0.2
        bg.layer?.shadowRadius = 8
        panel.contentView = bg
        
        // Text field inside panel
        let field = NSTextField(frame: NSRect(x: 6, y: 4, width: panelWidth - 12, height: panelHeight - 8))
        field.isBordered = false
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = currentColor
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.placeholderString = placeholder
        field.delegate = self
        field.target = self
        field.action = #selector(textInputComplete(_:))
        bg.addSubview(field)
        
        textInputPanel = panel
        
        // Show panel and make it key so it receives keyboard input
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }
    
    @objc private func textInputComplete(_ sender: Any?) {
        guard let panel = textInputPanel,
              let field = panel.contentView?.subviews.compactMap({ $0 as? NSTextField }).first,
              !field.stringValue.isEmpty else {
            removeTextInput()
            return
        }
        
        let text = field.stringValue
        let loc = textInputLocation
        
        if textInputTag == 2 {
            // Callout
            let annotation = CalloutAnnotation()
            applyCurrentProperties(to: annotation)
            annotation.cornerRadius = 8
            annotation.text = text
            annotation.color = currentColor
            annotation.startPoint = loc
            annotation.endPoint = CGPoint(x: loc.x + 150, y: loc.y + 80)
            undoStack.append(annotations)
            redoStack.removeAll()
            annotations.append(annotation)
        } else {
            // Text
            let annotation = TextAnnotation()
            annotation.color = currentColor
            annotation.text = text
            annotation.startPoint = CGPoint(x: loc.x, y: loc.y + 12)
            undoStack.append(annotations)
            redoStack.removeAll()
            annotations.append(annotation)
        }
        
        removeTextInput()
        // Restore focus to main window
        self.window?.makeKeyAndOrderFront(nil)
        needsDisplay = true
    }
    
    // MARK: - NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            textInputComplete(control)
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            removeTextInput()
            return true
        }
        return false
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(annotations)
        annotations = undoStack.removeLast()
        needsDisplay = true
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(annotations)
        annotations = redoStack.removeLast()
        needsDisplay = true
    }
    
    // MARK: - Keyboard Shortcuts
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z":
                if event.modifierFlags.contains(.shift) {
                    redo()
                } else {
                    undo()
                }
            default:
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Export
    
    func renderFinalImage() -> NSImage? {
        let imageRect = calculateImageRect()
        let size = originalImage.size
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        // Draw original image
        if let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        
        // Scale factor for annotations
        let scaleX = size.width / imageRect.width
        let scaleY = size.height / imageRect.height
        
        // Transform annotations to image coordinates
        context.saveGState()
        context.translateBy(x: -imageRect.origin.x * scaleX, y: -imageRect.origin.y * scaleY)
        context.scaleBy(x: scaleX, y: scaleY)
        
        for annotation in annotations {
            annotation.draw(in: context)
        }
        
        context.restoreGState()
        image.unlockFocus()
        
        return image
    }
    
    func getFinalImage() -> NSImage? {
        return renderFinalImage()
    }
}
