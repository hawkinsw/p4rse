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

@Test func test_control_single_key() async throws {
  let simple_parser_declaration = """
    control simple(inout int result, bool x) {
      action a() {
        result = 5;
      }
      action b() {
        result = 7;
      }
      table t {
        key = {
          x: exact;
        }
        actions = {
          a;
          b;
        }
      }
      apply {
      }
    };
    """

  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))

  // Pull the control out of the compiled program.
  let controls = program.InstancesWithTypes() { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  var control = ((controls[0].dataType() as P4DataType) as! Control)

  // Add entries to the table.
  control = control.updateTable(
    addEntry: (
      P4Value(P4BooleanValue(withValue: true)),
      TypedIdentifier(name: "a", withType: P4Type(Action()))
    )
  ).updateTable(
    addEntry: (
      P4Value(P4BooleanValue(withValue: false)),
      TypedIdentifier(name: "b", withType: P4Type(Action()))
    ))

  // Set a variable in the global scope for the inout first parameter.
  var global_values = VarValueScopes().enter()
  global_values = global_values.declare(
    identifier: Identifier(name: "result_arg"),
    withValue: P4Value(
          P4IntValue(withValue: 0),
          P4Type(P4Int())))

  let runtime = try #UseOkResult(
    P4Runtime.Runtime<P4TableHitMissValue, Control>.create(control: control, withGlobalValues: global_values))

  let (hit_miss, updated_execution) = try #UseOkResult(runtime.run(
    withArguments: ArgumentList([
      Argument(TypedIdentifier(name: "result_arg", withType: P4Type(P4Int())), atIndex: 0),
      Argument(P4Value(P4BooleanValue(withValue: true)), atIndex: 1),
    ])))

  // We expect there to be a hit.
  #expect(hit_miss == P4TableHitMissValue.Hit)

  // And that the proper action was invoked.
  let result_arg = try #UseOkResult(updated_execution.scopes.lookup(identifier: Identifier(name: "result_arg")))
  #expect(result_arg.eq(P4Value(P4IntValue(withValue: 5))))
}

@Test func test_control_single_key_false() async throws {
  let simple_parser_declaration = """
    control simple(inout int result, bool x) {
      action a() {
        result = 5;
      }
      action b() {
        result = 7;
      }
      table t {
        key = {
          x: exact;
        }
        actions = {
          a;
          b;
        }
      }
      apply {
      }
    };
    """

  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))

  // Pull the control out of the compiled program.
  let controls = program.InstancesWithTypes() { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  var control = ((controls[0].dataType() as P4DataType) as! Control)

  // Add entries to the table.
  control = control.updateTable(
    addEntry: (
      P4Value(P4BooleanValue(withValue: true)),
      TypedIdentifier(name: "a", withType: P4Type(Action()))
    )
  ).updateTable(
    addEntry: (
      P4Value(P4BooleanValue(withValue: false)),
      TypedIdentifier(name: "b", withType: P4Type(Action()))
    ))

  // Set a variable in the global scope for the inout first parameter.
  var global_values = VarValueScopes().enter()
  global_values = global_values.declare(
    identifier: Identifier(name: "result_arg"),
    withValue: P4Value(
          P4IntValue(withValue: 0),
          P4Type(P4Int())))

  let runtime = try #UseOkResult(
    P4Runtime.Runtime<P4TableHitMissValue, Control>.create(control: control, withGlobalValues: global_values))

  let (hit_miss, updated_execution) = try #UseOkResult(runtime.run(
    withArguments: ArgumentList([
      Argument(TypedIdentifier(name: "result_arg", withType: P4Type(P4Int())), atIndex: 0),
      Argument(P4Value(P4BooleanValue(withValue: false)), atIndex: 1),
    ])))

  // We expect there to be a hit.
  #expect(hit_miss == P4TableHitMissValue.Hit)

  // And that the proper action was invoked.
  let result_arg = try #UseOkResult(updated_execution.scopes.lookup(identifier: Identifier(name: "result_arg")))
  #expect(result_arg.eq(P4Value(P4IntValue(withValue: 7))))
}

@Test func test_control_single_integer_key_hit() async throws {
  let simple_parser_declaration = """
    control simple(inout int result, int x) {
      action a() {
        result = 5;
      }
      action b() {
        result = 7;
      }
      table t {
        key = {
          x: exact;
        }
        actions = {
          a;
          b;
        }
      }
      apply {
      }
    };
    """

  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))

  // Pull the control out of the compiled program.
  let controls = program.InstancesWithTypes() { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  var control = ((controls[0].dataType() as P4DataType) as! Control)

  // Add entries to the table.
  control = control.updateTable(
    addEntry: (
      P4Value(P4IntValue(withValue: 5)),
      TypedIdentifier(name: "a", withType: P4Type(Action()))
    )
  ).updateTable(
    addEntry: (
      P4Value(P4IntValue(withValue: 2)),
      TypedIdentifier(name: "b", withType: P4Type(Action()))
    ))

  // Set a variable in the global scope for the inout first parameter.
  var global_values = VarValueScopes().enter()
  global_values = global_values.declare(
    identifier: Identifier(name: "result_arg"),
    withValue: P4Value(
          P4IntValue(withValue: 0),
          P4Type(P4Int())))

  let runtime = try #UseOkResult(
    P4Runtime.Runtime<P4TableHitMissValue, Control>.create(control: control, withGlobalValues: global_values))

  let (hit_miss, updated_execution) = try #UseOkResult(runtime.run(
    withArguments: ArgumentList([
      Argument(TypedIdentifier(name: "result_arg", withType: P4Type(P4Int())), atIndex: 0),
      Argument(P4Value(P4IntValue(withValue: 5)), atIndex: 1),
    ])))

  // We expect there to be a hit.
  #expect(hit_miss == P4TableHitMissValue.Hit)

  let result_arg = try #UseOkResult(updated_execution.scopes.lookup(identifier: Identifier(name: "result_arg")))
  #expect(result_arg.eq(P4Value(P4IntValue(withValue: 5))))
}

