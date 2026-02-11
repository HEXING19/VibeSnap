import SwiftUI
import AppKit

// MARK: - Clipboard History SwiftUI Content View

/// Main content view for the clipboard history panel (SwiftUI)
struct ClipboardHistoryContentView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var selectedClipID: UUID?
    @State private var searchText = ""
    @AppStorage("clipboardShowTimestamps") private var showTimestamps = true
    
    var selectedClip: ClipboardItemType? {
        guard let id = selectedClipID else { return nil }
        return clipboardManager.clips.first { $0.id == id }
    }
    
    var filteredClips: [ClipboardItemType] {
        let clips = clipboardManager.sortedClips
        
        if searchText.isEmpty {
            return clips
        }
        
        return clips.filter { clip in
            switch clip {
            case .text(let textClip):
                return textClip.text.localizedCaseInsensitiveContains(searchText)
            case .image:
                return false // Images don't have searchable text
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side: List of clips
            clipListPanel
                .frame(width: 320)
            
            Divider()
            
            // Right side: Preview panel
            previewPanel
                .frame(maxWidth: .infinity)
        }
        .frame(width: 700, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Left Panel: Clip List
    
    private var clipListPanel: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField("Search clips...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Clips list
            if filteredClips.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredClips) { clip in
                            EquatableView(content: ClipboardItemRow(
                                clip: clip,
                                isSelected: selectedClipID == clip.id,
                                showTimestamp: showTimestamps,
                                onSelect: {
                                    selectedClipID = clip.id
                                },
                                onCopy: {
                                    clipboardManager.copyToClipboard(clip)
                                }
                            ))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.automatic)
            }
            
            Divider()
            
            // Bottom toolbar
            bottomToolbar
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(searchText.isEmpty ? "No clips yet" : "No matching clips")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("Copy something to get started.\nClipboard changes are tracked automatically.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // Clip count
            Text("\(filteredClips.count) clip\(filteredClips.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Clear menu
            Menu {
                Button(action: {
                    clipboardManager.clearUnpinned()
                    selectedClipID = nil
                }) {
                    Label("Clear Unpinned", systemImage: "pin.slash")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    clipboardManager.clearAll()
                    selectedClipID = nil
                }) {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Right Panel: Preview
    
    @ViewBuilder
    private var previewPanel: some View {
        if let clip = selectedClip {
            ClipboardPreviewPanel(
                clip: clip,
                clipboardManager: clipboardManager,
                onClose: { self.selectedClipID = nil }
            )
        } else {
            // Placeholder
            VStack(spacing: 16) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("Select a clip to preview")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Text("Click any item in the list to see its full content")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Clipboard History Window Controller

/// Window controller for clipboard history, styled to match Settings window
class ClipboardHistoryWindowController: NSWindowController {
    static let shared = ClipboardHistoryWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Clipboard History"
        window.level = .floating
        window.center()
        window.minSize = NSSize(width: 550, height: 350)
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified
        
        super.init(window: window)
        
        let hostingView = NSHostingView(
            rootView: ClipboardHistoryContentView(clipboardManager: ClipboardManager.shared)
        )
        window.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Show or toggle the clipboard history panel
    func togglePanel() {
        if let window = self.window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                showPanel()
            }
        }
    }
    
    /// Show the clipboard history panel
    func showPanel() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
