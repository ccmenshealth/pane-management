// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaneManagement",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PaneManagement", targets: ["PaneManagement"])],
    targets: [
        .target(name: "SnapCore"),
        .target(name: "AlwaysOnCore"),
        .target(name: "AlwaysOnService", dependencies: ["AlwaysOnCore"]),
        .executableTarget(name: "AlwaysOnServiceChecks", dependencies: ["AlwaysOnService", "AlwaysOnCore"], path: "Tests/AlwaysOnServiceChecks"),
        .target(name: "AlwaysOnNative", dependencies: ["AlwaysOnCore"]),
        .executableTarget(name: "AlwaysOnNativeChecks", dependencies: ["AlwaysOnNative", "AlwaysOnCore"], path: "Tests/AlwaysOnNativeChecks"),
        .executableTarget(name: "AlwaysOnEngineChecks", dependencies: ["AlwaysOnCore"], path: "Tests/AlwaysOnEngineChecks"),
        .target(name: "AlwaysOnUI", dependencies: ["AlwaysOnCore"]),
        .executableTarget(name: "AlwaysOnChecks", dependencies: ["AlwaysOnCore"], path: "Tests/AlwaysOnChecks"),
        .executableTarget(name: "AlwaysOnPreview", dependencies: ["AlwaysOnCore", "AlwaysOnUI"], path: "Tests/AlwaysOnPreview"),
        .executableTarget(name: "PaneManagement", dependencies: ["SnapCore", "AlwaysOnCore", "AlwaysOnUI"]),
        .executableTarget(name: "SnapCoreChecks", dependencies: ["SnapCore"], path: "Tests/SnapCoreTests"),
        .executableTarget(name: "PaneManagementTestWindows", path: "Tests/TestWindows")
    ]
)
