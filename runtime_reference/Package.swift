// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shizuku_Restored",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ShizukuCore"),
        .testTarget(name: "ShizukuCoreTests", dependencies: ["ShizukuCore", "ShizukuEngine", "ShizukuRender"]),
        .target(name: "ShizukuEngine", dependencies: ["ShizukuCore"]),
        .target(name: "ShizukuRender", dependencies: ["ShizukuCore", "ShizukuEngine"]),
        .executableTarget(
            name: "shizuku",
            dependencies: ["ShizukuCore", "ShizukuEngine", "ShizukuRender"],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .executableTarget(
            name: "ShizukuApp",
            dependencies: ["ShizukuCore", "ShizukuEngine", "ShizukuRender"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("MetalKit"), .linkedFramework("Metal")]
        ),
    ]
)
