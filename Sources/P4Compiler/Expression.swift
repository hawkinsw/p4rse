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
import P4Runtime

protocol CompilableExpression {
  static func compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<EvaluatableExpression?>
}

extension TypedIdentifier: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Result<EvaluatableExpression?> {

    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(
      node: node, type: "identifier")

    guard
      case Result.Ok(let type) = context.names.lookup(
        identifier: Common.Identifier(name: node.text!))
    else {
      return .Error(ErrorOnNode(node: node, withError: "Cannot find \(node.text!) in scope"))
    }

    return .Ok(TypedIdentifier(name: node.text!, withType: type))
  }
}

extension P4BooleanValue: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Result<EvaluatableExpression?> {
    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(
      node: node, type: "booleanLiteralExpression")

    if node.text == "false" {
      return .Ok(P4BooleanValue(withValue: false))
    } else if node.text == "true" {
      return .Ok(P4BooleanValue(withValue: true))
    }

    return .Error(
      ErrorOnNode(node: node, withError: "Failed to parse boolean literal: \(node.text!)"))
  }
}

extension P4IntValue: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
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
    node: SwiftTreeSitter.Node, withContext scopes: CompilerContext
  ) -> Result<EvaluatableExpression?> {
    let node = node.child(at: 0)!
    #SkipUnlessNodeType<SwiftTreeSitter.Node, EvaluatableExpression?>(
      node: node, type: "string_literal")
    return .Ok(P4StringValue(withValue: node.text!))
  }
}

struct Expression {
  public static func Compile(
    node: Node, withContext: CompilerContext
  ) -> Result<EvaluatableExpression> {

    #RequireNodesType<Node, EvaluatableExpression>(
      nodes: node, type: ["expression", "keysetExpression"],
      nice_type_names: ["expression", "keyset expression"])

    // If the node is a keyset expression, then dig out the expression:
    let node =
      if node.nodeType == "keysetExpression" {
        node.child(at: 0)!
      } else {
        node
      }

    let localElementsParsers: [CompilableExpression.Type] = [
      P4BooleanValue.self, P4StringValue.self, P4IntValue.self, TypedIdentifier.self, BinaryOperatorExpression.self
    ]

    for le_parser in localElementsParsers {
      switch le_parser.compile(
        node: node, withContext: withContext)
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
    node: Node, withContext: CompilerContext
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
    node: Node, withContext context: CompilerContext
  ) -> Result<Common.Identifier> {
    return if let node_text_value = node.text {
      .Ok(Common.Identifier(name: node_text_value))
    } else {
      .Error(Error(withMessage: "Could not parse an identifier from \(node)"))
    }
  }
}

extension SelectExpression: CompilableExpression {
  static func compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<EvaluatableExpression?> {
    #RequireNodeType<Node, (SelectExpression, CompilerContext)>(
      node: node, type: "selectExpression", nice_type_name: "parser select expression")

    guard let selector_node = node.child(at: 2),
      selector_node.nodeType == "expression"
    else {
      return .Error(ErrorOnNode(node: node, withError: "Could not find selector expression"))
    }

    guard let select_body_node = node.child(at: 5),
      select_body_node.nodeType == "selectBody"
    else {
      return .Error(ErrorOnNode(node: node, withError: "Could not find select expression body"))
    }

    let maybe_selector = Expression.Compile(node: selector_node, withContext: context)
    guard case .Ok(let selector) = maybe_selector else {
      return .Error(
        Error(
          withMessage:
            "Could not parse transition select expression selector expression: \(maybe_selector.error()!)"
        ))
    }

    var kses: [KeysetExpression] = Array()
    var kses_errors: [Error] = Array()

    select_body_node.enumerateNamedChildren { current_node in
      let maybe_parsed_kse = KeysetExpression.compile(
        node: current_node, withContext: context)
      if case .Ok(let parsed_kse) = maybe_parsed_kse {
        kses.append(parsed_kse as! KeysetExpression)
      } else {
        kses_errors.append(Error(withMessage: "\(maybe_parsed_kse.error()!)"))
      }
    }

