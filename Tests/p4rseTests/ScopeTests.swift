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

@Test func test_scope() async throws {
  let s = LexicalScope()
  let s2 = s.declare(identifier: Identifier(name: "first"), withValue: P4Int.create())
  let found_first = try! #require(s2.lookup(identifier: Identifier(name: "first")))

  #expect(found_first.eq(rhs: P4Int.create()))
  #expect(s2.count == 1)
}

@Test func test_scope_no_set() async throws {
  var ss = LexicalScopes().enter()
  ss = ss.declare(identifier: Identifier(name: "first"), withValue: P4Int.create())
  ss = ss.enter()
  ss = ss.declare(identifier: Identifier(name: "second"), withValue: P4Boolean.create())

  let found_first = try! #UseOkResult(ss.lookup(identifier: Identifier(name: "first")))
  let found_second = try! #UseOkResult(ss.lookup(identifier: Identifier(name: "second")))

  #expect(found_first.eq(rhs: P4Int.create()))
  #expect(found_second.eq(rhs: P4Boolean.create()))
}

@Test func test_scope_set() async throws {
  var ss = LexicalScopes().enter()
  let id = Identifier(name: "first")
  let id_type = P4Int.create()

  ss = ss.declare(identifier: id, withValue: id_type)
  ss = ss.enter()
  ss = ss.declare(identifier: Identifier(name: "second"), withValue: P4Boolean.create())
  // Change the value of `first`.
  ss = ss.set(identifier: id, withValue: P4String.create())

  // Verify the change!
  let found = try! #UseOkResult(ss.lookup(identifier: id))

  #expect(found.eq(rhs: P4String.create()))
}
