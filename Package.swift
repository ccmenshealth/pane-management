// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaneManagement",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PaneManagement", targets: ["PaneManagement"])],
    targets: [
        .target(name: "SnapCore"),
        .executableTarget(name: "PaneManagement", dependencies: ["SnapCore"]),
        .executableTarget(name: "SnapCoreChecks", dependencies: ["SnapCore"], path: "Tests/SnapCoreTests"),
        .executableTarget(name: "PaneManagementTestWindows", path: "Tests/TestWindows")
    ]
)
