import AppKit
import SwiftUI

/// Modeless floating editor window for image annotations
class EditorWindow: NSWindow {
    private var editorView: EditorContentView?
    private var originalImage: NSImage?
    var onSave: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?
    
    init(image: NSImage) {
        self.originalImage = image
        
        // Calculate window size based on image, with max constraints
        let maxSize: CGFloat = 800
        var windowSize = image.size
        if windowSize.width > maxSize || windowSize.height > maxSize {
            let scale = min(maxSize / windowSize.width, maxSize / windowSize.height)
            windowSize = CGSize(width: windowSize.width * scale, height: windowSize.height * scale)
        }
        
        // Add space for toolbar
        let toolbarHeight: CGFloat = 50
        windowSize.height += toolbarHeight
        
        let screenRect = NSScreen.main?.frame ?? CGRect.zero
        let windowRect = CGRect(
            x: (screenRect.width - windowSize.width) / 2,
            y: (screenRect.height - windowSize.height) / 2,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupEditorView(image: image, toolbarHeight: toolbarHeight)
    }
    
    private func setupWindow() {
        self.title = "VibeSnap Editor"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces]
    }
    
    private func setupEditorView(image: NSImage, toolbarHeight: CGFloat) {
        editorView = EditorContentView(
            frame: NSRect(origin: .zero, size: self.frame.size),
            image: image,
            toolbarHeight: toolbarHeight,
            editorWindow: self
        )
        self.contentView = editorView
    }
    
    func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func saveAndClose() {
        if let editedImage = editorView?.getEditedImage() {
            onSave?(editedImage)
        }
        self.orderOut(nil)
    }
    
    override func close() {
        onCancel?()
        super.close()
    }
}

/// Main editor content view containing toolbar and canvas
class EditorContentView: NSView {
    weak var editorWindow: EditorWindow?
    private var toolbar: EditorToolbar?
    private var canvas: CanvasView?
    private let toolbarHeight: CGFloat
    
    init(frame frameRect: NSRect, image: NSImage, toolbarHeight: CGFloat, editorWindow: EditorWindow) {
        self.toolbarHeight = toolbarHeight
        self.editorWindow = editorWindow
        super.init(frame: frameRect)
        setupViews(image: image)
    }
    
    required init?(coder: NSCoder) {
        self.toolbarHeight = 50
        super.init(coder: coder)
    }
    
    private func setupViews(image: NSImage) {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        
        // Toolbar at top
        toolbar = EditorToolbar(
            frame: CGRect(x: 0, y: bounds.height - toolbarHeight, width: bounds.width, height: toolbarHeight)
        )
        toolbar?.autoresizingMask = [.width, .minYMargin]
        toolbar?.onToolSelected = { [weak self] tool in
            self?.canvas?.currentTool = tool
        }
        toolbar?.onUndo = { [weak self] in
            self?.canvas?.undo()
        }
        toolbar?.onRedo = { [weak self] in
            self?.canvas?.redo()
        }
        toolbar?.onDone = { [weak self] in
            self?.editorWindow?.saveAndClose()
        }
        addSubview(toolbar!)
        
        // Canvas below toolbar
        canvas = CanvasView(
            frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - toolbarHeight),
            image: image
        )
        canvas?.autoresizingMask = [.width, .height]
        addSubview(canvas!)
    }
    
    func getEditedImage() -> NSImage? {
        return canvas?.renderFinalImage()
    }
}

