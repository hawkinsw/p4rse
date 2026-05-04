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

    var walker = Walker(node: node)
    var current_node: Node? = .none

    #MustOr(
      result: current_node, thing: walker.getNext(),
      or: Result<(EvaluatableStatement, CompilerContext)>.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement")))

    if current_node!.nodeType != "{" {
      return Result.Error(
        ErrorOnNode(node: current_node!, withError: "Missing { on block statement"))
    }

    var statements: [EvaluatableStatement] = Array()
    var parse_err: Error? = .none
    var current_context = context

    walker.next()
    #MustOr(
      result: current_node, thing: walker.getNext(),
      or: Result<(EvaluatableStatement, CompilerContext)>.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement")))

    if current_node!.nodeType == "statements" {
      switch Parser.Statements.Compile(
        node: current_node!, withContext: current_context)
      {
      case .Ok(let (parsed_statements, updated_context)):
        current_context = updated_context
        statements = parsed_statements
      case .Error(let error):
        parse_err = error
      }

      walker.next()
    }

    if let err = parse_err {
      return .Error(err)
    }

    #MustOr(
      result: current_node, thing: walker.getNext(),
      or: Result<(EvaluatableStatement, CompilerContext)>.Error(
        ErrorOnNode(node: node, withError: "Malformed block statement")))

    if current_node!.nodeType != "}" {
      return Result.Error(
        ErrorOnNode(node: current_node!, withError: "Missing } on block statement"))
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

    var initializer: EvaluatableExpression? = .none

    // If there is an initializer, it must be an expression.
    if let initializer_expression = maybe_rvalue {
      guard initializer_expression.nodeType == "expression" else {
        return Result.Error(
          ErrorOnNode(
            node: node,
            withError: "initial value for declaration statement is not an expression"))
      }

      let maybe_parsed_rvalue = Expression.Compile(node: initializer_expression, withContext: context)
      guard
        case .Ok(let parsed_rvalue) = maybe_parsed_rvalue
      else {
        return .Error(maybe_parsed_rvalue.error()!)
      }

      if parsed_rvalue.type().eq(declaration_p4_type) {
        initializer = parsed_rvalue
      } else {
        return Result.Error(
          Error(
            withMessage:
              "Cannot initialize \(parsed_variablename) (with type \(declaration_p4_type)) from expression with type \(parsed_rvalue.type())"
          ))
      }
    }

    // If there is no initializer, then it must be defaultable.

    if initializer == nil {
      initializer = declaration_p4_type.def()
    }

    guard let initializer = initializer else {
        return Result.Error(
          ErrorOnNode(node: node, withError: "No initializer for declaration"))
    }

    return Result.Ok(
      (
        VariableDeclarationStatement(
          identifier: parsed_variablename, withInitializer: initializer),
        // Context with updated names to include the newly declared name.
        context.update(
          newInstances: context.instances.declare(
            identifier: parsed_variablename, withValue: declaration_p4_type))
      )
    )
  }
}

extension ExpressionStatement: CompilableStatement {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(EvaluatableStatement, CompilerContext)> {
    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "expressionStatement", nice_type_name: "expression statement")

    let expression_node = node.child(at: 0)!

    return switch Expression.Compile(node: expression_node, withContext: context) {
    case .Ok(let expression): .Ok((ExpressionStatement(expression), context))
    case .Error(let e): .Error(e)
    }
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

    let check_result = lvalue_identifier.check(to: rvalue, inScopes: context.instances)
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

extension ReturnStatement: CompilableStatement {
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(any Common.EvaluatableStatement, CompilerContext)> {
    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "return_statement", nice_type_name: "return statement")

    let expression_node = node.child(at: 1)!

    return switch Expression.Compile(node: expression_node, withContext: context) {
    case .Ok(let result):
      if result.type().baseType().eq(rhs: context.expected_type!.baseType()) {
        .Ok((ReturnStatement(result), context))
      } else {
        .Error(
          ErrorOnNode(
            node: node,
            withError:
              "Type of expression in return statement (\(result.type())) is not compatible with function return type (\(context.expected_type!))"
          ))
      }
    case .Error(let e): .Error(e)
    }
  }
}

extension ApplyStatement: CompilableStatement {
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(any Common.EvaluatableStatement, CompilerContext)> {
    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "apply_statement", nice_type_name: "apply statement")

    let expression_node = node.child(at: 1)!

    return switch BlockStatement.Compile(node: expression_node, withContext: context) {
    case .Ok((let statement, let updated_context)):
      .Ok((ApplyStatement(statement as! BlockStatement), updated_context))
    case .Error(let e): .Error(e)
    }
  }
}
