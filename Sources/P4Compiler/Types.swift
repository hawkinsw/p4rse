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

extension P4Boolean: CompilableType {
  public static func CompileType(
    type: SwiftTreeSitter.Node, withContext: CompilerContext
  ) -> Common.Result<(any Common.P4Type)?> {
    return type.text == "bool" ? .Ok(P4Boolean()) : .Ok(.none)
  }
}

extension P4Int: CompilableType {
  public static func CompileType(
    type: SwiftTreeSitter.Node, withContext: CompilerContext
  ) -> Common.Result<(any Common.P4Type)?> {
    return type.text == "int" ? .Ok(P4Int()) : .Ok(.none)
  }
}

extension P4String: CompilableType {
  public static func CompileType(
    type: SwiftTreeSitter.Node, withContext: CompilerContext
  ) -> Common.Result<(any Common.P4Type)?> {
    return type.text == "string" ? .Ok(P4String()) : .Ok(.none)
  }
}

extension P4Struct: CompilableType {
  public static func CompileType(
    type: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(any Common.P4Type)?> {
    let maybe_parsed_type_id = Identifier.Compile(node: type, withContext: context)
    guard case .Ok(let parsed_type_id) = maybe_parsed_type_id else {
      return .Error(maybe_parsed_type_id.error()!)
    }
    if case .Ok(let found_type) = context.types.lookup(identifier: parsed_type_id),
      let found_struct_type = found_type as? P4Struct
    {
      return .Ok(found_struct_type)
    }
    return .Ok(.none)
  }
}

public struct Types {
  static func CompileType(
    type: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Result<P4Type> {
    let type_parsers: [CompilableType.Type] = [
      P4Boolean.self, P4Int.self, P4String.self, P4Struct.self,
    ]
    for type_parser in type_parsers {
      switch type_parser.CompileType(type: type, withContext: context) {
      case .Ok(.some(let type)): return .Ok(type)
      case .Ok(.none): continue
      case .Error(let e): return .Error(e)
      }
    }
    return Result.Error(Error(withMessage: "Type name not recognized"))
  }
}
