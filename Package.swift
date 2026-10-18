// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Kumquat",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Kumquat", targets: ["Kumquat"]),
        .library(name: "KumquatCore", targets: ["KumquatCore"]),
    ],
    targets: [
        .target(name: "KumquatCore"),
        .executableTarget(name: "Kumquat", dependencies: ["KumquatCore"]),
        .testTarget(name: "KumquatCoreTests", dependencies: ["KumquatCore"]),
    ]
)
