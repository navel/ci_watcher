// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: [
                .product(name: "JWTKit", package: "jwt-kit")
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

