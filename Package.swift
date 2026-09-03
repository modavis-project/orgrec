// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OrgRec",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OrgRecCore", targets: ["OrgRecCore"]),
        .executable(name: "OrgRec", targets: ["OrgRecApp"]),
        .executable(name: "OrgRecStress", targets: ["OrgRecStress"]),
        .executable(name: "OrgRecDatasetTool", targets: ["OrgRecDatasetTool"]),
    ],
    targets: [
        .target(
            name: "OrgRecCore",
            exclude: ["Resources/empirical-timbre-model-v1.json"],
            resources: [
                .copy("Resources/demo-roadmap-v1.json"),
                .copy("Resources/crepe-tiny.mlmodelc"),
            ]
        ),
        .executableTarget(
            name: "OrgRecApp",
            dependencies: ["OrgRecCore"]
        ),
        .executableTarget(
            name: "OrgRecStress",
            dependencies: ["OrgRecCore"]
        ),
        .executableTarget(
            name: "OrgRecDatasetTool",
            dependencies: ["OrgRecCore"]
        ),
        .testTarget(
            name: "OrgRecCoreTests",
            dependencies: ["OrgRecCore"]
        ),
        .testTarget(
            name: "OrgRecAppTests",
            dependencies: ["OrgRecApp", "OrgRecCore"]
        ),
    ]
)
