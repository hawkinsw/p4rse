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

@testable import P4Parser

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


  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, execution_result) = try! #UseOkResult(runtime.run())

  #expect(execution_result.scopes.count == 1)

  guard let scope = execution_result.scopes.current else {
    assert(false)
  }

  // We should be in the accept state.
  #expect(state_result == P4Lang.reject)

  // There are two variables declared.
  #expect(scope.count == 2)

  // Check the names/values of the variables in scope.
  let b = try #require(scope.lookup(identifier: Identifier(name: "b")))
  let s = try #require(scope.lookup(identifier: Identifier(name: "s")))
  #expect(b.eq(rhs: P4BooleanValue(withValue: false)))
  #expect(s.eq(rhs: P4StringValue(withValue: "\"testing\"")))
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


  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, execution_result) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)

  #expect(execution_result.scopes.count == 1)
  let scope = try! #require(execution_result.scopes.current)
  #expect(scope.count == 2)
  let va = try #require(scope.lookup(identifier: Identifier(name: "va")))
  let where_to = try #require(scope.lookup(identifier: Identifier(name: "where_to")))
  #expect(where_to.eq(rhs: P4BooleanValue(withValue: false)))
  #expect(va.eq(rhs: P4IntValue(withValue: 5)))
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

  
  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, execution_result) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 2)

  #expect(state_result == P4Lang.reject)

  #expect(execution_result.scopes.count == 1)
  let scope = try! #require(execution_result.scopes.current)

  #expect(scope.count == 1)
  let where_to = try #require(scope.lookup(identifier: Identifier(name: "where_to")))
  #expect(where_to.eq(rhs: P4BooleanValue(withValue: false)))
}
@Test func test_simple_assignment() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = "here";
          where_to = false;
          where_from = "there";
          transition select (true) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  
  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, execution_result) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(state_result == P4Lang.accept)

  #expect(execution_result.scopes.count == 1)
  let scope = try! #require(execution_result.scopes.current)

  #expect(scope.count == 2)
  let where_to = try #require(scope.lookup(identifier: Identifier(name: "where_to")))
  #expect(where_to.eq(rhs: P4BooleanValue(withValue: false)))
  let where_from = try #require(scope.lookup(identifier: Identifier(name: "where_from")))
  #expect(where_from.eq(rhs: P4StringValue(withValue: "\"there\"")))
}