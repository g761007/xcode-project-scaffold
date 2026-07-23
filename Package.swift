// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "xcode-project-scaffold",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "xscaffold", targets: ["xscaffold"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
    ],
    targets: [
        // The published contract. Consumed by scaffold.yml, JSON output and the
        // Skill. Deliberately has no dependencies: it must never reach the file
        // system or spawn a process.
        .target(
            name: "ScaffoldSchema",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .target(
            name: "ScaffoldCore",
            dependencies: [
                "ScaffoldSchema",
                .product(name: "Yams", package: "Yams")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .executableTarget(
            name: "xscaffold",
            dependencies: [
                "ScaffoldCore",
                // Declared explicitly rather than relied on transitively: the
                // CLI names schema types directly, in --version and in JSON
                // output.
                "ScaffoldSchema",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .testTarget(
            name: "ScaffoldSchemaTests",
            dependencies: ["ScaffoldSchema"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .testTarget(
            name: "ScaffoldCoreTests",
            dependencies: ["ScaffoldCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // Runs the built executable. The CLI contract — exit codes, and what
        // arrives on stdout under --output json — is what scripts and the Skill
        // are written against, and none of it can be checked by importing a
        // module: it only exists once a process has run and exited.
        .testTarget(
            name: "CommandLineTests",
            dependencies: ["xscaffold", "ScaffoldCore", "ScaffoldSchema"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
