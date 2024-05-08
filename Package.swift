// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "BMQuadTree",
    platforms: [
        .macOS(.v10_14), .iOS(.v13), .tvOS(.v13)
    ],
    products: [
        .library(
            name: "BMQuadTree",
            targets: ["BMQuadTree"])
    ],
    targets: [
        .target(
            name: "BMQuadTree",
            dependencies: [], 
            path: "BMQuadTree/Classes",
        )
    ]
)
