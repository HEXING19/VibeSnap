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
    case rectangle = 0
    case ellipse = 1
    case line = 2
    case arrow = 3
    case freehand = 4
    case callout = 5
    case text = 6
    case number = 7
    case mosaic = 8
    case magnifier = 9
    case highlighter = 10
    case blur = 11  // Keep for backward compatibility
}

/// Base class for all annotations with configurable properties
class Annotation {
    var color: NSColor = .systemRed
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    
    // Common properties
    var lineWidth: CGFloat = 3.0
    var opacity: CGFloat = 1.0
    var cornerRadius: CGFloat = 0.0
    var filled: Bool = false
    
    func draw(in context: CGContext) {
        // Override in subclasses
    }
    
    func getRect() -> CGRect {
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }
}

/// Arrow annotation with configurable properties
class ArrowAnnotation: Annotation {
    var curved: Bool = false  // Whether to use curved line
    
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        let path = CGMutablePath()
        path.move(to: startPoint)
        
        if curved {
            // Draw curved arrow line using bezier
            let midX = (startPoint.x + endPoint.x) / 2
            let midY = (startPoint.y + endPoint.y) / 2
            let dx = endPoint.x - startPoint.x
            let dy = endPoint.y - startPoint.y
            let controlPoint = CGPoint(x: midX - dy * 0.2, y: midY + dx * 0.2)
            path.addQuadCurve(to: endPoint, control: controlPoint)
            context.addPath(path)
            context.strokePath()
            
            // Draw arrowhead based on curve direction
            let angle = atan2(endPoint.y - controlPoint.y, endPoint.x - controlPoint.x)
            drawArrowhead(in: context, at: endPoint, angle: angle)
        } else {
            // Draw straight arrow
            path.addLine(to: endPoint)
            context.addPath(path)
            context.strokePath()
            
            let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
            drawArrowhead(in: context, at: endPoint, angle: angle)
        }
        
        context.restoreGState()
    }
    
    private func drawArrowhead(in context: CGContext, at point: CGPoint, angle: CGFloat) {
        let arrowLength: CGFloat = lineWidth * 5
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = CGMutablePath()
        arrowPath.move(to: point)
        arrowPath.addLine(to: CGPoint(
            x: point.x - arrowLength * cos(angle - arrowAngle),
            y: point.y - arrowLength * sin(angle - arrowAngle)
        ))
        arrowPath.move(to: point)
        arrowPath.addLine(to: CGPoint(
            x: point.x - arrowLength * cos(angle + arrowAngle),
            y: point.y - arrowLength * sin(angle + arrowAngle)
        ))
        
        context.addPath(arrowPath)
        context.strokePath()
    }
}

/// Rectangle annotation with corner radius and fill support
class RectangleAnnotation: Annotation {
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        
        let rect = getRect()
        let path: CGPath
        
        if cornerRadius > 0 {
            path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        } else {
            path = CGPath(rect: rect, transform: nil)
        }
        
        if filled {
            context.setFillColor(color.cgColor)
            context.addPath(path)
            context.fillPath()
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.addPath(path)
            context.strokePath()
        }
        
        context.restoreGState()
    }
}

/// Ellipse annotation with fill support
class EllipseAnnotation: Annotation {
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        
        let rect = getRect()
        
        if filled {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: rect)
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect)
        }
        
        context.restoreGState()
    }
}

/// Line annotation with dash support
class LineAnnotation: Annotation {
    var dashed: Bool = false
    var dashPattern: [CGFloat] = [8, 4]
    
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        if dashed {
            context.setLineDash(phase: 0, lengths: dashPattern)
        }
        
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
        
        context.restoreGState()
    }
}

/// Freehand drawing annotation
class FreehandAnnotation: Annotation {
    var points: [CGPoint] = []
    
