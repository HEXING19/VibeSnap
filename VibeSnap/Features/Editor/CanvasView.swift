import AppKit

/// Canvas view for drawing annotations on the screenshot
class CanvasView: NSView {
    private var originalImage: NSImage
    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    
    var currentTool: AnnotationTool = .arrow
    private var currentAnnotation: Annotation?
    private var currentColor: NSColor = .systemRed
    
    // Text input field for text tool
    private var textField: NSTextField?
    
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
        layer?.backgroundColor = NSColor.darkGray.cgColor
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
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // Get color from parent toolbar
        if let toolbar = (superview as? EditorContentView)?.subviews.compactMap({ $0 as? EditorToolbar }).first {
            currentColor = toolbar.currentColor
        }
        
        switch currentTool {
        case .arrow:
            let annotation = ArrowAnnotation()
            annotation.color = currentColor
            annotation.startPoint = location
            annotation.endPoint = location
            currentAnnotation = annotation
            
        case .rectangle:
            let annotation = RectangleAnnotation()
            annotation.color = currentColor
            annotation.startPoint = location
            annotation.endPoint = location
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
            
        case .text:
            showTextInput(at: location)
            return
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if let highlighter = currentAnnotation as? HighlighterAnnotation {
            highlighter.points.append(location)
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
        textField?.removeFromSuperview()
        
        textField = NSTextField(frame: CGRect(x: location.x, y: location.y - 12, width: 200, height: 24))
        textField?.isBordered = true
        textField?.backgroundColor = .white
        textField?.font = .systemFont(ofSize: 18)
        textField?.target = self
        textField?.action = #selector(textInputComplete)
        
        addSubview(textField!)
        textField?.becomeFirstResponder()
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
}
