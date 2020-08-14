// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Cobalt",
    platforms: [
        .iOS(.v10),
    ],
    products: [
        .library(name: "Cobalt", targets: ["Cobalt"]),
        .library(name: "CobaltCache", targets: ["CobaltCache"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.2.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", .upToNextMajor(from: "4.1.0"))
    ],
    targets: [
        .target(
            name: "Cobalt",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "KeychainAccess",
                "Logging"
            ],
            path: "Sources/Core"
        ),
        .target(
            name: "CobaltCache",
            dependencies: [
                "Cobalt"
            ],
            path: "Sources/Cache"
        )
    ],
    swiftLanguageVersions: [ .v5 ]
)
