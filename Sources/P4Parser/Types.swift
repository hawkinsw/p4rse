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

extension P4Boolean: ParseableType {
  public static func ParseType(type: String) -> Common.Result<(any Common.P4Type)?> {
    return type == "bool" ? .Ok(P4Boolean.create()) : .Ok(.none)
  }
}

extension P4Int: ParseableType {
  public static func ParseType(type: String) -> Common.Result<(any Common.P4Type)?> {
    return type == "int" ? .Ok(P4Int.create()) : .Ok(.none)
  }
}

extension P4String: ParseableType {
  public static func ParseType(type: String) -> Common.Result<(any Common.P4Type)?> {
    return type == "string" ? .Ok(P4String.create()) : .Ok(.none)
  }
}
public struct Types {
  static func ParseBasicType(type: String) -> Result<P4Type> {
    let type_parsers: [ParseableType.Type] = [P4Boolean.self, P4Int.self, P4String.self]
    for type_parser in type_parsers {
      switch type_parser.ParseType(type: type) {
      case .Ok(.some(let type)): return .Ok(type)
      case .Ok(.none): continue
      case .Error(let e): return .Error(e)
      }
    }
    return Result.Error(Error(withMessage: "Type name not recognized"))
  }
}
