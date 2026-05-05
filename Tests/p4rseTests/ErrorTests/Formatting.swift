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

@Test func test_error_with_location_formatting() async throws {
  let formatter = FormatterAnsi()
  let e = ErrorWithLocation(sourceLocation: SourceLocation(1, 5), withError: "There was an error")
  let formatted = e.format(formatter)
  #expect(formatted == "\u{1B}[31;1m{1, 5}\u{1B}[0m: There was an error")
}

@Test func test_errors_with_location_no_formatting() async throws {
  let e = ErrorWithLocation(sourceLocation: SourceLocation(1, 5), withError: "There was an error")
  let e1 = ErrorWithLocation(
    sourceLocation: SourceLocation(10, 5), withError: "There was another error")

  let formatted = e.append(error: e1).format(FormatterPlain())

  #expect(formatted == "{1, 5}: There was an error\n{10, 5}: There was another error")
}

@Test func test_errors_with_location_ansi_formatting() async throws {
  let e = ErrorWithLocation(sourceLocation: SourceLocation(1, 5), withError: "There was an error")
  let e1 = ErrorWithLocation(
    sourceLocation: SourceLocation(10, 5), withError: "There was another error")

  let formatted = e.append(error: e1).format(FormatterAnsi())

  #expect(
    formatted
      == "\u{1B}[31;1m{1, 5}\u{1B}[0m: There was an error\n\u{1B}[31;1m{10, 5}\u{1B}[0m: There was another error"
  )
}
