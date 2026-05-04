// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChatMarkdown",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ChatMarkdown", targets: ["ChatMarkdown"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "ChatMarkdown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "ChatMarkdownTests",
            dependencies: ["ChatMarkdown"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
