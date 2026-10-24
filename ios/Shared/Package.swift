// swift-tools-version: 6.2
import PackageDescription

// The app ↔ engine contract. Types and one protocol only, no logic.
// Imported by the app target and by the Engine package.
let package = Package(
    name: "EarmarkShared",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "EarmarkShared", targets: ["EarmarkShared"]),
    ],
    targets: [
        .target(name: "EarmarkShared"),
    ]
)
