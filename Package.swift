// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Cobalt",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "Cobalt", targets: ["Cobalt"]),
        .library(name: "CobaltCache", targets: ["CobaltCache"]),
        .library(name: "CobaltStubbing", targets: ["CobaltStubbing"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.2.1")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", .upToNextMajor(from: "4.2.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "11.0.0")),
        .package(url: "https://github.com/UnlockAgency/DebugMasking.git", .upToNextMajor(from: "1.0.1")),
    ],
    targets: [
        .target(
            name: "Cobalt",
            dependencies: [
                "Alamofire",
                "KeychainAccess",
                .product(name: "Logging", package: "swift-log"),
                "DebugMasking"
            ],
            path: "Sources/Core",
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "CobaltCache",
            dependencies: [
                "Cobalt"
            ],
            path: "Sources/Cache"
        ),
        .target(
            name: "CobaltStubbing",
            dependencies: [
                "Alamofire",
                 "Cobalt"
            ],
            path: "Sources/Stubbing"
        ),
        .testTarget(
            name: "CobaltTesting",
            dependencies: [
                "Nimble",
                "Cobalt",
                "CobaltStubbing",
                "CobaltCache"
            ],
            path: "CobaltTests"
        )
    ],
    swiftLanguageVersions: [ .v5 ]
)
