// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftTreeSitter
import TreeSitterP4

func parse(_ source: String) -> Optional<MutableTree> {

    let p4lang = Language(tree_sitter_p4())

    let p = Parser.init()

    do {
        try p.setLanguage(p4lang)
    } catch {
        return .none
    }

    let result = p.parse(source)

    guard let tree = result else {
        return .none
    }
    return  tree
}
