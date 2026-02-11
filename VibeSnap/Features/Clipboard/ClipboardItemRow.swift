import SwiftUI
import AppKit

/// A single row in the clipboard history list
struct ClipboardItemRow: View, Equatable {
    let clip: ClipboardItemType
    let isSelected: Bool
    let showTimestamp: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    
    @State private var isHovering = false
    
    static func == (lhs: ClipboardItemRow, rhs: ClipboardItemRow) -> Bool {
        lhs.clip.id == rhs.clip.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.showTimestamp == rhs.showTimestamp &&
        lhs.clip.isPinned == rhs.clip.isPinned
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Type indicator icon
                typeIcon
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
                
                // Content preview
                contentPreview
                
                Spacer()
                
                // Copy button (appears on hover)
                if isHovering {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                    .transition(.opacity)
                }
                
                // Pin indicator
                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) :
                          isHovering ? Color.primary.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    private var typeIcon: some View {
        switch clip {
        case .text:
            Image(systemName: "doc.text")
                .font(.system(size: 14))
        case .image:
            Image(systemName: "photo")
                .font(.system(size: 14))
        }
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        switch clip {
        case .text(let textClip):
            VStack(alignment: .leading, spacing: 4) {
                Text(String(textClip.text.prefix(200)))
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if showTimestamp {
                    Text(dateFormatter.string(from: textClip.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        case .image(let imageClip):
            HStack(spacing: 8) {
                // Thumbnail
                if let thumbnail = imageClip.thumbnail() {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image")
                        .font(.system(size: 13))
                    
                    Text("\(imageClip.width) × \(imageClip.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if showTimestamp {
                        Text(dateFormatter.string(from: imageClip.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
