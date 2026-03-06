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

protocol CompilableExpression {
  static func compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?>
}

extension TypedIdentifier: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree,
    withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {

    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(node: node, type: "identifier")

    guard
      case Result.Ok(let type) = scopes.lookup(
        identifier: Common.Identifier(name: node.text!))
    else {
      return .Error(ErrorOnNode(node: node, withError: "Cannot find \(node.text!) in scope"))
    }

    return .Ok(TypedIdentifier(name: node.text!, withType: type))
  }
}

extension P4BooleanValue: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree,
    withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {
    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(node: node, type: "booleanLiteralExpression")

    if node.text == "false" {
      return .Ok(P4BooleanValue(withValue: false))
    } else if node.text == "true" {
      return .Ok(P4BooleanValue(withValue: true))
    }

    return .Error(ErrorOnNode(node: node, withError: "Failed to parse boolean literal: \(node.text!)"))
  }
}

extension P4IntValue: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree,
    withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {
    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(node: node, type: "integer")
    if let parsed_int = Int(node.text!) {
      return .Ok(P4IntValue(withValue: parsed_int))
    } else {
      return .Error(ErrorOnNode(node: node, withError: "Failed to parse integer: \(node.text!)"))
    }
  }
}

extension P4StringValue: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, inTree tree: SwiftTreeSitter.MutableTree,
    withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression?> {
    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(node: node, type: "string_literal")
    return .Ok(P4StringValue(withValue: node.text!))
  }
}

struct Expression {
  public static func Compile(
    node: Node, inTree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<EvaluatableExpression> {

    #RequireNodesType<Node, EvaluatableExpression>(nodes: node, type: ["expression", "keysetExpression"], msg: ["expression", "keyset expression"])

    // If the node is a keyset expression, then dig out the expression:
    let node =
      if node.nodeType == "keysetExpression" {
        node.child(at: 0)!
      } else {
        node
      }

    let localElementsParsers: [CompilableExpression.Type] = [
      P4BooleanValue.self, P4StringValue.self, P4IntValue.self, TypedIdentifier.self,
    ]

    for le_parser in localElementsParsers {
      switch le_parser.compile(
        node: node, inTree: inTree, withScopes: scopes)
      {
      case .Ok(.some(let parsed)): return .Ok(parsed)
      case .Error(let e): return .Error(e)
      default: continue
      }
    }

    return Result.Error(Error(withMessage: "\(node.range): Could not parse into expression"))
  }
}

struct LValue {
  public static func Compile(
    node: Node, inTree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<Common.Identifier> {
    return if let node_text_value = node.text {
      .Ok(Common.Identifier(name: node_text_value))
    } else {
      .Error(Error(withMessage: "Could not parse an identifier for an LValue"))
    }
  }
}

struct Identifier {
  public static func Compile(
    node: Node, inTree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<Common.Identifier> {
    return if let node_text_value = node.text {
      .Ok(Common.Identifier(name: node_text_value))
    } else {
      .Error(Error(withMessage: "Could not parse an identifier from \(node)"))
    }
  }
}