/// Toolbar with annotation tools
class EditorToolbar: NSView {
    var onToolSelected: ((AnnotationTool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onDone: (() -> Void)?
    
    private var selectedTool: AnnotationTool = .arrow
    private var toolButtons: [NSButton] = []
    private var colorWell: NSColorWell?
    
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
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.95).cgColor
        
        // Tool buttons
        let tools: [(AnnotationTool, String, String)] = [
            (.arrow, "arrow.up.right", "Arrow"),
            (.rectangle, "rectangle", "Rectangle"),
            (.highlighter, "highlighter", "Highlighter"),
            (.blur, "aqi.medium", "Blur"),
            (.text, "textformat", "Text")
        ]
        
        var xOffset: CGFloat = 16
        for (tool, iconName, tooltip) in tools {
            let button = createToolButton(icon: iconName, tooltip: tooltip, tag: tool.rawValue)
            button.frame.origin = CGPoint(x: xOffset, y: (frame.height - 32) / 2)
            addSubview(button)
            toolButtons.append(button)
            xOffset += 44
        }
        
        // Color picker
        colorWell = NSColorWell(frame: CGRect(x: xOffset + 16, y: (frame.height - 28) / 2, width: 28, height: 28))
        colorWell?.color = NSColor.systemRed
        colorWell?.action = #selector(colorChanged(_:))
        colorWell?.target = self
        addSubview(colorWell!)
        
        // Undo/Redo buttons
        let undoButton = createActionButton(icon: "arrow.uturn.backward", action: #selector(undoClicked))
        undoButton.frame.origin = CGPoint(x: frame.width - 160, y: (frame.height - 32) / 2)
        undoButton.autoresizingMask = [.minXMargin]
        addSubview(undoButton)
        
        let redoButton = createActionButton(icon: "arrow.uturn.forward", action: #selector(redoClicked))
        redoButton.frame.origin = CGPoint(x: frame.width - 116, y: (frame.height - 32) / 2)
        redoButton.autoresizingMask = [.minXMargin]
        addSubview(redoButton)
        
        // Done button
        let doneButton = NSButton(frame: CGRect(x: frame.width - 72, y: (frame.height - 32) / 2, width: 60, height: 32))
        doneButton.title = "Done"
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(doneClicked)
        doneButton.autoresizingMask = [.minXMargin]
        addSubview(doneButton)
        
        // Select first tool
        selectTool(toolButtons.first)
    }
    
    private func createToolButton(icon: String, tooltip: String, tag: Int) -> NSButton {
        let button = NSButton(frame: CGRect(x: 0, y: 0, width: 36, height: 32))
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.toolTip = tooltip
        button.tag = tag
        button.target = self
        button.action = #selector(toolClicked(_:))
        button.contentTintColor = .white
        return button
    }
    
    private func createActionButton(icon: String, action: Selector) -> NSButton {
        let button = NSButton(frame: CGRect(x: 0, y: 0, width: 36, height: 32))
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.contentTintColor = .white
        return button
    }
    
    @objc private func toolClicked(_ sender: NSButton) {
        selectTool(sender)
        if let tool = AnnotationTool(rawValue: sender.tag) {
            onToolSelected?(tool)
        }
    }
    
    private func selectTool(_ button: NSButton?) {
        for btn in toolButtons {
            btn.contentTintColor = .white
        }
        button?.contentTintColor = .systemBlue
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        // Color will be read from colorWell when drawing
    }
    
    @objc private func undoClicked() {
        onUndo?()
    }
    
    @objc private func redoClicked() {
        onRedo?()
    }
    
    @objc private func doneClicked() {
        onDone?()
    }
    
    var currentColor: NSColor {
        return colorWell?.color ?? .systemRed
    }
}

/// Annotation tool enum
enum AnnotationTool: Int {
    case arrow = 0
    case rectangle = 1
    case highlighter = 2
    case blur = 3
    case text = 4
}

/// Base class for all annotations
class Annotation {
    var color: NSColor = .systemRed
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    
    func draw(in context: CGContext) {
        // Override in subclasses
    }
}

/// Arrow annotation with bezier curve
class ArrowAnnotation: Annotation {
    override func draw(in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        
        // Draw curved arrow line using bezier
        let path = CGMutablePath()
        path.move(to: startPoint)
        
        // Calculate control point for curve
        let midX = (startPoint.x + endPoint.x) / 2
        let midY = (startPoint.y + endPoint.y) / 2
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let controlPoint = CGPoint(x: midX - dy * 0.2, y: midY + dx * 0.2)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        context.addPath(path)
        context.strokePath()
        
        // Draw arrowhead
        let angle = atan2(endPoint.y - controlPoint.y, endPoint.x - controlPoint.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = CGMutablePath()
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        ))
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        ))
        
        context.addPath(arrowPath)
        context.strokePath()
    }
}

/// Rectangle annotation
class RectangleAnnotation: Annotation {
    override func draw(in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3)
        
        let rect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
        
        context.stroke(rect)
    }
}

/// Highlighter annotation (semi-transparent)
class HighlighterAnnotation: Annotation {
    var points: [CGPoint] = []
    
    override func draw(in context: CGContext) {
        guard points.count > 1 else { return }
        
        context.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(20)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setBlendMode(.multiply)
        
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        context.addPath(path)
        context.strokePath()
    }
}

/// Blur annotation
class BlurAnnotation: Annotation {
    var blurredImage: CGImage?
    
    func applyBlur(to image: NSImage, rect: CGRect) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIPixellate")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(10, forKey: kCIInputScaleKey)
        
        if let output = filter.outputImage {
            let context = CIContext()
            if let blurred = context.createCGImage(output, from: ciImage.extent) {
                blurredImage = blurred
            }
        }
    }
    
    override func draw(in context: CGContext) {
        guard let blurred = blurredImage else { return }
        
        let rect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
        
        context.saveGState()
        context.clip(to: rect)
        // Draw the blurred portion
        context.draw(blurred, in: context.boundingBoxOfClipPath)
        context.restoreGState()
    }
}

/// Text annotation
class TextAnnotation: Annotation {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: 18, weight: .medium)
    
    override func draw(in context: CGContext) {
        guard !text.isEmpty else { return }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(at: startPoint, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}
