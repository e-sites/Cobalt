// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Cobalt",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(name: "Cobalt", targets: ["Cobalt"]),
        .library(name: "CobaltCache", targets: ["CobaltCache"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "4.9.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "5.0.1")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", .upToNextMajor(from: "4.1.0"))
    ],
    targets: [
        .target(
            name: "Cobalt",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "RxSwift",
                "RxCocoa",
                "KeychainAccess"
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
