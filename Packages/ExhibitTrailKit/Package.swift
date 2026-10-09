// swift-tools-version:6.0
import PackageDescription

// Local visit storage. GRDB 7.11.1 requires Swift 6.1+, compatible with the pinned toolchains.
let package = Package(
    name: "ExhibitTrailKit",
    platforms: [
        .iOS("26.0"),
        .macOS(.v11), // FileHandle.read(upToCount:) requires macOS 10.15.4+; CI tests on macos-26.
    ],
    products: [
        .library(name: "ExhibitTrailKit", targets: ["ExhibitTrailKit"]),
    ],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .target(name: "ExhibitTrailKit", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "ExhibitTrailKitTests", dependencies: ["ExhibitTrailKit"], resources: [.copy("Fixtures/v1.sqlite")]),
    ]
)
