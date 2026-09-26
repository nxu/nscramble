// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StatsKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "StatsKit", targets: ["StatsKit"]),
    ],
    targets: [
        .target(name: "StatsKit"),
        .testTarget(name: "StatsKitTests", dependencies: ["StatsKit"]),
    ]
)
