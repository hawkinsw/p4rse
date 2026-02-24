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

extension VariableDeclarationStatement: ParseableStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)> {
    guard
      let variable_declaration_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(variableDeclaration (annotations)? (typeRef) @type-name variable_name: (identifier) @identifier ((assignment) (expression) @value)?)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = variable_declaration_query.execute(node: node, in: tree)
    guard let variable_declaration = qr.next() else {
      return .Ok((.none, scopes))
    }

    let type_name_capture = variable_declaration.captures(named: "type-name")
    let variable_name_capture = variable_declaration.captures(named: "identifier")
    let value_capture = variable_declaration.captures(named: "value")

    // There must be a type name and a variable name
    guard !type_name_capture.isEmpty,
      !variable_name_capture.isEmpty,
      !value_capture.isEmpty,
      let variable_name = variable_name_capture[0].node.text,
      let type_name = type_name_capture[0].node.text
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parser variable declaration statement"))
    }

    guard case .Ok(let declaration_p4_type) = Types.ParseBasicType(type: type_name) else {
      return Result.Error(
        Error(withMessage: "Could not parse a P4 type from \(type_name)"))
    }

    let rvalue_raw = value_capture[0].node
    let maybe_parsed_rvalue = Expression.Parse(node: rvalue_raw, inTree: tree, withScopes: scopes)
    guard case Result.Ok(let rvalue) = maybe_parsed_rvalue else {
      return Result.Error(maybe_parsed_rvalue.error()!)
    }

    if rvalue.type().eq(rhs: declaration_p4_type) {
      return Result.Ok(
        (
          VariableDeclarationStatement(identifier: Identifier(name: variable_name), withInitializer: rvalue),
          scopes.declare(identifier: Identifier(name: variable_name), withValue: declaration_p4_type)
        ))

    } else {
      return Result.Error(
        Error(
          withMessage:
            "Cannot initialize \(variable_name) (with type \(declaration_p4_type)) from rvalue with type \(rvalue.type())"
        ))

    }
  }
}
