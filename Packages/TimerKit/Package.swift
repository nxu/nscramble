// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TimerKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "TimerKit", targets: ["TimerKit"]),
    ],
    targets: [
        .target(name: "TimerKit"),
        .testTarget(name: "TimerKitTests", dependencies: ["TimerKit"]),
    ]
)
