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
            
            ShortcutsSettingsView()
            .tabItem {
                Label("Shortcuts", systemImage: "keyboard")
            }
        }
        .frame(width: 450, height: 300)
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
            }
        }
        .padding()
    }
}


