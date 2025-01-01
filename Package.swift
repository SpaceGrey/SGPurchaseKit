// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SGPurchaseKit",
    platforms: [
           .iOS(.v15),
           .macOS(.v12),
           .tvOS(.v15),
           .watchOS(.v8)      
       ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SGPurchaseKit",
            targets: ["SGPurchaseKit"]),
    ], dependencies: [
        // Add KeychainSwift as a dependency
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "22.0.0")
    ],
    targets: [
        .target(
            name: "SGPurchaseKit",
            dependencies: [
                .product(name: "KeychainSwift", package: "keychain-swift") // <-- 添加到目标依赖中
            ],
            path: "Sources"
        )
    ]
)
