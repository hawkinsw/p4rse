// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "p4lm",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Parser",
            targets: ["Parser"]
        ),
        .library(
            name: "P4",
            targets: ["P4"]
        )
    ],
    dependencies: [
        .package(path: "./tree-sitter-p4"),
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", revision: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Parser",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "SwiftTreeSitterLayer", package: "swift-tree-sitter"),
                .product(name: "TreeSitterP4", package: "tree-sitter-p4"),
                .target(name: "P4")
            ],
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "P4",
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: ["Parser", "P4"]
        ),
    ]
)