    override func draw(in context: CGContext) {
        guard points.count > 1 else { return }
        
        context.saveGState()
        context.setAlpha(opacity)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let path = CGMutablePath()
        path.move(to: points[0])
        
        // Use quadratic curves for smoother lines
        for i in 1..<points.count {
            if i < points.count - 1 {
                let midPoint = CGPoint(
                    x: (points[i].x + points[i + 1].x) / 2,
                    y: (points[i].y + points[i + 1].y) / 2
                )
                path.addQuadCurve(to: midPoint, control: points[i])
            } else {
                path.addLine(to: points[i])
            }
        }
        
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}

/// Callout annotation (speech bubble with text)
class CalloutAnnotation: Annotation {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: 14, weight: .medium)
    var backgroundColor: NSColor = .white
    var textColor: NSColor = .black
    var tailPosition: CGPoint = .zero  // Where the tail points to
    
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        
        let rect = getRect()
        let padding: CGFloat = 8
        let tailHeight: CGFloat = 15
        
        // Draw bubble background
        let bubblePath = CGMutablePath()
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY + tailHeight, 
                                 width: rect.width, height: rect.height - tailHeight)
        
        bubblePath.addRoundedRect(in: bubbleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        
        // Draw tail
        let tailX = bubbleRect.midX
        bubblePath.move(to: CGPoint(x: tailX - 10, y: bubbleRect.minY))
        bubblePath.addLine(to: CGPoint(x: tailX, y: rect.minY))
        bubblePath.addLine(to: CGPoint(x: tailX + 10, y: bubbleRect.minY))
        
        context.setFillColor(backgroundColor.cgColor)
        context.addPath(bubblePath)
        context.fillPath()
        
        // Draw border
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.addPath(bubblePath)
        context.strokePath()
        
        // Draw text
        if !text.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let textRect = bubbleRect.insetBy(dx: padding, dy: padding)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            text.draw(in: textRect, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }
        
        context.restoreGState()
    }
}

/// Number annotation (circled number)
class NumberAnnotation: Annotation {
    var number: Int = 1
    var fontSize: CGFloat = 16
    
    override func draw(in context: CGContext) {
        context.saveGState()
        context.setAlpha(opacity)
        
        // Calculate circle size based on number digits
        let text = "\(number)"
        let size = max(fontSize * 2, CGFloat(text.count) * fontSize + 8)
        let circleRect = CGRect(
            x: startPoint.x - size / 2,
            y: startPoint.y - size / 2,
            width: size,
            height: size
        )
        
        // Draw filled circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)
        
        // Draw number
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: circleRect.midX - textSize.width / 2,
            y: circleRect.midY - textSize.height / 2
        )
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(at: textPoint, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
    }
}

/// Mosaic/Pixelate annotation
class MosaicAnnotation: Annotation {
    var blockSize: CGFloat = 10
    var sourceImage: CGImage?
    
    override func draw(in context: CGContext) {
        guard let source = sourceImage else { return }
        
        context.saveGState()
        
        let rect = getRect()
        
        // Create pixelated version of the region
        let ciImage = CIImage(cgImage: source)
        let filter = CIFilter(name: "CIPixellate")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(blockSize, forKey: kCIInputScaleKey)
        
        if let output = filter.outputImage {
            let ciContext = CIContext()
            if let pixelated = ciContext.createCGImage(output, from: ciImage.extent) {
                context.clip(to: rect)
                context.draw(pixelated, in: context.boundingBoxOfClipPath)
            }
        }
        
        context.restoreGState()
    }
}

/// Magnifier annotation
class MagnifierAnnotation: Annotation {
    var zoomLevel: CGFloat = 2.0
    var borderWidth: CGFloat = 3
    var sourceImage: CGImage?
    
    override func draw(in context: CGContext) {
        guard let source = sourceImage else { return }
        
        context.saveGState()
        context.setAlpha(opacity)
        
        let rect = getRect()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Create circular clip
        context.addEllipse(in: rect)
        context.clip()
        
        // Calculate source rect (smaller area to zoom in)
        let sourceSize = CGSize(width: rect.width / zoomLevel, height: rect.height / zoomLevel)
        let sourceRect = CGRect(
            x: center.x - sourceSize.width / 2,
            y: center.y - sourceSize.height / 2,
            width: sourceSize.width,
            height: sourceSize.height
        )
        
        // Draw zoomed portion
        context.draw(source, in: rect)
        
        context.restoreGState()
        
        // Draw border
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(borderWidth)
        context.strokeEllipse(in: rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        context.restoreGState()
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
