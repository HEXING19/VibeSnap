import SwiftUI

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
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Capture Area")
                    Spacer()
                    Text("⇧⌘1")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Capture Window")
                    Spacer()
                    Text("⇧⌘2")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Capture Fullscreen")
                    Spacer()
                    Text("⇧⌘3")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Screenshot History")
                    Spacer()
                    Text("⇧⌘4")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Clipboard History")
                    Spacer()
                    Text("⇧⌘V")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}


