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

@testable import P4Parser

@Test func test_simple_runtime() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           true;
           transition accept;
       }
    };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  // We should be in the accept state.
  #expect(state_result == P4Lang.accept)
}

@Test func test_simple_runtime_to_accept() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state start {
           true;
           transition reject;
       }
    };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  // We should be in the accept state.
  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_runtime_no_start_state() async throws {
  let simple_parser_declaration = """
    parser main_parser() {
       state tart {
           true;
           transition reject;
       }
    };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))

  #expect(
    #RequireErrorResult<ParserRuntime>(
      Error(withMessage: "No start state defined"),
      P4Runtime.ParserRuntime.create(program: program)))
}

@Test func test_simple_parser_with_transition_select_expression() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
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
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)

  #expect(state_result == P4Lang.accept)
}

@Test func test_simple_parser_with_transition_select_expression_to_reject() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          transition select (false) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)
  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_parser_with_conditional_statement() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool x = true;
          string check = "Invalid";
          if (x) {
            x = false;
            check = "valid";
          };
          transition select (x) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, exec_result) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)
  #expect(state_result == P4Lang.reject)

  let x = try #UseOkResult(exec_result.scopes.lookup(identifier: Identifier(name: "x")))
  #expect(x.eq(rhs: P4BooleanValue(withValue: false)))
  let check = try #UseOkResult(exec_result.scopes.lookup(identifier: Identifier(name: "check")))
  #expect(check.eq(rhs: P4StringValue(withValue: "\"valid\"")))
}

@Test func test_simple_parser_with_conditional_statement_and_else() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool x = false;
          string check = "Invalid";
          if (x) {
            x = false;
            check = "a";
          } else {
            x = true;
            check = "b";
          };
          transition select (x) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Parse(simple_parser_declaration))
  let parser = try #UseOkResult(program.find_parser(withName: Identifier(name: "main_parser")))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, exec_result) = try! #UseOkResult(runtime.run())

  #expect(parser.states.count() == 1)
  #expect(state_result == P4Lang.accept)

  let x = try #UseOkResult(exec_result.scopes.lookup(identifier: Identifier(name: "x")))
  #expect(x.eq(rhs: P4BooleanValue(withValue: true)))
  let check = try #UseOkResult(exec_result.scopes.lookup(identifier: Identifier(name: "check")))
  #expect(check.eq(rhs: P4StringValue(withValue: "\"b\"")))
}
