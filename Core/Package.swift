// swift-tools-version:5.9
// The model: what a workout is, the order its parts come in, and the clock that
// walks through them. No screens in here, so `swift test` checks it in seconds.
import PackageDescription

let package = Package(
    name: "WorkoutCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WorkoutCore", targets: ["WorkoutCore"])],
    targets: [
        .target(name: "WorkoutCore"),
        .testTarget(name: "WorkoutCoreTests", dependencies: ["WorkoutCore"]),
    ]
)
