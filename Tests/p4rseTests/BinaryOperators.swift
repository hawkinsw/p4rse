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

@Test func test_simple_parser_binary_operator_equal() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (true == true) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_equal_not_equal() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (true == false) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_equal_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 == 5) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_equal_not_equal_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 == 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(state_result == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_equal_invalid_types() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 == true) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())


  // TODO: This test should throw an error.

  #expect(state_result == P4Lang.reject)
}