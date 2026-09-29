// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Selene",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SeleneCore"),
        .executableTarget(name: "selene", dependencies: ["SeleneCore"]),
        // Command Line Tools ship neither XCTest nor the swift-testing macros,
        // so the checks are a plain executable: `swift run selene-check`.
        .executableTarget(name: "selene-check", dependencies: ["SeleneCore"]),
    ],
    swiftLanguageModes: [.v5]
)
