import Foundation
import AppKit

/// High-performance thumbnail cache with memory and disk storage
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    // MARK: - Properties
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let diskCacheDirectory: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.vibesnap.thumbnailcache", qos: .userInitiated)
    
    // Cache configuration
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxMemoryCacheCount = 50
    private let thumbnailSize: CGFloat = 160
    
    // Track pending requests to avoid duplicates
    private var pendingRequests: [String: [(NSImage?) -> Void]] = [:]
    private let requestsLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        // Setup memory cache
        memoryCache.countLimit = maxMemoryCacheCount
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Setup disk cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        diskCacheDirectory = appSupport.appendingPathComponent("VibeSnap/ThumbnailCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: NSNotification.Name("NSApplicationDidReceiveMemoryWarning"),
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Get thumbnail for a history item, using cache or generating if needed
    func getThumbnail(for item: HistoryItem, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = item.id.uuidString
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            completion(cachedImage)
            return
        }
        
        // Check if request is already pending
        requestsLock.lock()
        if var callbacks = pendingRequests[cacheKey] {
            callbacks.append(completion)
            pendingRequests[cacheKey] = callbacks
            requestsLock.unlock()
            return
        } else {
            pendingRequests[cacheKey] = [completion]
            requestsLock.unlock()
        }
        
        // Load from disk cache or generate
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Try disk cache
            if let thumbnail = self.loadFromDiskCache(key: cacheKey) {
                self.cacheInMemory(thumbnail, key: cacheKey)
                self.completeRequest(key: cacheKey, image: thumbnail)
                return
            }
            
            // Generate new thumbnail
            guard let fullImage = NSImage(contentsOf: item.fileURL) else {
                self.completeRequest(key: cacheKey, image: nil)
                return
            }
            
            let thumbnail = self.createThumbnail(from: fullImage)
            
            // Save to both caches
            self.saveToDiskCache(thumbnail, key: cacheKey)
            self.cacheInMemory(thumbnail, key: cacheKey)
            
            self.completeRequest(key: cacheKey, image: thumbnail)
        }
    }
    
    /// Prefetch thumbnails for multiple items
    func prefetchThumbnails(for items: [HistoryItem]) {
        for item in items {
            getThumbnail(for: item) { _ in
                // Prefetch only, no action needed
            }
        }
    }
    
    /// Cancel pending request for an item
    func cancelRequest(for item: HistoryItem) {
        let cacheKey = item.id.uuidString
        requestsLock.lock()
        pendingRequests.removeValue(forKey: cacheKey)
        requestsLock.unlock()
    }
    
    /// Clear all caches
    func clearCache() {
        memoryCache.removeAllObjects()
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheDirectory)
            try? self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Clear memory cache only (useful for memory warnings)
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    // MARK: - Private Methods
    
    private func createThumbnail(from image: NSImage) -> NSImage {
        let originalSize = image.size
        let scale = min(thumbnailSize / originalSize.width, thumbnailSize / originalSize.height)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        
        // Use high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    private func cacheInMemory(_ image: NSImage, key: String) {
        // Calculate approximate cost (width * height * 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    private func loadFromDiskCache(key: String) -> NSImage? {
        let fileURL = diskCacheURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }
    
    private func saveToDiskCache(_ image: NSImage, key: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        let fileURL = diskCacheURL(for: key)
        try? pngData.write(to: fileURL)
        
        // Cleanup old cache if needed
        cleanupDiskCacheIfNeeded()
    }
    
    private func diskCacheURL(for key: String) -> URL {
        return diskCacheDirectory.appendingPathComponent("\(key).png")
    }
    
    private func completeRequest(key: String, image: NSImage?) {
        requestsLock.lock()
        let callbacks = pendingRequests.removeValue(forKey: key) ?? []
        requestsLock.unlock()
        
        DispatchQueue.main.async {
            callbacks.forEach { $0(image) }
        }
    }
    
    private func cleanupDiskCacheIfNeeded() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
            guard let enumerator = self.fileManager.enumerator(
                at: self.diskCacheDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else { return }
            
            var files: [(url: URL, size: Int64, date: Date)] = []
            var totalSize: Int64 = 0
            
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let fileSize = resourceValues.fileSize,
                      let modificationDate = resourceValues.contentModificationDate else {
                    continue
                }
                
                let size = Int64(fileSize)
                files.append((fileURL, size, modificationDate))
                totalSize += size
            }
            
            // If over limit, remove oldest files
            if totalSize > self.maxDiskCacheSize {
                files.sort { $0.date < $1.date } // Oldest first
                
                var sizeToRemove = totalSize - self.maxDiskCacheSize
                for file in files {
                    if sizeToRemove <= 0 { break }
                    try? self.fileManager.removeItem(at: file.url)
                    sizeToRemove -= file.size
                }
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
