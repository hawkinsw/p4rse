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

@Test func test_array_access() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ta[1] == 2;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Int(), withValue: [
      P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3),
    ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_array_access_invalid_type() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ta[1];
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Int())
  #expect(
    #RequireErrorResult(
      Error(
        withMessage: "{49, 22}: Failed to parse a statement element: {65, 2}: ta does not name an array type"
      ),
      Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  )
}

@Test func test_array_access2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ta[0] == 2;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Int(), withValue: [
      P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3),
    ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}

@Test func test_array_access3() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (ta[0] == 1) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Int(), withValue: [
      P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3),
    ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_array_access4() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (ta[1] == 2) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Int(), withValue: [
      P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3),
    ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_array_access_nested() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          int where_to = ta[0][0];
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Array(withValueType: P4Int())))
  var test_values = ValueScopes().enter()

  let nested = P4ArrayValue(
    withType: P4Int(),
    withValue: [P4IntValue(withValue: 5), P4IntValue(withValue: 2), P4IntValue(withValue: 3)])

  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Array(withValueType: P4Int()), withValue: [nested]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_array_set() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ta[1] = 3;
          bool where_to = ta[1] == 3;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Int(), withValue: [
      P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3),
    ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_array_set_nested() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ta[0][0] = 5;
          int where_to = ta[0][0];
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Array(withValueType: P4Int())))
  var test_values = ValueScopes().enter()

  let nested = P4ArrayValue(
    withType: P4Int(),
    withValue: [P4IntValue(withValue: 1), P4IntValue(withValue: 2), P4IntValue(withValue: 3)])

  test_values = test_values.declare(
    identifier: Identifier(name: "ta"),
    withValue: P4ArrayValue(withType: P4Array(withValueType: P4Int()), withValue: [nested]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}
