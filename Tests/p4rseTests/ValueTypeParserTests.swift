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
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Parser

@Test func test_invalid_types() async throws {
  for invalid_type_name in ["boo", "str", "in"] {
    #expect(
      #RequireErrorResult(
        Error(withMessage: "Type name not recognized"),
        Types.ParseBasicType(type: invalid_type_name)))
  }
}

@Test func test_invalid_type_in_assignment() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          string g = "Testing";
          string where_to = "Testing";
          where_to = true;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
        "Failed to parse a statement element: Cannot assign value of type Boolean to where_to (with type String)"
      ),
      Program.Parse(simple_parser_declaration)))
}

@Test func test_invalid_type_in_assignment2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = "testing";
          where_to = where_from;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "Failed to parse a statement element: Cannot assign value of type String to where_to (with type Boolean)"
      ),
      Program.Parse(simple_parser_declaration)))
}

@Test func test_invalid_type_in_declaration() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          string where_from = "testing";
          bool where_to = where_from;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "Failed to parse local element: Cannot initialize where_to (with type Boolean) from rvalue with type String"
      ),
      Program.Parse(simple_parser_declaration)))
}

@Test func test_invalid_type_in_declaration2() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state start {
          bool where_to = true;
          string where_from = where_to;
          transition reject;
        }
      };
    """

  #expect(
    #RequireErrorResult(
      Error(
        withMessage:
          "Failed to parse local element: Cannot initialize where_from (with type String) from rvalue with type Boolean"
      ),
      Program.Parse(simple_parser_declaration)))
}
