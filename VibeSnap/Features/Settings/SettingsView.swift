import SwiftUI
import AppKit
import HotKey

struct SettingsView: View {
    @AppStorage("autoSaveLocation") private var autoSaveLocation: String = "Desktop"
    @AppStorage("overlayDuration") private var overlayDuration: Double = 5.0
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                autoSaveLocation: $autoSaveLocation,
                overlayDuration: $overlayDuration
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            ClipboardSettingsView()
            .tabItem {
                Label("Clipboard", systemImage: "list.clipboard")
            }
            
            ShortcutsSettingsView()
            .tabItem {
                Label("Shortcuts", systemImage: "keyboard")
            }
        }
        .frame(width: 480, height: 340)
    }
}

struct GeneralSettingsView: View {
    @Binding var autoSaveLocation: String
    @Binding var overlayDuration: Double
    
    var body: some View {
        Form {
            Section {
                Picker("Save Location:", selection: $autoSaveLocation) {
                    Text("Desktop").tag("Desktop")
                    Text("Documents").tag("Documents")
                    Text("Downloads").tag("Downloads")
                    Text("Custom...").tag("Custom")
                }
                
                HStack {
                    Text("Overlay Duration:")
                    Slider(value: $overlayDuration, in: 1...10, step: 1)
                    Text("\(Int(overlayDuration))s")
                        .frame(width: 30)
                }
            }
        }
        .padding()
    }
}

struct ClipboardSettingsView: View {
    @AppStorage("clipboardMonitoringEnabled") private var monitoringEnabled = true
    @AppStorage("clipboardCaptureScreenshots") private var captureScreenshots = true
    @AppStorage("clipboardShowTimestamps") private var showTimestamps = true
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Monitoring toggle
                    Toggle(isOn: $monitoringEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Clipboard Monitoring")
                            Text("Automatically track clipboard changes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: monitoringEnabled) { _, newValue in
                        if newValue {
                            ClipboardManager.shared.startMonitoring()
                        } else {
                            ClipboardManager.shared.stopMonitoring()
                        }
                    }
                    
                    Divider()
                    
                    // Screenshot capture toggle
                    Toggle(isOn: $captureScreenshots) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Capture System Screenshots")
                            Text("Detect and record screenshots taken via ⌘⇧3/4")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: captureScreenshots) { _, newValue in
                        ClipboardManager.shared.configureScreenshotWatcher(enabled: newValue)
                    }
                    .disabled(!monitoringEnabled)
                    
                    Divider()
                    
                    // Show timestamps toggle
                    Toggle("Show Timestamps", isOn: $showTimestamps)
                    
                    Divider()
                    
                    // Clear all button
                    HStack {
                        Spacer()
                        Button(role: .destructive, action: {
                            ClipboardManager.shared.clearAll()
                        }) {
                            Label("Clear All Clipboard History", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ShortcutsSettingsView: View {
    @State private var recordingAction: String? = nil
    @State private var refreshTrigger = false
    
    private let shortcuts: [(String, String)] = [
        ("captureArea", "Capture Area"),
        ("captureFullscreen", "Capture Fullscreen"),
        ("showHistory", "Screenshot History"),
        ("clipboardHistory", "Clipboard History"),
    ]
    
    var body: some View {
        Form {
            Section {
                ForEach(shortcuts, id: \.0) { action, label in
                    HStack {
                        Text(label)
                        Spacer()
                        ShortcutRecorderButton(
                            action: action,
                            isRecording: recordingAction == action,
                            onStartRecording: {
                                recordingAction = action
                            },
                            onStopRecording: {
                                recordingAction = nil
                                refreshTrigger.toggle()
                            }
                        )
                    }
                }
            } header: {
                Text("Click a shortcut to change it, then press your desired key combination.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .id(refreshTrigger) // force refresh when shortcut changes
    }
}

/// A button that records keyboard shortcuts when clicked
struct ShortcutRecorderButton: NSViewRepresentable {
    let action: String
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    func makeNSView(context: Context) -> ShortcutRecorderNSButton {
        let button = ShortcutRecorderNSButton()
        button.shortcutAction = action
        button.onStartRecording = onStartRecording
        button.onStopRecording = onStopRecording
        button.updateDisplay()
        return button
    }
    
    func updateNSView(_ nsView: ShortcutRecorderNSButton, context: Context) {
        nsView.shortcutAction = action
        nsView.isRecordingMode = isRecording
        nsView.onStartRecording = onStartRecording
        nsView.onStopRecording = onStopRecording
        nsView.updateDisplay()
    }
}

class ShortcutRecorderNSButton: NSButton {
    var shortcutAction: String = ""
    var isRecordingMode = false
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        self.target = self
        self.action = #selector(buttonClicked)
        self.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    func updateDisplay() {
        if isRecordingMode {
            self.title = "Press keys..."
            self.contentTintColor = .systemOrange
        } else {
            self.title = HotkeyManager.shared.shortcutDisplayString(for: self.shortcutAction)
            self.contentTintColor = .labelColor
        }
    }
    
    @objc private func buttonClicked() {
        if isRecordingMode {
            isRecordingMode = false
            onStopRecording?()
        } else {
            // Temporarily unregister hotkeys so we can capture the key combo
            HotkeyManager.shared.unregisterHotkeys()
            isRecordingMode = true
            onStartRecording?()
            self.window?.makeFirstResponder(self)
        }
        updateDisplay()
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecordingMode else {
            super.keyDown(with: event)
            return
        }
        
        // Escape cancels recording
        if event.keyCode == 53 {
            isRecordingMode = false
            onStopRecording?()
            HotkeyManager.shared.registerHotkeys()
            updateDisplay()
            return
        }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Need at least one modifier key
        guard modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) else {
            return
        }
        
        // Get the key from carbon key code
        guard let key = Key(carbonKeyCode: UInt32(event.keyCode)) else { return }
        
        // Save the shortcut
        HotkeyManager.shared.saveShortcut(
            action: self.shortcutAction,
            keyString: key.description.lowercased(),
            modifiers: modifiers
        )
        
        isRecordingMode = false
        onStopRecording?()
        updateDisplay()
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Don't consume flag changes
    }
}
