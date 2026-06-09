// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "XplorerRemap",
    platforms: [.macOS(.v13)],
    targets: [
        // C wrapper around IOKit's IOUSBLib (COM-style API hostile to Swift).
        .target(
            name: "CXplorerUSB",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        // UI-free logic: report parsing, key mapping, event posting. Unit-tested.
        .target(
            name: "XplorerKit",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
            ]
        ),
        // CLI probe: dumps raw reports to verify the USB layer + axis offsets.
        .executableTarget(
            name: "xplorer-probe",
            dependencies: ["CXplorerUSB", "XplorerKit"]
        ),
        // The windowed remapper app.
        .executableTarget(
            name: "XplorerRemap",
            dependencies: ["CXplorerUSB", "XplorerKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "XplorerKitTests",
            dependencies: ["XplorerKit"]
        ),
    ]
)
