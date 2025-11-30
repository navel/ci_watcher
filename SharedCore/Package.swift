// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: [
                .product(name: "SwiftJWT", package: "Swift-JWT")
            ],
            path: "Sources/SharedCore"
        ),
        .testTarget(
            name: "SharedCoreTests",
            dependencies: ["SharedCore"],
            path: "Tests/SharedCoreTests"
        ),
    ]
)

