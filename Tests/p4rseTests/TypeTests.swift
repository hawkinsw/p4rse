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

import Foundation
import Common
import Macros
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_simple_struct() async throws {
  let fields = P4StructFields([
    P4StructFieldIdentifier(name: "yesno", withType: P4Boolean()),
    P4StructFieldIdentifier(name: "count", withType: P4Int()),
  ])

  let struct_type = P4Struct(withName: Identifier(name: "Testing"), andFields: fields)

  #expect(struct_type.fields.count() == 2)
  #expect(struct_type.fields == fields)
}