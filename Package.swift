// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "p4rse",
    platforms: [ .iOS(.v17), .macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "P4Parser",
            targets: ["P4Parser"]
        ),
        .library(
            name: "Common",
            targets: ["Common"]
        ),
        .library(
            name: "P4Lang",
            targets: ["P4Lang"]
        ),
        .library(
            name: "P4Runtime",
            targets: ["P4Runtime"]
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
            name: "P4Parser",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "SwiftTreeSitterLayer", package: "swift-tree-sitter"),
                .product(name: "TreeSitterP4", package: "tree-sitter-p4"),
                .target(name: "TreeSitterExtensions"),
                .target(name: "Common"),
                .target(name: "P4Lang"),
                .target(name: "P4Runtime"),
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
            name: "Common",
            dependencies: ["Macros"]
        ),
        .target(
            name: "P4Lang",
            dependencies: ["Common"]
        ),
        .target(
            name: "P4Runtime",
            dependencies: ["P4Lang", "Common"]
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: ["P4Parser", "P4Runtime", "P4Lang", "Macros", "TreeSitterExtensions", "Common"]
        ),
    ]
)
