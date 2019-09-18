// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Cobalt",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(name: "Cobalt", targets: ["Cobalt"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/google/promises", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0")),
    ],
    targets: [
        .target(
            name: "Cobalt",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "RxSwift",
                "RxCocoa",
                "Promises",
                "KeychainAccess"
            ],
            path: "Sources"
        )
    ]
)
