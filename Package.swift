// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "p4lm",
    platforms: [ .iOS(.v17), .macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Parser",
            targets: ["Parser"]
        ),
        .library(
            name: "P4",
            targets: ["P4"]
        ),
    ],
    dependencies: [
        .package(path: "./tree-sitter-p4"),
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", revision: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "509.0.0"),
    ],
    targets: [
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]),
        .target(
            name: "Parser",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "SwiftTreeSitterLayer", package: "swift-tree-sitter"),
                .product(name: "TreeSitterP4", package: "tree-sitter-p4"),
                .target(name: "TreeSitterExtensions"),
                .target(name: "P4"),
            ],
        ),
        .target(
            name: "TreeSitterExtensions",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "SwiftTreeSitterLayer", package: "swift-tree-sitter"),
            ],
        ),
        .target(
            name: "P4",
            dependencies: ["Macros", "TreeSitterExtensions"]
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: ["Parser", "P4", "Macros", "TreeSitterExtensions"]
        ),
    ]
)
