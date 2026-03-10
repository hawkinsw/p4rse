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
import Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_unsupported_annotations() async throws {
  let simple_annotated_parser_declaration = """
    @testing parser main_parser() {
       state start {
           transition start;
       }
    };
    """
  #expect(
    #RequireErrorResult(
      Error(withMessage: "{0, 8}: Annotations in parser type are not yet handled."),
      Program.Compile(simple_annotated_parser_declaration)))
}

@Test func test_unsupported_annotations_state() async throws {
  let simple_annotated_parser_declaration = """
    parser main_parser() {
       @testing state start {
           transition start;
       }
    };
    """
  #expect(
    #RequireErrorResult(
      Error(withMessage: "{26, 8}: Annotations in parser state are not yet handled."),
      Program.Compile(simple_annotated_parser_declaration)))
}
