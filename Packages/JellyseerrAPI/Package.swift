// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JellyseerrAPI",
    platforms: [.iOS(.v26), .tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "JellyseerrAPI", targets: ["JellyseerrAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "JellyseerrAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ]
        )
    ]
)
