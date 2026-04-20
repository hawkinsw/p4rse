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
import P4Lang

@testable import P4Compiler

@Test func test_simple_control_declaration() async throws {
  let simple_parser_declaration = """
    control simple() {
      action a() {
      }
      table t {
        key = {
          true: exact;
        }
      }
      apply {
      }
    };
    """
  let x = { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple"
    default: false
    }
  }
  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))
  #expect(program.InstancesWithTypes(x).count == 1)
}

@Test func test_simple_control_declaration2() async throws {
  let simple_parser_declaration = """
    struct Testing {
    };
    control simple() {
      action a() {
      }
      table t {
        key = {
          true: exact;
        }
      }
      apply {
      }
    };
    control complex() {
      action b() {
      }
      table t {
        key = {
          true: exact;
        }
      }
      apply {
      }
    };
    """

  let filter = { (tipe: P4Type) -> Bool in
    switch tipe.dataType() {
    case let c as Control: c.name == "simple" || c.name == "complex"
    default: false
    }
  }
  let program = try! #UseOkResult(Program.Compile(simple_parser_declaration))
  #expect(program.InstancesWithTypes(filter).count == 2)
}

@Test func test_simple_control_declaration_with_parameters() async throws {
  let simple_parser_declaration = """
    control simple(bool x, bool y) {
      action a() {
      }
      table t {
        key = {
          x: exact;
          y: exact;
        }
      }
      apply {
      }
    };
    """
  #expect(#RequireOkResult(Program.Compile(simple_parser_declaration)))
}

@Test func test_simple_control_declaration_with_action_using_parameter() async throws {
  let simple_parser_declaration = """
    control simple(bool x, bool y) {
      action a(int z) {
        z = 5;
      }
      table t {
        key = {
          x: exact;
          y: exact;
        }
      }
      apply {
      }
    };
    """
  #expect(#RequireOkResult(Program.Compile(simple_parser_declaration)))
}

@Test func test_simple_control_declaration_with_action_using_parameter_wrong_type() async throws {
  let simple_parser_declaration = """
    control simple(bool x, bool y) {
      action a(int z) {
        z = false;
      }
      table t {
        key = {
          x: exact;
          y: exact;
        }
      }
      apply {
      }
    };
    """
  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "{57, 10}: Failed to parse a statement element: {57, 1}: Cannot assign value with type Boolean to identifier z with type Int"
      ),
      Program.Compile(simple_parser_declaration))
  )
}