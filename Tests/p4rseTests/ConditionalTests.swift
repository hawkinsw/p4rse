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

@Test func test_simple_parser_with_conditional_statement() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool x = true;
          string check = "Invalid";
          if (x) {
            x = false;
            check = "valid";
          }
          transition select (x) {
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
          }
          transition select (x) {
            false: reject;
            true: accept;
          };
        }
      };
    """

  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)

}
