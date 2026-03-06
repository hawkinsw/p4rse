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
import P4Lang
import P4Runtime
import SwiftTreeSitter
import TreeSitterExtensions
import TreeSitterP4

let p4lang = Language(tree_sitter_p4())

public func ConfigureP4Parser() -> Result<SwiftTreeSitter.Parser> {
    let p = SwiftTreeSitter.Parser.init()

    do {
      try p.setLanguage(p4lang)
    } catch {
      return Result.Error(Error(withMessage: "Could not configure the P4 parser"))
    }

  return .Ok(p)
}

public func ErrorOnNode(node: Node, withError error: String) -> Error {
  return Error(withMessage: "\(node.range): \(error)")
}
