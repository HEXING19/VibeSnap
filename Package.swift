// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VibeSnap",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VibeSnap", targets: ["VibeSnap"])
    ],
    dependencies: [
        .package(path: "Dependencies/HotKey")
    ],
    targets: [
        .executableTarget(
            name: "VibeSnap",
            dependencies: ["HotKey"],
            path: "VibeSnap",
            exclude: ["Info.plist", "VibeSnap.entitlements"]
        )
    ]
)
