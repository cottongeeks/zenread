// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mac-reader",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.9.0")
    ],
    targets: [
        // AppKit-free logic (Markdown span extraction), separate so it can
        // be unit tested, on Linux too.
        .target(
            name: "ReaderCore",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]),
        .testTarget(name: "ReaderCoreTests", dependencies: ["ReaderCore"]),
    ]
)

// The app is AppKit, so it only exists on macOS. Elsewhere (Linux orbs) the package is just
// ReaderCore and its tests.
#if os(macOS)
    // The command-line launcher and the app are one binary.
    package.products.append(.executable(name: "mac-reader", targets: ["MacReader"]))
    package.targets.append(.executableTarget(name: "MacReader", dependencies: ["ReaderCore"]))
#endif
