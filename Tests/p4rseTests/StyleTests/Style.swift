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

@Test func test_style_add_format() async throws {
    let red = Style(StyleColor.Red)
    let bold_red = red.update(addFormat: StyleFormat.Bold)

    #expect(bold_red == Style(StyleColor.Red, [StyleFormat.Bold]))
}

@Test func test_style_add_format2() async throws {
    let bold_red = Style(StyleColor.Red, [StyleFormat.Bold])
    let bold_underline_red = bold_red.update(addFormat: StyleFormat.Underline)

    #expect(bold_underline_red == Style(StyleColor.Red, [StyleFormat.Bold, StyleFormat.Underline]))
}


@Test func test_style_remove_format() async throws {
    let bold_red = Style(StyleColor.Red, [StyleFormat.Bold])
    let red = bold_red.update(removeFormat: StyleFormat.Bold)

    #expect(red == Style(StyleColor.Red))
}

@Test func test_style_remove_format2() async throws {
    let bold_underline_red = Style(StyleColor.Red, [StyleFormat.Bold, StyleFormat.Underline])
    let underline_red = bold_underline_red.update(removeFormat: StyleFormat.Bold)

    #expect(underline_red == Style(StyleColor.Red, [StyleFormat.Underline]))
}
