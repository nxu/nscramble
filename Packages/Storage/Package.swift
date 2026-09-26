// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(name: "Storage", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "StorageTests", dependencies: ["Storage", .product(name: "GRDB", package: "GRDB.swift")]),
    ]
)
