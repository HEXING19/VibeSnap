# VibeSnap 📸

**A lightweight, native macOS screenshot & clipboard manager built with Swift.**

VibeSnap lives in your menu bar and gives you powerful screen capture tools, annotation features, and a unified clipboard history — all in a beautiful, macOS-native interface.

---

## ✨ Features

### 🖼 Screen Capture
- **Area Capture** — Select any region of your screen to capture
- **Fullscreen Capture** — Capture your entire display instantly
- **Multi-display Support** — Works seamlessly across all connected monitors

### ✏️ Annotation Tools
A full suite of annotation tools, inspired by macOS Preview:
- ✎ **Arrow** — Straight & curved arrows with adjustable thickness
- ▢ **Rectangle** — With corner radius, fill, and stroke options
- ○ **Ellipse** — Filled or outlined circles/ellipses
- — **Line** — Solid or dashed lines
- ✍ **Freehand** — Smooth freeform drawing
- 💬 **Callout** — Speech bubble annotations with text
- **T Text** — Click-to-type text annotations
- **#  Number** — Circled number markers
- ▦ **Mosaic** — Pixelate sensitive information
- 🔍 **Magnifier** — Zoom into specific areas
- 🖊 **Highlighter** — Semi-transparent highlight strokes

### 📋 Clipboard History
- Automatically tracks text and image clipboard changes
- Search through your clipboard history
- Pin important clips to keep them at the top
- Preview clips with full-size rendering
- Detects system screenshots (⌘⇧3/4) automatically

### ⌨️ Customizable Shortcuts
All keyboard shortcuts are fully customizable from Settings:

| Action | Default Shortcut |
|---|---|
| Capture Area | ⇧⌘1 |
| Capture Fullscreen | ⇧⌘3 |
| Screenshot History | ⇧⌘4 |
| Clipboard History | ⇧⌘V |

### 🎨 Design
- Native macOS look and feel
- Floating toolbar with glassmorphism effect
- Context-aware properties panel
- Thumbnail preview overlay after capture
- Pin screenshots to float above other windows

---

## 📥 Installation

### Build from Source

**Requirements:**
- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Swift 5.9+

```bash
git clone https://github.com/YOUR_USERNAME/VibeSnap.git
cd VibeSnap
swift build
swift run
```

### Permissions
On first launch, VibeSnap will request **Screen Recording** permission. You can enable this in:

> System Settings → Privacy & Security → Screen Recording → VibeSnap ✓

---

## 🖥 Usage

1. **Launch** — VibeSnap appears as a camera icon in your menu bar
2. **Capture** — Click the icon or use keyboard shortcuts to capture
3. **Annotate** — Use the floating toolbar to add annotations
4. **Copy/Save** — Copy to clipboard or save to disk
5. **History** — Access your screenshot and clipboard history anytime

---

## 🏗 Architecture

```
VibeSnap/
├── App/                  # App delegate & entry point
├── Core/Managers/        # HotkeyManager, CaptureManager, etc.
├── Features/
│   ├── Capture/          # Screen capture overlay & loupe
│   ├── Clipboard/        # Clipboard history & monitoring
│   ├── Editor/           # Annotation tools & canvas
│   ├── History/          # Screenshot history panel
│   ├── MenuBar/          # Status bar controller
│   ├── Pin/              # Pinned image windows
│   ├── Preview/          # Thumbnail overlay
│   └── Settings/         # Preferences UI
└── Dependencies/         # HotKey library
```

Built with:
- **SwiftUI** + **AppKit** for native macOS UI
- **ScreenCaptureKit** for screen recording
- **HotKey** library for global keyboard shortcuts
- **Core Image** for blur/mosaic effects

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>Built with ❤️ for macOS</b><br>
  <sub>If you find VibeSnap useful, give it a ⭐ on GitHub!</sub>
</p>
