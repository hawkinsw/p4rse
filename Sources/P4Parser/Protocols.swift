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

public protocol ParseableStatement {
  static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)>
}

public protocol ParseableValue {
  static func ParseValue(withValue value: String) -> Result<P4Value>
}

public protocol ParseableType {
  static func ParseType(type: String) -> Result<P4Type?>
}
