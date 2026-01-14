// swift-tools-version: 6.2

import Foundation
import PackageDescription

var sources = ["src/parser.c"]
if FileManager.default.fileExists(atPath: "src/scanner.c") {
    sources.append("src/scanner.c")
}

let package = Package(
    name: "TreeSitterP4",
    products: [
        .library(name: "TreeSitterP4", targets: ["TreeSitterP4"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", revision: "main"),
    ],
    targets: [
        .target(
            name: "TreeSitterP4",
            dependencies: [],
            path: ".",
            sources: sources,
            resources: [
                .copy("queries")
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .testTarget(
            name: "TreeSitterP4Tests",
            dependencies: [
                "TreeSitterP4",
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
            ],
            path: "bindings/swift/TreeSitterP4Tests"
        )
    ],
    cLanguageStandard: .c11
)
