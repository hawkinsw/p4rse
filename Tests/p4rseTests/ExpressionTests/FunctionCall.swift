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

@Test func test_function_call_scoped_name_collision() async throws {
  let simple_parser_declaration = """
      bool functionb(bool c) {
        return c;
      };
      parser main_parser() {
        state start {
          int c = 5;
          bool b = functionb(true);
          transition select (b) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_function_call_scoped_name_collision2() async throws {
  // Test whether the assignment to c leaks out of the function call scope.
  let simple_parser_declaration = """
      bool functionb(bool c) {
        c = true;
        return c;
      };
      parser main_parser() {
        state start {
          bool c = false;
          bool b = functionb(true);
          transition select (c) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_function_call_scoped_name_collision_inout() async throws {
  let simple_parser_declaration = """
      bool functionb(inout bool c) {
        c = true;
        return c;
      };
      parser main_parser() {
        state start {
          bool c = false;
          bool b = functionb(c);
          transition select (c) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}


@Test func test_function_call_integer_return_value() async throws {
  let simple_parser_declaration = """
      int functionb(int c) {
        return c;
      };
      parser main_parser() {
        state start {
          int c = 5;
          transition select (5 == functionb(c)) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_function_call_integer_return_value2() async throws {
  let simple_parser_declaration = """
      int functionb(int c) {
        return c;
      };
      parser main_parser() {
        state start {
          int c = 5;
          transition select (4 == functionb(c)) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_function_call_invalid_return_type() async throws {
  let simple_parser_declaration = """
      int functionb(int c) {
        return true;
      };
      parser main_parser() {
        state start {
          int c = 5;
          transition select (4 == functionb(c)) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let error = try #UseErrorResult(Program.Compile(simple_parser_declaration))

  #expect(error.msg().contains("{29, 12}: Type of expression in return statement (Boolean) is not compatible with function return type (Int)"))
}
