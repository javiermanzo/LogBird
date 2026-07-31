// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogBird",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LogBird",
            targets: ["LogBird"]),
        .library(
            name: "LogBirdUI",
            targets: ["LogBirdUI"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LogBird"),
        .target(
            name: "LogBirdUI",
            dependencies: ["LogBird"]),
        .testTarget(
            name: "LogBirdTests",
            dependencies: ["LogBird"]
        ),
        .testTarget(
            name: "LogBirdUITests",
            dependencies: ["LogBird", "LogBirdUI"]
        ),
    ],
    swiftLanguageModes: [.version("6"), .v5]
)
