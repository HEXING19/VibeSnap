import Foundation
import AppKit

/// Watches for new system screenshots using NSMetadataQuery (Spotlight)
class ClipboardScreenshotWatcher {
    private var query: NSMetadataQuery?
    private var onScreenshot: ((Data) -> Void)?
    private var lastScreenshotDate: Date = Date()
    
    init() {}
    
    /// Start watching for new screenshots
    func startWatching(onScreenshot: @escaping (Data) -> Void) {
        self.onScreenshot = onScreenshot
        self.lastScreenshotDate = Date()
        
        query = NSMetadataQuery()
        guard let query = query else { return }
        
        // Search for screenshot files via Spotlight metadata
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [
            NSMetadataQueryLocalComputerScope
        ]
        
        // Sort by creation date descending
        query.sortDescriptors = [NSSortDescriptor(key: "kMDItemFSCreationDate", ascending: false)]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        
        query.start()
    }
    
    /// Stop watching for screenshots
    func stopWatching() {
        query?.stop()
        query = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        // Initial gathering complete, enable live updates
        query?.enableUpdates()
    }
    
    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = query else { return }
        
        query.disableUpdates()
        defer { query.enableUpdates() }
        
        // Check for new screenshots
        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem else { continue }
            
            guard let path = item.value(forAttribute: kMDItemPath as String) as? String,
                  let creationDate = item.value(forAttribute: kMDItemFSCreationDate as String) as? Date else {
                continue
            }
            
            // Only process screenshots created after we started watching
            if creationDate > lastScreenshotDate {
                lastScreenshotDate = creationDate
                
                // Load the screenshot image with a small delay to ensure file is fully written
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    let url = URL(fileURLWithPath: path)
                    if let imageData = try? Data(contentsOf: url) {
                        DispatchQueue.main.async {
                            self?.onScreenshot?(imageData)
                        }
                    }
                }
                
                // Only process the newest screenshot
                break
            }
        }
    }
    
    deinit {
        stopWatching()
    }
}
