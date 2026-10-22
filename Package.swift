// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WakeCore", platforms: [.macOS(.v15)], products: [.library(name: "WakeCore", targets: ["WakeCore"])], targets: [.target(name: "WakeCore", path: "WakeUpPlz/Domain"), .testTarget(name: "WakeCoreTests", dependencies: ["WakeCore"], path: "Tests/WakeCoreTests")])
