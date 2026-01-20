import Testing
import TreeSitter
import SwiftTreeSitter
import TreeSitterP4
import Foundation
import P4

@testable import Parser

@Test func test_simple_parser() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state start {
               transition drop;
           }
        }
        """

    let program = try #require(Parser.Program(simple_parser_declaration))

    #expect(program.parsers.count == 1)
    #expect(program.parsers[0].states.count == 1)
    #expect(program.parsers[0].states[0].state_name == "start")
    #expect(program.parsers[0].states[0].statements.count == 0)
}

@Test func test_simple_parser_syntax_error() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state
               transition drop;
           }
        }
        """
    #expect(Parser.Program(simple_parser_declaration) == nil)
}

@Test func test_simple_parser_with_statement() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state start {
               true;
               transition drop;
           }
        }
        """

    let program = try #require(Parser.Program(simple_parser_declaration))

    #expect(program.parsers.count == 1)
    #expect(program.parsers[0].states.count == 1)
    #expect(program.parsers[0].states[0].state_name == "start")
    #expect(program.parsers[0].states[0].statements.count == 1)
}

