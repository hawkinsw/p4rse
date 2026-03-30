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

// Integer binary operator tests ...

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

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
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

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_less_than_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 < 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_less_than_equal_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 <= 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_less_than_equal_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (6 <= 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_greater_than_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (7 > 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_greater_than_equal_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (6 >= 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_greater_than_equal_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (7 >= 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_less_than_integer_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (6 < 5) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_less_than_integer_not2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 < 5) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_less_than_equal_integer_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (6 <= 5) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_greater_than_integer_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 > 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_greater_than_integer_not2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 > 5) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}

@Test func test_simple_parser_binary_operator_greater_than_equal_integer_not() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (5 >= 6) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}


// Add Integers

@Test func test_simple_parser_binary_operator_add_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (5 + 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_add_non_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (true + 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 16}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_add_non_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (5 + false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 17}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_add_non_integer3() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (false + false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 21}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

// Subtract Integers

@Test func test_simple_parser_binary_operator_subtract_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (0 == (5 - 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_subtract_non_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (true - 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 16}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_subtract_non_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (5 - false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 17}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_subtract_non_integer3() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (false - false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 21}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}


// Multiply Integers

@Test func test_simple_parser_binary_operator_multiply_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (25 == (5 * 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_multiply_non_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (true * 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 16}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_multiply_non_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (5 * false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 17}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_multiply_non_integer3() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (false * false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 21}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

// Divide Integers

@Test func test_simple_parser_binary_operator_divide_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (1 == (5 / 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  let program = try #UseOkResult(Program.Compile(simple))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_simple_parser_binary_operator_divide_non_integer() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (true / 5)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 16}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_divide_non_integer2() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (5 / false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 17}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

@Test func test_simple_parser_binary_operator_divide_non_integer3() async throws {
  let simple = """
    parser main_parser() {
       state start {
           transition select (10 == (false / false)) {
              true: accept;
              false: reject;
           };
       }
    };
  """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "{72, 21}: Could not parse transition select expression selector expression: Mathematical operation on operands with non-int type is not allowed"
      ),
      Program.Compile(simple)))
}

