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
import P4Lang
import Macros
import P4Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_simple_local_element_variable_declaration() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           bool b = false;
           string s = "testing";
           true;
           false;
           true;
           transition reject;
       }
    };
    """


  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_scope() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state starts {
          bool where_to = false;
          int va = 5;
          transition accept;
        }
        state start {
          bool where_to = true;
          transition select (where_to) {
            false: reject;
            true: starts;
          };
        }
      };
    """


  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)

}

@Test func test_simple_scope2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state starts {
          bool where_to = false;
          int va = 5;
          transition accept;
        }
        state start {
          bool where_to = true;
          where_to = false;
          transition select (where_to) {
            false: reject;
            true: starts;
          };
        }
      };
    """

  
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_assignment() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = "here";
          where_to = false;
          where_from = "there";
          transition select (where_to) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)

}

@Test func test_nested_declaration_assignment() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = "here";
          string where_where = "here";
          if (where_to) {
            bool where_from = true;
            if (where_from) {
              where_to = false;
            }
          }
          where_from = "there";
          transition select (where_to) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}