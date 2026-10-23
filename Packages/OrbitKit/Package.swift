// swift-tools-version:5.10
import PackageDescription

// OrbitKit holds everything that doesn't need SwiftUI: the knowledge atlas and its
// content, graph queries (prerequisites, why-paths), 3D layouts and camera math,
// step-by-step simulations, quizzes and spaced review, and learner state.
// It builds on Linux too, so all of it can be tested without a Mac.
let package = Package(
    name: "OrbitKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "OrbitKit", targets: ["OrbitKit"])
    ],
    targets: [
        .target(name: "OrbitKit", resources: [.process("Resources")]),
        .testTarget(name: "OrbitKitTests", dependencies: ["OrbitKit"])
    ]
)
