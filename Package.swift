// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIMailComposer",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "AIMailComposer",
            path: "AIMailComposer",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
