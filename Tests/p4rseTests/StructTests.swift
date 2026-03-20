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

@Test func test_field_access() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ts.yesno;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = VarValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_access_declared() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing ts;
          ts.yesno = true;
          bool where_to = ts.yesno;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = TypeTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

 let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: .none, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_access_declared2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          Testing ts;
          ts.yesno = true;
          ts.count = 5;
          bool where_to = ts.yesno;
          transition select (ts.count == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_types = TypeTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "Testing"), withValue: struct_type)

 let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: .none, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_access_opp() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = ts.yesno;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = VarValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: false),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.reject)
}


@Test func test_field_access2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (ts.count == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = VarValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_access2_opp() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (ts.count == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = VarValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 8),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.reject)
}

@Test func test_field_access_nested() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          int where_to = ts.ty.count;
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()

  let ty_fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let ty_struct_type = P4Struct(withName: Identifier(name: "nested"), andFields: ty_fields)

  let ts_fields = P4StructFields([P4StructFieldIdentifier(name: "ty", withType: ty_struct_type)])
  let ts_struct_type = P4Struct(withName: Identifier(name: "outer"), andFields: ts_fields)

  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: ts_struct_type)

  var test_values = VarValueScopes().enter()

  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(
      withType: ts_struct_type,
      andInitializers: [
        P4StructValue(
          withType: ty_struct_type,
          andInitializers: [
            P4BooleanValue(withValue: true),
            P4IntValue(withValue: 5),
          ])
      ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_write() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ts.yesno = true;
          bool where_to = ts.yesno;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = VarValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: false),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_write_invalid_type() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ts.yesno = 5;
          transition accept;
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  #expect(
    #RequireErrorResult(
      Error(
        withMessage: "{49, 13}: Failed to parse a statement element: {49, 8}: Cannot assign value of type Int to field with type Boolean"
      ),
      Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  )
}

@Test func test_field_write_nested() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ts.ty.count = 5;
          int where_to = ts.ty.count;
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()

  let ty_fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let ty_struct_type = P4Struct(withName: Identifier(name: "nested"), andFields: ty_fields)

  let ts_fields = P4StructFields([P4StructFieldIdentifier(name: "ty", withType: ty_struct_type)])
  let ts_struct_type = P4Struct(withName: Identifier(name: "outer"), andFields: ts_fields)

  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: ts_struct_type)

  var test_values = VarValueScopes().enter()

  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(
      withType: ts_struct_type,
      andInitializers: [
        P4StructValue(
          withType: ty_struct_type,
          andInitializers: [
            P4BooleanValue(withValue: true),
            P4IntValue(withValue: 7),
          ])
      ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_write_nested2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ts.ty.count = 3;
          ts.ty.count = 5;
          int where_to = ts.ty.count;
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()

  let ty_fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let ty_struct_type = P4Struct(withName: Identifier(name: "nested"), andFields: ty_fields)

  let ts_fields = P4StructFields([P4StructFieldIdentifier(name: "ty", withType: ty_struct_type)])
  let ts_struct_type = P4Struct(withName: Identifier(name: "outer"), andFields: ts_fields)

  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: ts_struct_type)

  var test_values = VarValueScopes().enter()

  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(
      withType: ts_struct_type,
      andInitializers: [
        P4StructValue(
          withType: ty_struct_type,
          andInitializers: [
            P4BooleanValue(withValue: true),
            P4IntValue(withValue: 7),
          ])
      ]))
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}

@Test func test_field_write_nested_invalid_type() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          ts.ty.count = false;
          int where_to = ts.ty.count;
          transition select (where_to == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  var test_declarations = VarTypeScopes().enter()

  let ty_fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let ty_struct_type = P4Struct(withName: Identifier(name: "nested"), andFields: ty_fields)

  let ts_fields = P4StructFields([P4StructFieldIdentifier(name: "ty", withType: ty_struct_type)])
  let ts_struct_type = P4Struct(withName: Identifier(name: "outer"), andFields: ts_fields)

  test_declarations = test_declarations.declare(identifier: Identifier(name: "ts"), withValue: ts_struct_type)

  #expect(
    #RequireErrorResult(
      Error(
        withMessage: "{49, 20}: Failed to parse a statement element: {49, 11}: Cannot assign value of type Boolean to field with type Int"
      ),
      Program.Compile(simple_parser_declaration, withGlobalInstances: test_declarations))
  )

}
