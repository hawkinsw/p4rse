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
import P4Runtime
import P4Lang
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_invalid_types() async throws {
  for invalid_type_name in ["boo", "str", "in"] {
    let simple_parser_declaration = """
          parser main_parser() {
            state start {
              \(invalid_type_name) v = 1;
              transition reject;
            }
          };
      """;

    let err = Program.Compile(simple_parser_declaration)
    guard case Result.Error(let e) = err else {
      assert(false, "Expected an error, but had success")
    }
    #expect(e.msg.contains("Failed to parse a statement element: Could not parse a P4 type from \(invalid_type_name)"))
  }
}

@Test func test_invalid_type_in_assignment() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          string g = "Testing";
          string where_to = "Testing";
          where_to = true;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{112, 16}: Failed to parse a statement element: {112, 8}: Cannot assign value with type Boolean to identifier where_to with type String"
      ),
      Program.Compile(simple_parser_declaration)))
}

@Test func test_invalid_type_in_assignment2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = "testing";
          where_to = where_from;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{114, 22}: Failed to parse a statement element: {114, 8}: Cannot assign value with type String to identifier where_to with type Boolean"
      ),
      Program.Compile(simple_parser_declaration)))
}

@Test func test_invalid_type_in_declaration() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          string where_from = "testing";
          bool where_to = where_from;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "{86, 27}: Failed to parse a statement element: Cannot initialize where_to (with type Boolean) from rvalue with type String"
      ),
      Program.Compile(simple_parser_declaration)))
}

@Test func test_invalid_type_in_declaration2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = where_to;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "{77, 29}: Failed to parse a statement element: Cannot initialize where_from (with type String) from rvalue with type Boolean"
      ),
      Program.Compile(simple_parser_declaration)))
}

@Test func test_expression_in_declaration_initializer() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = 5 == 5 == true;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // 5 == 5 == true
  // true == true
  // true
  #expect(state_result == P4Lang.accept)
}

@Test func test_expression_in_declaration_initializer2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = 5 == 5 == false;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // 5 == 5 == true
  // true == false
  // false
  #expect(state_result == P4Lang.reject)
}

@Test func test_expression_in_declaration_initializer_false() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = 6 == 5 == true;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // 6 == 5 == true
  // false == true
  // false
  #expect(state_result == P4Lang.reject)
}

@Test func test_expression_in_declaration_initializer_false2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = 6 == 5 == false;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // 6 == 5 == false
  // false == false
  // true
  #expect(state_result == P4Lang.accept)
}

@Test func test_expression_in_declaration_initializer_invalid_types() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = false == 5 == true;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // TODO: This test should throw an error.

  // false == 5 == true
  // false == true
  // false
  #expect(state_result == P4Lang.reject)
}

@Test func test_expression_in_declaration_initializer_invalid_types2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ta[0];
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = VarTypeScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "{49, 22}: Failed to parse a statement element: Cannot initialize where_to (with type Boolean) from rvalue with type Int"
      ),
      Program.Compile(simple_parser_declaration, withGlobalInstances: test_types)))
}
