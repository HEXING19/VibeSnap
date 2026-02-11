import Foundation
import AppKit
import Combine

/// Manages clipboard monitoring, history tracking, and screenshot detection
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var clips: [ClipboardItemType] = []
    
    // Polling state
    private var lastChangeCount: Int
    private var timer: Timer?
    private var lastCapturedText: String?
    private var lastCapturedImageData: Data?
    private var ignoreNextClipboardChange: Bool = false
    
    // Screenshot watcher
    private var screenshotWatcher: ClipboardScreenshotWatcher?
    
    // Configuration
    private let maxTotalItems = 30
    private let maxUnpinnedItems = 25
    private let maxPinnedItems = 5
    private let pollInterval: TimeInterval = 0.5
    
    // Storage
    private let storageDirectory: URL
    private let metadataURL: URL
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // Set up persistent storage directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("VibeSnap/ClipboardHistory", isDirectory: true)
        metadataURL = storageDirectory.appendingPathComponent("clipboard_metadata.json")
        
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Load persisted clips
        loadPersistedClips()
        
        // Start monitoring if enabled
        let isEnabled = UserDefaults.standard.object(forKey: "clipboardMonitoringEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "clipboardMonitoringEnabled")
        
        if isEnabled {
            startMonitoring()
        }
        
        // Configure screenshot watcher based on settings
        let captureScreenshots = UserDefaults.standard.object(forKey: "clipboardCaptureScreenshots") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "clipboardCaptureScreenshots")
        
        configureScreenshotWatcher(enabled: captureScreenshots)
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    /// Start clipboard monitoring via polling
    func startMonitoring() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    /// Stop clipboard monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        screenshotWatcher?.stopWatching()
    }
    
    /// Enable or disable screenshot watching
    func configureScreenshotWatcher(enabled: Bool) {
        if enabled {
            if screenshotWatcher == nil {
                screenshotWatcher = ClipboardScreenshotWatcher()
                screenshotWatcher?.startWatching { [weak self] imageData in
                    self?.captureScreenshot(imageData)
                }
            }
        } else {
            screenshotWatcher?.stopWatching()
            screenshotWatcher = nil
        }
    }
    
    // MARK: - Clipboard Checking
    
    /// Check system clipboard for changes
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Skip if this change was triggered by our own copy action
        if ignoreNextClipboardChange {
            ignoreNextClipboardChange = false
            return
        }
        
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        // Check for file URLs that point to images first
        if types.contains(.fileURL),
           let urlString = pasteboard.string(forType: .fileURL),
           let url = URL(string: urlString),
           ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp", "heic"].contains(url.pathExtension.lowercased()),
           let imageData = try? Data(contentsOf: url) {
            captureImage(imageData)
            return
        }
        
        // Try to capture image data (e.g. copied from apps)
        if types.contains(.tiff) || types.contains(.png) {
            if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                captureImage(imageData)
                return
            }
        }
        
        // Fall back to text
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            captureText(string)
            return
        }
    }
    
    // MARK: - Capture Methods
    
    /// Capture a text clip from the clipboard
    private func captureText(_ text: String) {
        // Deduplicate consecutive identical text
        guard text != lastCapturedText else { return }
        lastCapturedText = text
        lastCapturedImageData = nil
        
        let newClip = TextClipItem(text: text)
        
        DispatchQueue.main.async {
            self.clips.insert(.text(newClip), at: 0)
            self.enforceCapacity()
        }
    }
    
    /// Capture an image clip from the clipboard
    private func captureImage(_ imageData: Data) {
        // Deduplicate consecutive identical images
        guard imageData != lastCapturedImageData else { return }
        lastCapturedImageData = imageData
        lastCapturedText = nil
        
        guard let imageClip = ImageClipItem(imageData: imageData) else {
            print("[ClipboardManager] Failed to create image clip or image too large")
            return
        }
        
        DispatchQueue.main.async {
            self.clips.insert(.image(imageClip), at: 0)
            self.enforceCapacity()
            self.persistImageClip(imageClip)
        }
    }
    
    /// Capture a screenshot detected by the file watcher
    private func captureScreenshot(_ imageData: Data) {
        guard imageData != lastCapturedImageData else { return }
        lastCapturedImageData = imageData
        lastCapturedText = nil
        
        // Ignore the next clipboard change since screenshot watcher may trigger one
        ignoreNextClipboardChange = true
        
        guard let imageClip = ImageClipItem(imageData: imageData) else {
            print("[ClipboardManager] Failed to create image clip from screenshot")
            return
        }
        
        DispatchQueue.main.async {
            self.clips.insert(.image(imageClip), at: 0)
            self.enforceCapacity()
            self.persistImageClip(imageClip)
        }
    }
    
    // MARK: - Capacity Management
    
    /// Enforce capacity limits, removing oldest unpinned items first
    private func enforceCapacity() {
        let pinnedCount = clips.filter { $0.isPinned }.count
        let unpinnedCount = clips.count - pinnedCount
        
        // Remove oldest unpinned items if over limit
        if unpinnedCount > maxUnpinnedItems {
            let itemsToRemove = unpinnedCount - maxUnpinnedItems
            var removed = 0
            
            // Build new list, skipping oldest unpinned items
            var newClips: [ClipboardItemType] = []
            for clip in clips.reversed() {
                if removed < itemsToRemove && !clip.isPinned {
                    // Clean up persisted image if needed
                    if case .image(let imgClip) = clip {
                        removePersistedImage(imgClip.id)
                    }
                    removed += 1
                } else {
                    newClips.insert(clip, at: 0)
                }
            }
            clips = newClips
        }
        
        // Hard cap on total items
        if clips.count > maxTotalItems {
            let overflow = Array(clips.suffix(from: maxTotalItems))
            for clip in overflow {
                if case .image(let imgClip) = clip {
                    removePersistedImage(imgClip.id)
                }
            }
            clips = Array(clips.prefix(maxTotalItems))
        }
        
        saveMetadata()
    }
    
    // MARK: - Clip Operations
    
    /// Toggle pin status for a clip
    func togglePin(for clipID: UUID) {
        if let index = clips.firstIndex(where: { $0.id == clipID }) {
            clips[index].isPinned.toggle()
            
            // Move pinned items to top
            if clips[index].isPinned {
                let clip = clips.remove(at: index)
                let firstUnpinnedIndex = clips.firstIndex(where: { !$0.isPinned }) ?? 0
                clips.insert(clip, at: firstUnpinnedIndex)
            }
            saveMetadata()
        }
    }
    
    /// Delete a specific clip
    func delete(clipID: UUID) {
        if let clip = clips.first(where: { $0.id == clipID }) {
            if case .image(let imgClip) = clip {
                removePersistedImage(imgClip.id)
            }
        }
        clips.removeAll { $0.id == clipID }
        saveMetadata()
    }
    
    /// Clear all unpinned clips
    func clearUnpinned() {
        let unpinned = clips.filter { !$0.isPinned }
        for clip in unpinned {
            if case .image(let imgClip) = clip {
                removePersistedImage(imgClip.id)
            }
        }
        clips.removeAll { !$0.isPinned }
        saveMetadata()
    }
    
    /// Clear all clips
    func clearAll() {
        for clip in clips {
            if case .image(let imgClip) = clip {
                removePersistedImage(imgClip.id)
            }
        }
        clips.removeAll()
        saveMetadata()
    }
    
    /// Copy a clip back to the system clipboard
    func copyToClipboard(_ clip: ClipboardItemType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Temporarily ignore the next change so we don't re-capture
        ignoreNextClipboardChange = true
        
        switch clip {
        case .text(let textClip):
            pasteboard.setString(textClip.text, forType: .string)
            lastCapturedText = textClip.text
            lastChangeCount = pasteboard.changeCount
            
        case .image(let imageClip):
            if let image = imageClip.fullImage() {
                pasteboard.writeObjects([image])
                lastCapturedImageData = imageClip.imageData
                lastChangeCount = pasteboard.changeCount
            }
        }
    }
    
    /// Get sorted clips (pinned first, then by date)
    var sortedClips: [ClipboardItemType] {
        let pinned = clips.filter { $0.isPinned }
        let unpinned = clips.filter { !$0.isPinned }
        return pinned + unpinned
    }
    
    // MARK: - Persistence
    
    /// Save image clip data to disk
    private func persistImageClip(_ clip: ImageClipItem) {
        let fileURL = storageDirectory.appendingPathComponent("\(clip.id.uuidString).dat")
        try? clip.imageData.write(to: fileURL)
    }
    
    /// Remove persisted image data
    private func removePersistedImage(_ id: UUID) {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).dat")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Save metadata for all clips
    private func saveMetadata() {
        let metadata = clips.map { clip -> ClipboardMetadataItem in
            switch clip {
            case .text(let textClip):
                return ClipboardMetadataItem(
                    id: textClip.id,
                    clipType: "text",
                    createdAt: textClip.createdAt,
                    isPinned: textClip.isPinned,
                    text: textClip.text,
                    width: nil,
                    height: nil
                )
            case .image(let imageClip):
                return ClipboardMetadataItem(
                    id: imageClip.id,
                    clipType: "image",
                    createdAt: imageClip.createdAt,
                    isPinned: imageClip.isPinned,
                    text: nil,
                    width: imageClip.width,
                    height: imageClip.height
                )
            }
        }
        
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
    
    /// Load persisted clips from disk
    private func loadPersistedClips() {
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode([ClipboardMetadataItem].self, from: data) else {
            return
        }
        
        clips = metadata.compactMap { meta in
            switch meta.clipType {
            case "text":
                guard let text = meta.text else { return nil }
                let clip = TextClipItem(
                    id: meta.id,
                    createdAt: meta.createdAt,
                    isPinned: meta.isPinned,
                    text: text
                )
                return .text(clip)
                
            case "image":
                let fileURL = storageDirectory.appendingPathComponent("\(meta.id.uuidString).dat")
                guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
                let clip = ImageClipItem(
                    id: meta.id,
                    createdAt: meta.createdAt,
                    isPinned: meta.isPinned,
                    imageData: imageData,
                    width: meta.width ?? 0,
                    height: meta.height ?? 0
                )
                return .image(clip)
                
            default:
                return nil
            }
        }
    }
}

// MARK: - Metadata Model for Persistence

private struct ClipboardMetadataItem: Codable {
    let id: UUID
    let clipType: String
    let createdAt: Date
    let isPinned: Bool
    let text: String?
    let width: Int?
    let height: Int?
}
