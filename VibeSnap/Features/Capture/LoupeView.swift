import AppKit

/// Circular magnifying loupe view for pixel-perfect selection
class LoupeView: NSView {
    private let magnification: CGFloat = 4.0
    private let gridLineColor = NSColor.gray.withAlphaComponent(0.3)
    private var capturedImage: NSImage?
    private var targetPoint: CGPoint = .zero
    
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
        layer?.cornerRadius = frame.width / 2
        layer?.masksToBounds = true
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.white.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.5
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
    }
    
    func updateMagnification(at point: CGPoint) {
        targetPoint = point
        captureScreenAt(point)
        needsDisplay = true
    }
    
    private func captureScreenAt(_ point: CGPoint) {
        // Capture a small area around the cursor for magnification
        let captureSize = frame.size.width / magnification
        let captureRect = CGRect(
            x: point.x - captureSize / 2,
            y: point.y - captureSize / 2,
            width: captureSize,
            height: captureSize
        )
        
        // Use CGWindowListCreateImage for quick screen capture
        if let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            capturedImage = NSImage(cgImage: cgImage, size: captureRect.size)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw background
        NSColor.black.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        
        // Draw magnified image
        if let image = capturedImage {
            NSGraphicsContext.saveGraphicsState()
            
            // Clip to circle
            let circlePath = NSBezierPath(ovalIn: bounds)
            circlePath.addClip()
            
            // Draw the captured image scaled up
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
            
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Draw pixel grid
        drawPixelGrid()
        
        // Draw crosshair
        drawCrosshair()
        
        // Draw color info at bottom
        drawColorInfo()
    }
    
    private func drawPixelGrid() {
        gridLineColor.setStroke()
        
        let gridSize = magnification
        let path = NSBezierPath()
        path.lineWidth = 0.5
        
        // Vertical lines
        var x: CGFloat = 0
        while x < bounds.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.line(to: CGPoint(x: x, y: bounds.height))
            x += gridSize
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y < bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.line(to: CGPoint(x: bounds.width, y: y))
            y += gridSize
        }
        
        path.stroke()
    }
    
    private func drawCrosshair() {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let crosshairSize: CGFloat = 10
        
        NSColor.red.withAlphaComponent(0.8).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        
        // Horizontal line
        path.move(to: CGPoint(x: centerX - crosshairSize, y: centerY))
        path.line(to: CGPoint(x: centerX + crosshairSize, y: centerY))
        
        // Vertical line
        path.move(to: CGPoint(x: centerX, y: centerY - crosshairSize))
        path.line(to: CGPoint(x: centerX, y: centerY + crosshairSize))
        
        path.stroke()
    }
    
    private func drawColorInfo() {
        // Get center pixel color
        guard let image = capturedImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let centerX = Int(cgImage.width / 2)
        let centerY = Int(cgImage.height / 2)
        
        // Create bitmap context to get pixel color
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: [UInt8] = [0, 0, 0, 0]
        
        if let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            context.draw(cgImage, in: CGRect(x: -centerX, y: -centerY, width: cgImage.width, height: cgImage.height))
        }
        
        let hexColor = String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])
        
        // Draw color info background
        let infoRect = CGRect(x: 0, y: 0, width: bounds.width, height: 20)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(rect: infoRect).fill()
        
        // Draw hex color text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        hexColor.draw(at: CGPoint(x: 8, y: 4), withAttributes: attributes)
        
        // Draw color swatch
        let swatchRect = CGRect(x: bounds.width - 20, y: 4, width: 12, height: 12)
        NSColor(red: CGFloat(pixel[0])/255, green: CGFloat(pixel[1])/255, blue: CGFloat(pixel[2])/255, alpha: 1).setFill()
        NSBezierPath(rect: swatchRect).fill()
        NSColor.white.setStroke()
        NSBezierPath(rect: swatchRect).stroke()
    }
}