@Test func test_control_single_integer_key_miss() async throws {
  let simple_parser_declaration = """
    control simple(inout int result, int x) {
      action a() {
        result = 5;
      }
      action b() {
        result = 7;
      }
      table t {
        key = {
          x: exact;
        }
        actions = {
          a;
          b;
        }
      }
      apply {
      }
    };
    """

  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))

  // Pull the control out of the compiled program.
  let controls = program.InstancesWithTypes() { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  var control = ((controls[0].dataType() as P4DataType) as! Control)

  // Add entries to the table.
  control = control.updateTable(
    addEntry: (
      P4Value(P4IntValue(withValue: 1)),
      TypedIdentifier(name: "a", withType: P4Type(Action()))
    )
  ).updateTable(
    addEntry: (
      P4Value(P4IntValue(withValue: 2)),
      TypedIdentifier(name: "b", withType: P4Type(Action()))
    ))

  // Set a variable in the global scope for the inout first parameter.
  var global_values = VarValueScopes().enter()
  global_values = global_values.declare(
    identifier: Identifier(name: "result_arg"),
    withValue: P4Value(
          P4IntValue(withValue: 0),
          P4Type(P4Int())))

  let runtime = try #UseOkResult(
    P4Runtime.Runtime<P4TableHitMissValue, Control>.create(control: control, withGlobalValues: global_values))

  let (hit_miss, updated_execution) = try #UseOkResult(runtime.run(
    withArguments: ArgumentList([
      Argument(TypedIdentifier(name: "result_arg", withType: P4Type(P4Int())), atIndex: 0),
      Argument(P4Value(P4IntValue(withValue: 3)), atIndex: 1),
    ])))

  // We expect there to be a hit.
  #expect(hit_miss == P4TableHitMissValue.Miss)

  let result_arg = try #UseOkResult(updated_execution.scopes.lookup(identifier: Identifier(name: "result_arg")))
  #expect(result_arg.eq(P4Value(P4IntValue(withValue: 0))))
}

@Test func test_control_multiple_keys() async throws {
  let simple_parser_declaration = """
    control simple(inout int result, bool x, int f) {
      action a() {
        result = 5;
      }
      action b() {
        result = 7;
      }
      table t {
        key = {
          x: exact;
          f: exact;
        }
        actions = {
          a;
          b;
        }
      }
      apply {
      }
    };
    """

  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))

  // Pull the control out of the compiled program.
  let controls = program.InstancesWithTypes() { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  var control = ((controls[0].dataType() as P4DataType) as! Control)

  // Add entries to the table.
  control = control.updateTable(
    addEntry: (
      P4Value(P4BooleanValue(withValue: true)),
      TypedIdentifier(name: "a", withType: P4Type(Action()))
    )
  ).updateTable(
    addEntry: (
      P4Value(P4IntValue(withValue: 5)),
      TypedIdentifier(name: "b", withType: P4Type(Action()))
    ))

  // Set a variable in the global scope for the inout first parameter.
  var global_values = VarValueScopes().enter()
  global_values = global_values.declare(
    identifier: Identifier(name: "result_arg"),
    withValue: P4Value(
          P4IntValue(withValue: 0),
          P4Type(P4Int())))

  let runtime = try #UseOkResult(
    P4Runtime.Runtime<P4TableHitMissValue, Control>.create(control: control, withGlobalValues: global_values))

  let (hit_miss, updated_execution) = try #UseOkResult(runtime.run(
    withArguments: ArgumentList([
      Argument(TypedIdentifier(name: "result_arg", withType: P4Type(P4Int())), atIndex: 0),
      Argument(P4Value(P4BooleanValue(withValue: false)), atIndex: 1),
      Argument(P4Value(P4IntValue(withValue: 5)), atIndex: 2),
    ])))

  // We expect there to be a hit.
  #expect(hit_miss == P4TableHitMissValue.Hit)

  // And that the proper action was invoked.
  let result_arg = try #UseOkResult(updated_execution.scopes.lookup(identifier: Identifier(name: "result_arg")))
  #expect(result_arg.eq(P4Value(P4IntValue(withValue: 7))))

}
