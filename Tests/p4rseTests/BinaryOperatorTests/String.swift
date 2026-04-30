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

// String binary operator tests ...

@Test func test_simple_parser_binary_operator_equal_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("five" == "five") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_equal_not_equal_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("five" == "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_less_than_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("five" < "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_less_than_equal_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("six" <= "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_greater_than_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("twelve" > "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_greater_than_equal_string() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("twelve" >= "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_less_than_string_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("six" < "five") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_less_than_equal_string_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("six" <= "five") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_greater_than_string_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("five" > "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_greater_than_equal_string_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select ("five" >= "six") {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}
