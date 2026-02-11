import AppKit

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
    
    // Text input field for text tool
    private var textField: NSTextField?
    
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
    
    // MARK: - Text Input
    
    private func showTextInput(at location: CGPoint) {
        // Remove any existing text field
        textField?.removeFromSuperview()
        textField = nil
        
        // Create text field at the clicked location
        textField = NSTextField(frame: CGRect(x: location.x, y: location.y - 12, width: 200, height: 24))
        textField?.isBordered = true
        textField?.backgroundColor = .white
        textField?.font = .systemFont(ofSize: 18)
        textField?.focusRingType = .none
        textField?.delegate = self
        textField?.target = self
        textField?.action = #selector(textInputComplete)
        textField?.isEditable = true
        textField?.isSelectable = true
        textField?.placeholderString = "输入文字..."
        
        // Store the location for later use
        textField?.tag = 1  // Mark as text tool
        
        addSubview(textField!)
        
        // CRITICAL FIX: Ensure the editor window becomes key and the text field gets focus
        // This prevents keyboard input from going to the previous window
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let field = self.textField, let window = self.window else { return }
            
            // Force app activation and window focus
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            
            // Give focus to the text field
            window.makeFirstResponder(field)
            
            // Double-check that the field has focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field, weak window] in
                if let field = field, let window = window {
                    window.makeFirstResponder(field)
                }
            }
        }
    }
    
    @objc private func textInputComplete() {
        guard let field = textField, !field.stringValue.isEmpty else {
            textField?.removeFromSuperview()
            textField = nil
            return
        }
        
        let annotation = TextAnnotation()
        annotation.color = currentColor
        annotation.text = field.stringValue
        annotation.startPoint = CGPoint(x: field.frame.origin.x, y: field.frame.origin.y + 12)
        
        // Save state for undo
        undoStack.append(annotations)
        redoStack.removeAll()
        
        annotations.append(annotation)
        
        textField?.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }
    
    private func showCalloutInput(at location: CGPoint) {
        // Remove any existing text field
        textField?.removeFromSuperview()
        textField = nil
        
        // Create a larger text field for callout
        textField = NSTextField(frame: CGRect(x: location.x, y: location.y - 12, width: 150, height: 60))
        textField?.isBordered = true
        textField?.backgroundColor = .white
        textField?.font = .systemFont(ofSize: 14)
        textField?.focusRingType = .none
        textField?.delegate = self
        textField?.target = self
        textField?.action = #selector(calloutInputComplete)
        textField?.isEditable = true
        textField?.isSelectable = true
        textField?.placeholderString = "输入标注文字..."
        
        // Store the location for later use
        textField?.tag = 2  // Mark as callout tool
        
        addSubview(textField!)
        
        // CRITICAL FIX: Ensure the editor window becomes key and the text field gets focus
        // This prevents keyboard input from going to the previous window
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let field = self.textField, let window = self.window else { return }
            
            // Force app activation and window focus
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            
            // Give focus to the text field
            window.makeFirstResponder(field)
            
            // Double-check that the field has focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field, weak window] in
                if let field = field, let window = window {
                    window.makeFirstResponder(field)
                }
            }
        }
    }
    
    @objc private func calloutInputComplete() {
        guard let field = textField, !field.stringValue.isEmpty else {
            textField?.removeFromSuperview()
            textField = nil
            return
        }
        
        let annotation = CalloutAnnotation()
        applyCurrentProperties(to: annotation)
        annotation.cornerRadius = 8
        annotation.text = field.stringValue
        annotation.color = currentColor
        
        // Position callout based on text field location
        let location = field.frame.origin
        annotation.startPoint = location
        annotation.endPoint = CGPoint(x: location.x + 150, y: location.y + 80)
        
        // Save state for undo
        undoStack.append(annotations)
        redoStack.removeAll()
        
        annotations.append(annotation)
        
        textField?.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }
    
    // MARK: - NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // User pressed Return key - trigger the appropriate completion
            if let field = textField, field.action == #selector(calloutInputComplete) {
                calloutInputComplete()
            } else {
                textInputComplete()
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // User pressed Escape key
            textField?.removeFromSuperview()
            textField = nil
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
