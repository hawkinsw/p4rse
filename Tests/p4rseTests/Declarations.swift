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

@Test func test_struct_declaration_and_field_write() async throws {
  let simple_parser_declaration = """
      struct Testing {
        bool yesno;
        int count;
      };
      parser main_parser() {
        state start {
          Testing ts;
          ts.yesno = true;
          bool where_to = ts.yesno;
          transition select (where_to) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_declaration_and_field_write_field_read() async throws {
  let simple_parser_declaration = """
      struct Testing {
        bool yesno;
        int count;
      };
      parser main_parser() {
        state start {
          Testing ts;
          ts.yesno = true;
          ts.count = 5;
          transition select (ts.count == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_declaration_and_field_read_defaults() async throws {
  let simple_parser_declaration = """
      struct Testing {
        bool yesno;
        int count;
      };
      parser main_parser() {
        state start {
          Testing ts;
          transition select (ts.count == 0) {
            true: accept;
            false: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_declaration_and_field_read_defaults_sc() async throws {
  let simple_parser_declaration = """
      struct Testing {
        bool yesno;
        int count;
      };
      parser main_parser() {
        state start {
          Testing ts;
          transition select (ts.count) {
            0: accept;
            _: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)
}

@Test func test_struct_declaration_and_field_read_defaults_sc2() async throws {
  let simple_parser_declaration = """
      struct Testing {
        bool yesno;
        int count;
      };
      parser main_parser() {
        state start {
          Testing ts;
          ts.count = 1;
          transition select (ts.count) {
            0: accept;
            _: reject;
          };
        }
      };
    """
  let program = try #UseOkResult(
    Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())
  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}
