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
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {
    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "blockStatement", nice_type_name: "block statement")

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
    var current_context = context

    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement"))
    }
    currentChild = node.child(at: currentChildIdx)
    if currentChild!.nodeType == "statements" {
      switch Parser.Statements.Compile(
        node: currentChild!, withContext: current_context)
      {
      case .Ok(let (parsed_statements, updated_context)):
        current_context = updated_context
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

    return .Ok((BlockStatement(statements), current_context))
  }
}

extension ConditionalStatement: CompilableStatement {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {

    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "conditionalStatement", nice_type_name: "conditional statement")

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
        node: condition_expression, withContext: context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a conditional expression in a conditional statement"))
    }

    guard
      case .Ok((let thenns, _)) = Parser.Statement.Compile(
        node: thens, withContext: context)
    else {
      return Result.Error(
        Error(
          withMessage:
            "Could not parse the then block in a conditional statement"))
    }

    let optional_elss: Result<(any EvaluatableStatement, CompilerContext)>? =
      if let elss = node.child(at: 6) {
        .some(
          Parser.Statement.Compile(
            node: elss, withContext: context))
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
        (ConditionalStatement(condition: condition, withThen: thenns, andElse: elss), context))
    }
    return .Ok((ConditionalStatement(condition: condition, withThen: thenns), context))
  }
}

extension VariableDeclarationStatement: CompilableStatement {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {

    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "variableDeclaration", nice_type_name: "variable declaration statement")

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

    guard
      case .Ok(let parsed_variablename) = Identifier.Compile(
        node: variablename, withContext: context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse variable name"))
    }

    guard case .Ok(let declaration_p4_type) = Types.CompileType(type: typeref, withContext: context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a P4 type from \(typeref.text!)"))
    }

    var initializer: EvaluatableExpression = declaration_p4_type.def()
    // If there is an initializer, it must be an expression.
    if let rvalue = maybe_rvalue {
      guard rvalue.nodeType == "expression" else {
        return Result.Error(
          ErrorOnNode(
            node: node,
            withError: "initial value for declaration statement is not an expression"))
      }

      let maybe_parsed_rvalue = Expression.Compile(node: rvalue, withContext: context)
      guard
        case .Ok(let parsed_rvalue) = maybe_parsed_rvalue
      else {
        return .Error(maybe_parsed_rvalue.error()!)
      }

      if parsed_rvalue.type().eq(rhs: declaration_p4_type) {
        initializer = parsed_rvalue
      } else {
        return Result.Error(
          Error(
            withMessage:
              "Cannot initialize \(parsed_variablename) (with type \(declaration_p4_type)) from rvalue with type \(parsed_rvalue.type())"
          ))
      }
    }
    return Result.Ok(
      (
        VariableDeclarationStatement(
          identifier: parsed_variablename, withInitializer: initializer),
        // Context with updated names to include the newly declared name.
        context.update(
          newNames: context.names.declare(
            identifier: parsed_variablename, withValue: declaration_p4_type))
      ))
  }
}

extension ExpressionStatement: CompilableStatement {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {
    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "expressionStatement", nice_type_name: "expression statement")

    let _ = node.child(at: 0)

    return Result.Ok((ExpressionStatement(), context))
  }
}

extension ParserAssignmentStatement: CompilableStatement {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {

    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "assignmentStatement", nice_type_name: "assignment statement")

    guard let lvalue_node = node.child(at: 0),
      lvalue_node.nodeType == "expression"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing lvalue in assignment statement"))
    }

    guard let rvalue_node = node.child(at: 2),
      rvalue_node.nodeType == "expression"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing rvalue in assignment statement"))
    }

    let maybe_parsed_rvalue = Expression.Compile(
      node: rvalue_node, withContext: context)
    guard case Result.Ok(let rvalue) = maybe_parsed_rvalue else {
      return Result.Error(maybe_parsed_rvalue.error()!)
    }

    let maybe_parsed_lvalue = LValue.Compile(node: lvalue_node, withContext: context)
    guard case .Ok(let lvalue_identifier) = maybe_parsed_lvalue else {
      return Result.Error(maybe_parsed_lvalue.error()!)
    }

    let check_result = lvalue_identifier.check(to: rvalue, inScopes: context.names)
    guard case .Ok(_) = check_result else {
      return Result.Error(
        ErrorOnNode(
          node: lvalue_node,
          withError: "\(check_result.error()!)"))
    }

    return Result.Ok(
      (
        ParserAssignmentStatement(
          withLValue: lvalue_identifier,
          withValue: rvalue
        ), context
      ))
  }
}
