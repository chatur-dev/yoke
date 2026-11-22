// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Yoke",
    products: [
        .library(name: "YokeCore", targets: ["YokeCore"]),
    ],
    targets: [
        .target(name: "YokeCore"),
        .testTarget(name: "YokeCoreTests", dependencies: ["YokeCore"]),
    ]
)
