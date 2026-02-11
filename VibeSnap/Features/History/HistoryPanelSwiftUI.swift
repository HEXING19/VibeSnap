import SwiftUI
import AppKit

// MARK: - Screenshot History SwiftUI Content View

/// Main content view for the screenshot history panel (SwiftUI)
struct ScreenshotHistoryContentView: View {
    @State private var historyItems: [HistoryItem] = []
    @State private var selectedItemID: UUID?
    @State private var searchText = ""
    @State private var isLoading = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]
    
    var filteredItems: [HistoryItem] {
        historyItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerView
            
            Divider()
            
            // Grid of screenshots
            if isLoading {
                loadingView
            } else if filteredItems.isEmpty {
                emptyStateView
            } else {
                screenshotGrid
            }
            
            Divider()
            
            // Bottom toolbar
            bottomToolbar
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadHistory()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Screenshot History")
                .font(.headline)
            
            Spacer()
            
            // Search field (placeholder for future)
            Image(systemName: "photo.stack")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading screenshots...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No screenshots yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Take a screenshot to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Screenshot Grid
    
    private var screenshotGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredItems) { item in
                    ScreenshotThumbnailView(item: item, isSelected: selectedItemID == item.id)
                        .onTapGesture {
                            selectedItemID = item.id
                        }
                        .onTapGesture(count: 2) {
                            copyToClipboard(item)
                        }
                        .contextMenu {
                            Button("Copy to Clipboard") {
                                copyToClipboard(item)
                            }
                            Button("Delete", role: .destructive) {
                                deleteItem(item)
                            }
                        }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.automatic)
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Text("\(filteredItems.count) screenshot\(filteredItems.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: clearAll) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Clear All")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func loadHistory() {
        isLoading = true
        // Load on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let items = HistoryManager.shared.getHistory()
            DispatchQueue.main.async {
                self.historyItems = items
                self.isLoading = false
            }
        }
    }
    
    private func copyToClipboard(_ item: HistoryItem) {
        HistoryManager.shared.copyToClipboard(item: item)
        
        // Visual feedback
        let notification = NSUserNotification()
        notification.title = "Copied to Clipboard"
        notification.informativeText = "Screenshot copied"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func deleteItem(_ item: HistoryItem) {
        HistoryManager.shared.deleteItem(item)
        historyItems.removeAll { $0.id == item.id }
    }
    
    private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will permanently delete all saved screenshots."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            HistoryManager.shared.clearHistory()
            historyItems.removeAll()
        }
    }
}

// MARK: - Screenshot Thumbnail View

struct ScreenshotThumbnailView: View {
    let item: HistoryItem
    let isSelected: Bool
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .cornerRadius(6)
                } else {
                    placeholderView
                        .frame(height: 120)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            // Timestamp
            Text(dateFormatter.string(from: item.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(NSColor.quaternaryLabelColor)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .cornerRadius(6)
    }
    
    private func loadThumbnail() {
        // Load thumbnail asynchronously
        HistoryManager.shared.getThumbnail(for: item) { loadedThumbnail in
            self.thumbnail = loadedThumbnail
            self.isLoading = false
        }
    }
}

// MARK: - Screenshot History Window Controller

/// Floating panel window for screenshot history (SwiftUI version)
class ScreenshotHistoryWindowController: NSWindowController {
    static let shared = ScreenshotHistoryWindowController()
    
    private init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Screenshot History"
        window.center()
        window.level = .floating
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 400, height: 300)
        window.isMovableByWindowBackground = true
        
        super.init(window: window)
        
        let hostingView = NSHostingView(
            rootView: ScreenshotHistoryContentView()
        )
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Show or toggle the screenshot history panel
    func togglePanel() {
        if let window = self.window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                showPanel()
            }
        }
    }
    
    /// Show the screenshot history panel
    func showPanel() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
