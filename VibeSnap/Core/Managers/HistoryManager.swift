import Foundation
import AppKit

/// Manager for storing and retrieving screenshot history
final class HistoryManager {
    static let shared = HistoryManager()
    
    private let maxHistoryCount = 50
    private var historyItems: [HistoryItem] = []
    private let historyDirectory: URL
    
    private init() {
        // Create history directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        historyDirectory = appSupport.appendingPathComponent("VibeSnap/History", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        
        // Load existing history
        loadHistory()
    }
    
    /// Add a new screenshot to history
    func addToHistory(image: NSImage, rect: CGRect) {
        let timestamp = Date()
        let filename = "screenshot_\(Int(timestamp.timeIntervalSince1970)).png"
        let fileURL = historyDirectory.appendingPathComponent(filename)
        
        // Save image to disk
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }
        
        // Create history item (no thumbnail yet - lazy load)
        let item = HistoryItem(
            id: UUID(),
            timestamp: timestamp,
            fileURL: fileURL,
            captureRect: rect
        )
        
        historyItems.insert(item, at: 0)
        
        // Generate thumbnail asynchronously for cache
        ThumbnailCache.shared.getThumbnail(for: item) { _ in }
        
        // Trim old items
        while historyItems.count > maxHistoryCount {
            let removed = historyItems.removeLast()
            try? FileManager.default.removeItem(at: removed.fileURL)
        }
        
        saveHistoryMetadata()
    }
    
    /// Get all history items
    func getHistory() -> [HistoryItem] {
        return historyItems
    }
    
    /// Get thumbnail for a history item (async)
    func getThumbnail(for item: HistoryItem, completion: @escaping (NSImage?) -> Void) {
        ThumbnailCache.shared.getThumbnail(for: item, completion: completion)
    }
    
    /// Prefetch thumbnails for visible items
    func prefetchThumbnails(for items: [HistoryItem]) {
        ThumbnailCache.shared.prefetchThumbnails(for: items)
    }
    
    /// Get full image for a history item
    func getImage(for item: HistoryItem) -> NSImage? {
        return NSImage(contentsOf: item.fileURL)
    }
    
    /// Copy image to clipboard
    func copyToClipboard(item: HistoryItem) {
        guard let image = getImage(for: item) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    /// Delete a history item
    func deleteItem(_ item: HistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: item.fileURL)
        saveHistoryMetadata()
    }
    
    /// Clear all history
    func clearHistory() {
        for item in historyItems {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        historyItems.removeAll()
        ThumbnailCache.shared.clearCache()
        saveHistoryMetadata()
    }
    
    // MARK: - Private Methods
    
    private func createThumbnail(from image: NSImage, maxSize: CGFloat = 100) -> NSImage {
        let originalSize = image.size
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    private func loadHistory() {
        let metadataURL = historyDirectory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let items = try? JSONDecoder().decode([HistoryItemMetadata].self, from: data) else {
            return
        }
        
        // Load metadata only - thumbnails will be loaded on demand
        historyItems = items.compactMap { metadata in
            let fileURL = historyDirectory.appendingPathComponent(metadata.filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            
            return HistoryItem(
                id: metadata.id,
                timestamp: metadata.timestamp,
                fileURL: fileURL,
                captureRect: metadata.captureRect
            )
        }
    }
    
    private func saveHistoryMetadata() {
        let metadata = historyItems.map { item in
            HistoryItemMetadata(
                id: item.id,
                timestamp: item.timestamp,
                filename: item.fileURL.lastPathComponent,
                captureRect: item.captureRect
            )
        }
        
        let metadataURL = historyDirectory.appendingPathComponent("metadata.json")
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
}

/// Represents a screenshot in history
struct HistoryItem: Identifiable {
    let id: UUID
    let timestamp: Date
    let fileURL: URL
    let captureRect: CGRect
}

/// Metadata for persistence
struct HistoryItemMetadata: Codable {
    let id: UUID
    let timestamp: Date
    let filename: String
    let captureRect: CGRect
}
