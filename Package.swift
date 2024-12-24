// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SGPurchaseKit"),

    ]
)
