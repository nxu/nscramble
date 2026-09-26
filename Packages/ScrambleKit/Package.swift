// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScrambleKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "ScrambleKit", targets: ["ScrambleKit"]),
    ],
    targets: [
        .target(name: "ScrambleKit"),
        .testTarget(
            name: "ScrambleKitTests",
            dependencies: ["ScrambleKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
