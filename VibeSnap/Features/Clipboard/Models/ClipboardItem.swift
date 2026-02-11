import Foundation
import AppKit

// MARK: - Text Clip

/// Represents a text clipboard item
struct TextClipItem: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var isPinned: Bool
    let text: String
    
    /// Create a new text clip from current clipboard content
    init(text: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.isPinned = false
        self.text = text
    }
    
    /// Restore a text clip from persisted data
    init(id: UUID, createdAt: Date, isPinned: Bool, text: String) {
        self.id = id
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.text = text
    }
    
    static func == (lhs: TextClipItem, rhs: TextClipItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Image Clip

/// Represents an image clipboard item
struct ImageClipItem: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var isPinned: Bool
    let imageData: Data
    let width: Int
    let height: Int
    
    /// Initialize from raw image data with size limit
    init?(imageData: Data, maxSize: Int = 50_000_000) {
        // Limit image size to prevent memory issues (50MB default)
        guard imageData.count <= maxSize else { return nil }
        guard let nsImage = NSImage(data: imageData) else { return nil }
        guard let representation = nsImage.representations.first else { return nil }
        
        self.id = UUID()
        self.createdAt = Date()
        self.isPinned = false
        
        // Compress large images (>10MB) to JPEG to save storage
        if imageData.count > 10_000_000 {
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                self.imageData = jpegData
            } else {
                self.imageData = imageData
            }
        } else {
            self.imageData = imageData
        }
        
        self.width = representation.pixelsWide > 0 ? representation.pixelsWide : Int(nsImage.size.width)
        self.height = representation.pixelsHigh > 0 ? representation.pixelsHigh : Int(nsImage.size.height)
    }
    
    /// Restore an image clip from persisted data
    init(id: UUID, createdAt: Date, isPinned: Bool, imageData: Data, width: Int, height: Int) {
        self.id = id
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.imageData = imageData
        self.width = width
        self.height = height
    }
    
    /// Generate a thumbnail on-demand
    func thumbnail(size: CGSize = CGSize(width: 64, height: 64)) -> NSImage? {
        guard let original = NSImage(data: imageData) else { return nil }
        
        let originalSize = original.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        
        let aspectRatio = originalSize.width / originalSize.height
        let targetSize: CGSize
        
        if aspectRatio > 1 {
            targetSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            targetSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        original.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    /// Get the full-size image
    func fullImage() -> NSImage? {
        NSImage(data: imageData)
    }
    
    static func == (lhs: ImageClipItem, rhs: ImageClipItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Unified Clip Type

/// Unified container for both text and image clipboard items
enum ClipboardItemType: Identifiable, Equatable {
    case text(TextClipItem)
    case image(ImageClipItem)
    
    var id: UUID {
        switch self {
        case .text(let clip): return clip.id
        case .image(let clip): return clip.id
        }
    }
    
    var createdAt: Date {
        switch self {
        case .text(let clip): return clip.createdAt
        case .image(let clip): return clip.createdAt
        }
    }
    
    var isPinned: Bool {
        get {
            switch self {
            case .text(let clip): return clip.isPinned
            case .image(let clip): return clip.isPinned
            }
        }
        set {
            switch self {
            case .text(var clip):
                clip.isPinned = newValue
                self = .text(clip)
            case .image(var clip):
                clip.isPinned = newValue
                self = .image(clip)
            }
        }
    }
    
    static func == (lhs: ClipboardItemType, rhs: ClipboardItemType) -> Bool {
        lhs.id == rhs.id
    }
}
