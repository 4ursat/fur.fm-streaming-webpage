// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FurFMDevice",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FurFMDevice",
            path: "Sources/FurFMDevice",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/FurFMDevice/Info.plist"
                ])
            ]
        )
    ]
)
