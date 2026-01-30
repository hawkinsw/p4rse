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
import Macros
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

@Test func test_simple_local_element_variable_declaration() async throws {
    let simple_parser_declaration = """
        parser simple() {
           state start {
               bool b = false;
               string s = "testing";
               true;
               false;
               transition reject;
           }
        }
        """

    let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
    let runtime = try #UseOkResult(P4.ParserRuntime.create(program: program.parsers[0]))

    // This seems awkward to me!
    // TODO: Is there a better way?
    guard case P4.Result.Ok(let execution_result) = runtime.run(input: P4.Packet()) else {
        assert(false)
    }

    // There should be 1 scope.
    #expect(execution_result.scopes.count == 1)

    guard let scope = execution_result.scopes.current else {
        assert(false)
    }

    // There are two variables declared.
    #expect(scope.count == 2)

    // Check the names/values of the variables in scope.
    let b = try #require(scope.lookup(identifier: Identifier(name: "b")))
    let s = try #require(scope.lookup(identifier: Identifier(name: "s")))
    #expect(b.value_type == ValueType.Boolean(false))
    #expect(s.value_type == ValueType.String("\"testing\""))
}
