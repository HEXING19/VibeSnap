import SwiftUI
import AppKit

// MARK: - Virtualized Text View for large text content

/// NSTextView-backed scrollable text view for performance with large text
private struct ScrollableTextView: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5)
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
                textView.scrollToBeginningOfDocument(nil)
            }
        }
    }
}

// MARK: - Preview Panel

/// Preview panel showing full content of a selected clipboard item
struct ClipboardPreviewPanel: View {
    let clip: ClipboardItemType
    let clipboardManager: ClipboardManager
    let onClose: () -> Void
    
    @State private var showCopiedFeedback = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            headerBar
            
            Divider()
            
            // Content area
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer with copy button and metadata
            footerBar
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Pin status
            HStack(spacing: 4) {
                Image(systemName: clip.isPinned ? "pin.fill" : "pin.slash")
                    .font(.caption)
                Text(clip.isPinned ? "Pinned" : "Unpinned")
                    .font(.caption)
            }
            .foregroundColor(clip.isPinned ? .orange : .secondary)
            
            Spacer()
            
            // Pin/Unpin button
            Button(action: {
                clipboardManager.togglePin(for: clip.id)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: clip.isPinned ? "pin.slash" : "pin")
                    Text(clip.isPinned ? "Unpin" : "Pin")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(4)
            
            // Delete button
            Button(action: {
                clipboardManager.delete(clipID: clip.id)
                onClose()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12))
            .cornerRadius(4)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        switch clip {
        case .text(let textClip):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.accentColor)
                    Text("Text Clip")
                        .font(.headline)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                ScrollableTextView(text: textClip.text)
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            
        case .image(let imageClip):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.accentColor)
                        Text("Image Clip")
                            .font(.headline)
                    }
                    
                    if let fullImage = imageClip.fullImage() {
                        Image(nsImage: fullImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 350)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                            Text("Unable to display image")
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.never)
        }
    }
    
    // MARK: - Footer
    
    private var footerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: clip.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if case .text(let textClip) = clip {
                    Text("\(textClip.text.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if case .image(let imageClip) = clip {
                    Text("\(imageClip.width) × \(imageClip.height) • \(formatBytes(imageClip.imageData.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Copy button with feedback
            Button(action: {
                clipboardManager.copyToClipboard(clip)
                withAnimation {
                    showCopiedFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showCopiedFeedback = false
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    Text(showCopiedFeedback ? "Copied!" : "Copy")
                        .font(.body.weight(.medium))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(showCopiedFeedback ? .green : .accentColor)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
