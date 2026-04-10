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

/// Context for compilation
///
/// It contains (at least) three important pieces of information:
/// 1. Instances: A ``VarTypeScopes`` that contains information about instantiated objects
/// (and their types) in scope
/// 1. Types: A ``TypeTypeScopes`` that contains information about declared types in scope.
/// 1. Expected Type: In certain situations, to typecheck an element of a P4 program requires
/// knowledge of an expected type. For instance, when compiling a return statement, the
/// compiler must know the return type of the function to type check.
public struct CompilerContext {
  let instances: VarTypeScopes
  let types: TypeTypeScopes
  let expected_type: P4Type?

  public init(withInstances _instances: VarTypeScopes) {
    instances = _instances
    types = TypeTypeScopes()
    expected_type = .none
  }

  public init(withInstances _instances: VarTypeScopes, withTypes _types: TypeTypeScopes) {
    instances = _instances
    types = _types
    expected_type = .none
  }

  public init(
    withInstances _instances: VarTypeScopes, withTypes _types: TypeTypeScopes,
    withExpectation expectation: P4Type?
  ) {
    instances = _instances
    types = _types
    expected_type = expectation
  }

  /// Update a compiler context
  ///
  /// Create a new compiler context based on the current with the same types and new names.
  ///
  /// - Parameter instances: a ``VarTypeScopes`` with the updated instances for the newly created compiler context.
  /// - Returns: A new compiler context based on the current with the same types and new names.
  public func update(newInstances instances: VarTypeScopes) -> CompilerContext {
    return CompilerContext(
      withInstances: instances, withTypes: self.types, withExpectation: self.expected_type)
  }

  /// Update a compiler context
  ///
  /// Create a new compiler context based on the current with the same names and new types.
  ///
  /// - Parameter types: a ``TypeTypeScopes`` with the updated types for the newly created compiler context.
  /// - Returns: A new compiler context based on the current with the same names and new types.
  public func update(newTypes types: TypeTypeScopes) -> CompilerContext {
    return CompilerContext(
      withInstances: self.instances, withTypes: types, withExpectation: self.expected_type)
  }

  /// Update a compiler context
  ///
  /// Create a new compiler context based on the current with the same names and types but new expected type.
  ///
  /// - Parameter expectation: a ``P4Type?`` to (re)set the type the compiler is expecting.
  /// - Returns: A new compiler context based on the current with the same names and types but new expected type.
  public func update(newExpectation expectation: P4Type?) -> CompilerContext {
    return CompilerContext(
      withInstances: self.instances, withTypes: self.types, withExpectation: expectation)
  }

}
