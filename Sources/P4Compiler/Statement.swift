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

extension BlockStatement: CompilableStatement {
  public static func Compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {
    if node.nodeType != "blockStatement" {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find expected block statement"))
    }

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement"))
    }
    currentChild = node.child(at: currentChildIdx)
    if currentChild!.nodeType != "{" {
      return Result.Error(
        ErrorOnNode(node: currentChild!, withError: "Missing { on block statement"))
    }
    currentChildIdx += 1
    currentChildIdxSafe += 1

    var statements: [EvaluatableStatement] = Array()
    var parse_err: Error? = .none
    var new_scopes: LexicalScopes = LexicalScopes()

    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement"))
    }
    currentChild = node.child(at: currentChildIdx)
    if currentChild!.nodeType == "statements" {
      switch Parser.Statements.Compile(
        node: currentChild!, inTree: tree, withLexicalScopes: scopes.enter())
      {
      case .Ok(let (parsed_statements, parsed_scopes)):
        new_scopes = parsed_scopes
        statements = parsed_statements
      case .Error(let error):
        parse_err = error
      }

      currentChildIdx += 1
      currentChildIdxSafe += 1
    }

    if let err = parse_err {
      return .Error(err)
    }

    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement"))
    }
    currentChild = node.child(at: currentChildIdx)
    if currentChild!.nodeType != "}" {
      return Result.Error(
        ErrorOnNode(node: currentChild!, withError: "Missing } on block statement"))
    }

    return .Ok((BlockStatement(statements), new_scopes))
  }
}

extension ConditionalStatement: CompilableStatement {
  public static func Compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {

    guard let node_type = node.nodeType,
      node_type == "conditionalStatement"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find expected conditional statement"))
    }

    let maybe_condition_expression = node.child(at: 2)
    guard let condition_expression = maybe_condition_expression,
      condition_expression.nodeType == "expression"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find condition for conditional statement"))
    }

    let maybe_thens = node.child(at: 4)
    guard let thens = maybe_thens,
      thens.nodeType == "statement"
    else {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Did not find then statement block for conditional statement"))
    }

    guard
      case .Ok(let condition) = Expression.Compile(
        node: condition_expression, inTree: tree, withScopes: scopes)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a conditional expression in a conditional statement"))
    }

    guard
      case .Ok((let thenns, _)) = Parser.Statement.Compile(
        node: thens, inTree: tree, withScope: scopes)
    else {
      return Result.Error(
        Error(
          withMessage:
            "Could not parse the then block in a conditional statement"))
    }

    let optional_elss: Result<(any EvaluatableStatement, LexicalScopes)>? =
      if let elss = node.child(at: 6) {
        .some(
          Parser.Statement.Compile(
            node: elss, inTree: tree, withScope: scopes))
      } else {
        .none
      }

    if let parsed_elss = optional_elss {
      guard
        case .Ok((let elss, _)) = parsed_elss
      else {
        return Result.Error(
          Error(
            withMessage:
              "Could not parse the else block in a conditional statement"))
      }
      return .Ok(
        (ConditionalStatement(condition: condition, withThen: thenns, andElse: elss), scopes))
    }
    return .Ok((ConditionalStatement(condition: condition, withThen: thenns), scopes))
  }
}

extension VariableDeclarationStatement: CompilableStatement {
  public static func Compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {

    guard let node_type = node.nodeType,
      node_type == "variableDeclaration"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find expected variable declaration statement"))
    }

    let maybe_typeref = node.child(at: 0)
    guard let typeref = maybe_typeref,
      typeref.nodeType == "typeRef"
    else {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Did not find type name for variable declaration statement"))
    }

    let maybe_variablename = node.child(at: 1)
    guard let variablename = maybe_variablename,
      variablename.nodeType == "identifier"
    else {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Did not find identifier name for variable declaration statement"))
    }

    let maybe_rvalue = node.childCount > 3 ? node.child(at: 3) : .none
    guard let rvalue = maybe_rvalue,
      rvalue.nodeType == "expression"
    else {
      return Result.Error(
        ErrorOnNode(
          node: node,
          withError: "Did not find initial value expression for variable declaration statement"))
    }

    guard
      case .Ok(let parsed_variablename) = Identifier.Compile(
        node: variablename, inTree: tree, withScopes: scopes.enter())
    else {
      return Result.Error(
        Error(withMessage: "Could not parse variable name"))
    }

    guard
      case .Ok(let parsed_rvalue) = Expression.Compile(
        node: rvalue, inTree: tree, withScopes: scopes.enter())
    else {
      return Result.Error(
        Error(
          withMessage:
            "Could not parse initial value expression in a variable declaration statement"))
    }

    guard case .Ok(let declaration_p4_type) = Types.CompileBasicType(type: typeref.text!) else {
      return Result.Error(
        Error(withMessage: "Could not parse a P4 type from \(typeref.text!)"))
    }

    if parsed_rvalue.type().eq(rhs: declaration_p4_type) {
      return Result.Ok(
        (
          VariableDeclarationStatement(
            identifier: parsed_variablename, withInitializer: parsed_rvalue),
          scopes.declare(
            identifier: parsed_variablename, withValue: declaration_p4_type)
        ))

    } else {
      return Result.Error(
        Error(
          withMessage:
            "Cannot initialize \(parsed_variablename) (with type \(declaration_p4_type)) from rvalue with type \(parsed_rvalue.type())"
        ))

    }
  }
}

extension ExpressionStatement: CompilableStatement {
  public static func Compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {
    if node.nodeType != "expressionStatement" {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find expected expression statement"))
    }

    let _ = node.child(at: 0)

    return Result.Ok((ExpressionStatement(), scopes))
  }
}
