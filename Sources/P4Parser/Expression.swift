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
import SwiftTreeSitter
import TreeSitterP4

protocol ParseableEvaluatableExpression {
  static func parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?>
}

extension TypedIdentifier: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree, withScopes scopes: LexicalScopes
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

    let value_capture = result.captures(named: "identifier")
    guard
      case Result.Ok(let type) = scopes.lookup(
        identifier: Identifier(name: value_capture[0].node.text!))
    else {
      return .Error(Error(withMessage: "Cannot find \(result.captures[0].node.text!) in scope"))
    }

    return .Ok(TypedIdentifier(name: result.captures[0].node.text!, withType: type))
  }
}

extension P4BooleanValue: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree, withScopes scopes: LexicalScopes
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

extension P4IntValue: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {

    guard
      let integer_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expression (integer) @value)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
    }

    let integer_qr = integer_query.execute(node: node, in: tree)

    guard let result = integer_qr.next() else {
      return .Ok(.none)
    }

    let value_capture = result.captures(named: "value")
    if let parsed_int = Int(value_capture[0].node.text!) {
      return .Ok(P4IntValue(withValue: parsed_int))
    } else {
      print("HERE!!")
      return .Error(Error(withMessage: "Failed to parse integer: \(result.captures[0].node.text!)"))
    }
  }
}

extension P4StringValue: ParseableEvaluatableExpression {
  static func parse(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {

    guard
      let string_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expression (string_literal) @value)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
    }

    let string_qr = string_query.execute(node: node, in: tree)

    guard let result = string_qr.next() else {
      return .Ok(.none)
    }

    return .Ok(P4StringValue(withValue: result.captures[0].node.text!))
  }
}

struct Expression {
  public static func Parse(
    node: Node, inTree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression> {
    let localElementsParsers: [ParseableEvaluatableExpression.Type] = [
      P4BooleanValue.self, P4StringValue.self, P4IntValue.self, TypedIdentifier.self,
    ]

    for le_parser in localElementsParsers {
      if case Result.Ok(.some(let parsed)) = le_parser.parse(
        node: node, inTree: inTree, withScopes: scopes)
      {
        return .Ok(parsed)
      }
    }

    return Result.Error(Error(withMessage: "Could not parse into expression."))
  }
}

extension ExpressionStatement: ParseableStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)> {
    guard
      let expression_statement_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expressionStatement (expression) @expression)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = expression_statement_query.execute(node: node, in: tree)
    guard let query_result = qr.next() else {
      return Result.Ok((.none, scopes))
    }

    let expression_capture = query_result.captures(named: "expression")
    if !expression_capture.isEmpty {
      // TODO: Actually create an ExpressionStatement
      return Result.Ok((ExpressionStatement(), scopes))
    }
    return Result.Ok((.none, scopes))
  }
}

