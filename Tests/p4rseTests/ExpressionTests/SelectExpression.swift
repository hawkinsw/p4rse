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
import P4Lang
import P4Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_simple_parser_with_transition_select_case_nondefault_expressions() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (true) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_with_transition_select_case_default_expression() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (5) {
            5: reject;
            _: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_with_transition_select_case_default_expression2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (1) {
            5: reject;
            _: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_with_transition_select_case_default_expression3() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (6) {
            5: reject;
            6: reject;
            _: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_with_transition_select_case_invalid_type() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (6) {
            true: reject;
            6: reject;
            _: accept;
          };
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "Error(s) parsing select cases: {81, 12}: Keyset expression type does not match selector expression type"
      ),
      Program.Compile(simple_parser_declaration)))
}

@Test func test_select_expression_selection_order() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (5) {
            5: reject;
            5: accept;
            _: accept;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)

}

@Test func test_select_expression_from_parser_parameters() async throws {
  let simple_parser_declaration = """
      parser main_parser(bool pmtr, string smtr, int imtr) {
         state start {
            transition select (pmtr) {
              true: accept;
              false: reject;
            };
         }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))

  let args = ArgumentList([
    P4BooleanValue(withValue: false), P4StringValue(withValue: "Testing"), P4IntValue(withValue: 5),
  ])
  let (state_result, _) = try! #UseOkResult(runtime.run(withArguments: args))
  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_select_expression_from_parser_parameters2() async throws {
  let simple_parser_declaration = """
      parser main_parser(bool pmtr, string smtr, int imtr) {
         state start {
            transition select (imtr == 5) {
              true: accept;
              false: reject;
            };
         }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))

  let args = ArgumentList([
    P4BooleanValue(withValue: false), P4StringValue(withValue: "Testing"), P4IntValue(withValue: 5),
  ])
  let (state_result, _) = try! #UseOkResult(runtime.run(withArguments: args))
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}