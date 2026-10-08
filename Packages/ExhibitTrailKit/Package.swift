// swift-tools-version:6.0
import PackageDescription

// Pure-Swift visit domain. No UI, networking or Apple-only frameworks.
// Visit storage and pacing arrive in issues #2 and #4.
let package = Package(
    name: "ExhibitTrailKit",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "ExhibitTrailKit", targets: ["ExhibitTrailKit"]),
    ],
    targets: [
        .target(name: "ExhibitTrailKit"),
        .testTarget(name: "ExhibitTrailKitTests", dependencies: ["ExhibitTrailKit"]),
    ]
)
