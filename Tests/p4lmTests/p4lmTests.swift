import Testing
import TreeSitter
import SwiftTreeSitter
import TreeSitterP4
import Foundation

@testable import p4lm

@Test func example() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state testing {}
        }
        """

    guard let tree = p4lm.parse(simple_parser_declaration) else {
        assert(false, "Could not parse the simple parser declaration.")
    }

    let p4lang = Language(tree_sitter_p4())
    let query = try! SwiftTreeSitter.Query(language: p4lang, data: String("(parserDeclaration (parserTypeDeclaration (parser) parser_name: (identifier) @parser-name))").data(using: String.Encoding.utf8)!)

    let qr = query.execute(in: tree)

    // TODO: Figure out how to actually determine the number of matches.

    guard let parser_declaration = qr.next() else {
        assert(false, "Could not parse the simple parser declaration (No parser declaration).")
    }

    let parser_name_capture = parser_declaration.captures(named: "parser-name")[0]

    #expect(parser_name_capture.node.text == Optional<String>.some("simple"))

}
