// swift-tools-version: 6.2
import PackageDescription

// The voice engine: speech detection, quality checks, signatures, matching, decisions.
// The app links the `Engine` library. `earmark-calibrate` runs on the Mac to turn
// calibration recordings into the similarity CSV (PRD 6.4).
let package = Package(
    name: "Engine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Engine", targets: ["Engine"]),
        .executable(name: "earmark-calibrate", targets: ["Calibrate"]),
    ],
    dependencies: [
        .package(path: "../Shared"),
        // Pinned exactly (PRD 8). Bump only on purpose, and commit Package.resolved.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7"),
    ],
    targets: [
        .target(
            name: "Engine",
            dependencies: [
                .product(name: "EarmarkShared", package: "Shared"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .executableTarget(
            name: "Calibrate",
            dependencies: ["Engine"]
        ),
        .testTarget(
            name: "EngineTests",
            dependencies: [
                "Engine",
                .product(name: "EarmarkShared", package: "Shared"),
            ]
        ),
    ]
)
