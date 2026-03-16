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
    #expect(
      #RequireErrorResult(
        Error(withMessage: "Type name not recognized"),
        Types.CompileBasicType(type: invalid_type_name)))
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
        "{112, 16}: Failed to parse a statement element: {112, 16}: Cannot assign value of type Boolean to where_to (with type String)"
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
          "{114, 22}: Failed to parse a statement element: {114, 22}: Cannot assign value of type String to where_to (with type Boolean)"
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
  var test_types = LexicalScopes().enter()
  test_types = test_types.declare(identifier: Identifier(name: "ta"), withValue: P4Array(withValueType: P4Int()))
  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "{49, 22}: Failed to parse a statement element: Cannot initialize where_to (with type Boolean) from rvalue with type Int"
      ),
      Program.Compile(simple_parser_declaration, withGlobalTypes: test_types)))
}


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
  var test_types = LexicalScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
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
  var test_types = LexicalScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: false),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
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
  var test_types = LexicalScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 5),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
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
  var test_types = LexicalScopes().enter()
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)
  test_types = test_types.declare(identifier: Identifier(name: "ts"), withValue: struct_type)

  var test_values = ValueScopes().enter()
  test_values = test_values.declare(
    identifier: Identifier(name: "ts"),
    withValue: P4StructValue(withType: struct_type, andInitializers: [
      P4BooleanValue(withValue: true),
      P4IntValue(withValue: 8),
    ]))

  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
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
  var test_types = LexicalScopes().enter()

  let ty_fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])
  let ty_struct_type = P4Struct(withName: Identifier(name: "nested"), andFields: ty_fields)

  let ts_fields = P4StructFields([P4StructFieldIdentifier(name: "ty", withType: ty_struct_type)])
  let ts_struct_type = P4Struct(withName: Identifier(name: "outer"), andFields: ts_fields)

  test_types = test_types.declare(identifier: Identifier(name: "ts"), withValue: ts_struct_type)

  var test_values = ValueScopes().enter()

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
    Program.Compile(simple_parser_declaration, withGlobalTypes: test_types))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program, withInitialValues: test_values))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(state_result == P4Lang.accept)
}