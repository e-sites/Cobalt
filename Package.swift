// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Cobalt",
    products: [
        .library(name: "Cobalt", targets: ["Cobalt"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "4.8.2")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift", .upToNextMajor(from: "5.0.1")),
        .package(url: "https://github.com/google/promises", .upToNextMajor(from: "1.2.8")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "3.2.0")),
        .package(url: "https://github.com/Quick/Nimble", .upToNextMajor(from: "8.0.1")),
    ],
    targets: [
        .target(
            name: "Cobalt",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "RxSwift",
                "RxCocoa",
                "PromisesSwift",
                "KeychainAccess"

            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CobaltTests",
            dependencies: [
                "Nimble"

            ],
            path: "CobaltTests"
        )
    ]
)