    if !kses_errors.isEmpty {
      return .Error(
        Error(
          withMessage: "Error(s) parsing select cases: "
            + (kses_errors.map { error in
              return "\(error.msg)"
            }.joined(separator: ";\n"))))
    }
    return .Ok(
      SelectExpression(withSelector: selector, withKeysetExpressions: kses),
    )
  }
}

extension KeysetExpression: CompilableExpression {
  static func compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<EvaluatableExpression?> {
    if node.nodeType != "selectCase" {
      return Result.Error(Error(withMessage: "Expected select case not found"))
    }

    guard let keysetexpression_node = node.child(at: 0),
      keysetexpression_node.nodeType == "keysetExpression"
    else {
      return Result.Error(Error(withMessage: "Missing keyset expression in select case"))
    }

    guard let targetstate_node = node.child(at: 2),
      targetstate_node.nodeType == "identifier"
    else {
      return Result.Error(Error(withMessage: "Missing target state in select case"))
    }

    let maybe_parsed_keysetexpression = Expression.Compile(
      node: keysetexpression_node, withContext: context)
    guard case Result.Ok(let keysetexpression) = maybe_parsed_keysetexpression else {
      return Result.Error(maybe_parsed_keysetexpression.error()!)
    }

    let maybe_parsed_targetstate = Identifier.Compile(
      node: targetstate_node, withContext: context)
    guard case .Ok(let targetstate) = maybe_parsed_targetstate else {
      return Result.Error(maybe_parsed_targetstate.error()!)
    }

    return .Ok(
      KeysetExpression(
        withKey: keysetexpression, withNextState: targetstate)
    )
  }
}

extension BinaryOperatorExpression: CompilableExpression {
  static func compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableExpression)?> {
    let expression = node.child(at: 0)!

    #SkipUnlessNodeType<Node, EvaluatableExpression?>(node: expression, type: "binaryOperatorExpression")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    if expression.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Malformed binary operator expression"))
    }
    currentChild = expression.child(at: currentChildIdx)

    let binary_operator_expression_node = currentChild!
    #RequireNodesType<Node, EvaluatableExpression?>(nodes: binary_operator_expression_node, type: ["binaryEqualOperatorExpression"], nice_type_names: ["binary equal operator"])

    if binary_operator_expression_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing LHS for binary operator expression"))
    }
    currentChild = binary_operator_expression_node.child(at: currentChildIdx)
    let left_hand_side_raw = currentChild!

    currentChildIdx = currentChildIdx + 1 
    currentChildIdxSafe = currentChildIdxSafe + 1 
    if binary_operator_expression_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing binary operator for binary operator expression"))
    }
    currentChild = binary_operator_expression_node.child(at: currentChildIdx)


    currentChildIdx = currentChildIdx + 1 
    currentChildIdxSafe = currentChildIdxSafe + 1 
    if binary_operator_expression_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing binary operator for binary operator expression"))
    }
    currentChild = binary_operator_expression_node.child(at: currentChildIdx)
    let right_hand_side_raw = currentChild!

    let maybe_left_hand_side = Expression.Compile(node: left_hand_side_raw, withContext: context)
    guard case Result.Ok(let left_hand_side) = maybe_left_hand_side else {
      return Result.Error(maybe_left_hand_side.error()!)
    }

    let maybe_right_hand_side = Expression.Compile(node: right_hand_side_raw, withContext: context)
    guard case Result.Ok(let right_hand_side) = maybe_right_hand_side else {
      return Result.Error(maybe_right_hand_side.error()!)
    }

    return .Ok(
      BinaryOperatorExpression(
        withEvaluator: ("Binary Equal", P4Boolean.create(), binary_equal_operator_evaluator),
        withLhs: left_hand_side, withRhs: right_hand_side))
  }
}