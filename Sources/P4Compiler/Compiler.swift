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

/// Context for compilation.
public struct CompilerContext {
  let names: LexicalScopes
  let types: LexicalScopes

  public init(withNames _names: LexicalScopes) {
    names = _names
    types = LexicalScopes()
  }

  public init(withNames _names: LexicalScopes, withTypes _types: LexicalScopes) {
    names = _names
    types = _types
  }

  /// Update a compiler context
  ///
  /// Create a new compiler context based on the current with the same types and new names.
  /// 
  /// - Parameter names: a ``LexicalScopes`` with the updated names for the newly created compiler context.
  /// - Returns: A new compiler context based on the current with the same types and new names.
  public func update(newNames names: LexicalScopes) -> CompilerContext {
    return CompilerContext(withNames: names, withTypes: self.types)
  }

  /// Update a compiler context
  ///
  /// Create a new compiler context based on the current with the same names and new types.
  /// 
  /// - Parameter types: a ``LexicalScopes`` with the updated types for the newly created compiler context.
  /// - Returns: A new compiler context based on the current with the same names and new types.
  public func update(newTypes types: LexicalScopes) -> CompilerContext {
    return CompilerContext(withNames: self.names, withTypes: types)
  }


}