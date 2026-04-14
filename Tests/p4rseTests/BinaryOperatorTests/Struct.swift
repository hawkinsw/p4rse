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

@Test func test_struct_equality_empty() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing one;
          Testing two;
          transition select (one == two) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Type(P4Boolean())),
    P4StructFieldIdentifier(name: "count", withType: P4Type(P4Int())),
  ])
  var test_types = TypeTypeScopes().enter()
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations, withGlobalTypes: test_types))

  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_equality_one_empty() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing one;
          Testing two;

          one.yesno = true;

          transition select (one == two) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Type(P4Boolean())),
    P4StructFieldIdentifier(name: "count", withType: P4Type(P4Int())),
  ])
  var test_types = TypeTypeScopes().enter()
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations, withGlobalTypes: test_types))

  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_struct_equality_neither_empty() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing one;
          Testing two;

          one.yesno = true;
          two.yesno = true;

          transition select (one == two) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Type(P4Boolean())),
    P4StructFieldIdentifier(name: "count", withType: P4Type(P4Int())),
  ])
  var test_types = TypeTypeScopes().enter()
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations, withGlobalTypes: test_types))

  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_equality_neither_empty2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing one;
          Testing two;

          one.yesno = true;
          two.yesno = true;

          one.count = 5;
          two.count = 5;

          transition select (one == two) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Type(P4Boolean())),
    P4StructFieldIdentifier(name: "count", withType: P4Type(P4Int())),
  ])
  var test_types = TypeTypeScopes().enter()
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations, withGlobalTypes: test_types))

  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_equality_neither_empty3() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing one;
          Testing two;

          one.yesno = true;
          two.yesno = true;

          one.count = 5;
          two.count = 6;

          transition select (one == two) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Type(P4Boolean())),
    P4StructFieldIdentifier(name: "count", withType: P4Type(P4Int())),
  ])
  var test_types = TypeTypeScopes().enter()
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations, withGlobalTypes: test_types))

  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}


