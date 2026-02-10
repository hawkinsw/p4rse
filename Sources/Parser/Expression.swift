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

// expression: $ => choice($.identifier, $.integer, $.true, $.false, $.string_literal), // Very limited.

import Common
import SwiftTreeSitter
import TreeSitterP4

protocol ParseableEvaluatableExpression {
  static func parse(node: Node, inTree tree: MutableTree) -> Result<EvaluatableExpression?>
}

extension Identifier: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree
  ) -> Result<EvaluatableExpression?> {

    guard
      let parser_statement_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expression (identifier) @identifier)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
    }

    let qr = parser_statement_query.execute(node: node, in: tree)

    guard let result = qr.next() else {
      return .Ok(.none)
    }

    return .Ok(Identifier(name: result.captures[0].node.text!))
  }
}

extension P4BooleanValue: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree
  ) -> Result<EvaluatableExpression?> {

    guard
      let true_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expression (true))"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
    }

    let true_qr = true_query.execute(node: node, in: tree)

    if true_qr.next() != nil {
      return .Ok(P4BooleanValue(withValue: true))
    }

    guard
      let false_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expression (false))"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
    }

    let false_qr = false_query.execute(node: node, in: tree)

    if false_qr.next() != nil {
      return .Ok(P4BooleanValue(withValue: false))
    }
    return .Ok(.none)
  }
}

struct Expression {
  public static func Parse(node: Node, inTree: MutableTree) -> Result<EvaluatableExpression> {
    let localElementsParsers: [ParseableEvaluatableExpression.Type] = [
      P4BooleanValue.self, Identifier.self,
    ]

    for le_parser in localElementsParsers {
      if case Result.Ok(.some(let parsed)) = le_parser.parse(
        node: node, inTree: inTree)
      {
        return .Ok(parsed)
      }
    }

    return Result.Error(Error(withMessage: "Could not parse into expression."))
  }
}
