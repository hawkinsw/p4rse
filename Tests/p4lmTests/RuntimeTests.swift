import Foundation
import P4
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import Parser

@Test func test_simple_runtime() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state start {
               true;
               transition reject;
           }
        }
        """

    let program = try #require(Parser.Program(simple_parser_declaration))

    let runtime = P4.ParserRuntime()

    #expect(runtime.run(program: program.parsers[0], input: P4.Packet()) == P4.Result.Ok)
}

@Test func test_simple_runtime_no_start_state() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state tart {
               true;
               transition reject;
           }
        }
        """

    let program = try #require(Parser.Program(simple_parser_declaration))

    #expect(
        P4.ParserRuntime().run(program: program.parsers[0], input: P4.Packet())
            == Result.Error(Error(withMessage: "Could not find the start state")))

}
