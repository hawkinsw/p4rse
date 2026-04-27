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

@testable import Macros

func wrapper_test_mustor() -> Int {
    let x: Int? = 2
    var i = 0
    #MustOr(result: i, thing: x, or: 1)
    return i
}

func wrapper_test_mustor_none() -> Int {
    let x: Int? = .none
    var i = 0
    #MustOr(result: i, thing: x, or: 1)
    return i
}


@Test func test_mustor() async throws {
    #expect(wrapper_test_mustor() == 2)
}

@Test func test_mustor_none() async throws {
    #expect(wrapper_test_mustor_none() == 1)
}
