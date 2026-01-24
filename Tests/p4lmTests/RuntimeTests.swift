// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import P4
import P4Macros
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

    let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
    #expect(#RequireOkResult(P4.ParserRuntime.create(program: program.parsers[0])))
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

    let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
    #expect(
        #RequireErrorResult<ParserRuntime>(
            Error(withMessage: "Could not find the start state"),
            P4.ParserRuntime.create(program: program.parsers[0])))
}

@Test func test_simple_runtime_output() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state start {
               bool b = true;
               transition reject;
           }
        }
        """

    /*
    TODO: Add tests for "semantic" parsing failures. Here's an example!
    print(Parser.Program(simple_parser_declaration))
    #expect(
        #RequireErrorResult(
            Error(
                withMessage:
                    "Failed to parse a local element: <capture 1 \"state-local-elements\": <parserLocalElements range: {42, 14} childCount: 2>>"
            ), Parser.Program(simple_parser_declaration)))
    */
    let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
    let runtime = try #UseOkResult(P4.ParserRuntime.create(program: program.parsers[0]))
    #expect(runtime.run(input: P4.Packet()) == P4.Result.Ok(Nothing()))
}
