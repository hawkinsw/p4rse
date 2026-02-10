// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.
//
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

import Common
import Foundation
import Macros
import Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import Parser

@Test func test_simple_parser() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           transition start;
       }
    };
    """

  let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))

  #expect(parser.states.count() == 1)
  let state = try! #require(parser.states.find(withName: "start"))
  #expect(state.state_name == "start")
  #expect(state.statements.count == 0)

  #expect(#RequireOkResult(parser.states.semantic_check()))
  let next_state = try! #require(state.next_state)
  #expect(next_state == state)
}

@Test func test_simple_parser_syntax_error() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state
           transition start;
       }
    };
    """
  #expect(
    #RequireErrorResult(
      Error(withMessage: "Could not compile the P4 program"),
      Parser.Program(simple_parser_declaration)))
}

@Test func test_simple_parser_with_statement() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           true;
           transition start;
       }
    };
    """

  let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))

  #expect(parser.states.count() == 1)

  let state = try! #require(parser.states.find(withName: "start"))
  #expect(state.state_name == "start")
  #expect(state.statements.count == 1)
}

@Test func test_simple_parser_with_instantiation() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           true;
           transition start;
       }
    };
    bool() main;
    """

  let program = try #UseOkResult(Parser.Program(simple_parser_declaration))
  #expect(#RequireOkResult(program.find_parser(withName: Identifier(name: "main_parser"))))
}
