import AppKit
import SwiftUI

/// Floating panel for viewing screenshot history
class HistoryPanel: NSPanel {
    private var historyView: HistoryContentView?
    var onItemSelected: ((HistoryItem) -> Void)?
    var onItemDoubleClicked: ((HistoryItem) -> Void)?
    
    init() {
        let panelSize = CGSize(width: 400, height: 500)
        let screenRect = NSScreen.main?.visibleFrame ?? CGRect.zero
        let panelRect = CGRect(
            x: screenRect.midX - panelSize.width / 2,
            y: screenRect.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        
        super.init(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
        setupContentView()
    }
    
    private func setupPanel() {
        self.title = "Screenshot History"
        self.level = .floating
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    private func setupContentView() {
        historyView = HistoryContentView(frame: self.frame.size, panel: self)
        self.contentView = historyView
    }
    
    func show() {
        historyView?.refreshHistory()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func itemDoubleClicked(_ item: HistoryItem) {
        onItemDoubleClicked?(item)
    }
}

/// Main content view for history panel
class HistoryContentView: NSView {
    weak var panel: HistoryPanel?
    private var scrollView: NSScrollView?
    private var collectionView: NSCollectionView?
    private var historyItems: [HistoryItem] = []
    
    init(frame size: CGSize, panel: HistoryPanel) {
        self.panel = panel
        super.init(frame: NSRect(origin: .zero, size: size))
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Create scroll view
        scrollView = NSScrollView(frame: bounds)
        scrollView?.autoresizingMask = [.width, .height]
        scrollView?.hasVerticalScroller = true
        scrollView?.borderType = .noBorder
        
        // Create collection view
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 180, height: 140)
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.minimumLineSpacing = 10
        flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        collectionView = NSCollectionView()
        collectionView?.collectionViewLayout = flowLayout
        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.prefetchDataSource = self
        collectionView?.backgroundColors = [.clear]
        collectionView?.isSelectable = true
        collectionView?.allowsMultipleSelection = false
        collectionView?.register(HistoryItemCell.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("HistoryItemCell"))
        
        scrollView?.documentView = collectionView
        addSubview(scrollView!)
        
        // Add clear button at bottom
        let clearButton = NSButton(frame: CGRect(x: bounds.width - 80, y: 10, width: 70, height: 24))
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearAllClicked)
        clearButton.autoresizingMask = [.minXMargin, .maxYMargin]
        addSubview(clearButton)
    }
    
    func refreshHistory() {
        historyItems = HistoryManager.shared.getHistory()
        collectionView?.reloadData()
        
        // Prefetch thumbnails for first visible items
        let visibleIndexPaths = collectionView?.indexPathsForVisibleItems() ?? []
        let visibleItems = visibleIndexPaths.compactMap { historyItems[safe: $0.item] }
        HistoryManager.shared.prefetchThumbnails(for: visibleItems)
    }
    
    @objc private func clearAllClicked() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will permanently delete all saved screenshots."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearHistory()
            refreshHistory()
        }
    }
}

extension HistoryContentView: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return historyItems.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("HistoryItemCell"), for: indexPath)
        if let cell = item as? HistoryItemCell, let historyItem = historyItems[safe: indexPath.item] {
            cell.configure(with: historyItem)
        }
        return item
    }
}

extension HistoryContentView: NSCollectionViewPrefetching {
    @objc func collectionView(_ collectionView: NSCollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let itemsToPrefetch = indexPaths.compactMap { historyItems[safe: $0.item] }
        HistoryManager.shared.prefetchThumbnails(for: itemsToPrefetch)
    }
    
    @objc func collectionView(_ collectionView: NSCollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel pending thumbnail loads
        for indexPath in indexPaths {
            if let item = historyItems[safe: indexPath.item] {
                ThumbnailCache.shared.cancelRequest(for: item)
            }
        }
    }
}

extension HistoryContentView: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Single click - could show preview
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
    }
}

/// Collection view cell for history item
class HistoryItemCell: NSCollectionViewItem {
    private var thumbnailView: NSImageView?
    private var timestampLabel: NSTextField?
    private var historyItem: HistoryItem?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 140))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 8
        
        // Thumbnail
        thumbnailView = NSImageView(frame: NSRect(x: 10, y: 30, width: 160, height: 100))
        thumbnailView?.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(thumbnailView!)
        
        // Timestamp
        timestampLabel = NSTextField(labelWithString: "")
        timestampLabel?.frame = NSRect(x: 10, y: 5, width: 160, height: 20)
        timestampLabel?.font = .systemFont(ofSize: 10)
        timestampLabel?.textColor = .secondaryLabelColor
        timestampLabel?.alignment = .center
        view.addSubview(timestampLabel!)
        
        // Double-click gesture
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        view.addGestureRecognizer(doubleClick)
    }
    
    func configure(with item: HistoryItem) {
        historyItem = item
        
        // Show placeholder immediately
        thumbnailView?.image = createPlaceholderImage()
        
        // Load thumbnail asynchronously
        HistoryManager.shared.getThumbnail(for: item) { [weak self] thumbnail in
            guard let self = self, self.historyItem?.id == item.id else { return }
            self.thumbnailView?.image = thumbnail ?? self.createPlaceholderImage()
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        timestampLabel?.stringValue = formatter.string(from: item.timestamp)
    }
    
    private func createPlaceholderImage() -> NSImage {
        let size = NSSize(width: 160, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Draw gray background
        NSColor.quaternaryLabelColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw icon
        let iconSize: CGFloat = 40
        let iconRect = NSRect(
            x: (size.width - iconSize) / 2,
            y: (size.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        NSColor.tertiaryLabelColor.setFill()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: iconRect.minX + 5, y: iconRect.maxY - 5))
        path.line(to: NSPoint(x: iconRect.maxX - 5, y: iconRect.maxY - 5))
        path.line(to: NSPoint(x: iconRect.maxX - 5, y: iconRect.minY + 5))
        path.line(to: NSPoint(x: iconRect.minX + 5, y: iconRect.minY + 5))
        path.close()
        path.fill()
        
        image.unlockFocus()
        return image
    }
    
    @objc private func handleDoubleClick() {
        guard let item = historyItem else { return }
        
        // Copy to clipboard on double-click
        HistoryManager.shared.copyToClipboard(item: item)
        
        // Visual feedback
        showCopiedFeedback()
        
        // Notify panel
        if let panel = view.window as? HistoryPanel {
            panel.itemDoubleClicked(item)
        }
    }
    
    private func showCopiedFeedback() {
        let copiedLabel = NSTextField(labelWithString: "✓ Copied")
        copiedLabel.font = .boldSystemFont(ofSize: 14)
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.9)
        copiedLabel.isBezeled = false
        copiedLabel.drawsBackground = true
        copiedLabel.alignment = .center
        copiedLabel.frame = NSRect(x: 40, y: 60, width: 100, height: 30)
        copiedLabel.wantsLayer = true
        copiedLabel.layer?.cornerRadius = 6
        
        view.addSubview(copiedLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            copiedLabel.removeFromSuperview()
        }
    }
    
    override var isSelected: Bool {
        didSet {
            view.layer?.borderWidth = isSelected ? 2 : 0
            view.layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : nil
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
