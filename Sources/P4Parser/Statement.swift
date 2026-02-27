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

extension BlockStatement: ParseableStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)> {
    // TODO: Make sure that this works.
    // (And apply in other places!)
    guard
      let block_statement_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(statement . (blockStatement . (statements . ((statement) @astatement)*) @statements) @block-statement) @statement"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = block_statement_query.execute(node: node, in: tree)
    guard let variable_declaration = qr.next() else {
      return .Ok((.none, scopes))
    }

    let statement_capture = variable_declaration.captures(named: "statement")
    let blockstatement_capture = variable_declaration.captures(named: "block-statement")
    let astatement_capture = variable_declaration.captures(named: "astatement")
    let statements_capture = variable_declaration.captures(named: "statements")

    if statement_capture.isEmpty || blockstatement_capture.isEmpty {
      return .Error(Error(withMessage: "Could not parse a block statement"))
    }

    let statement_node = statement_capture[0].node
    let blockstatement_capture_node = blockstatement_capture[0].node
    let statements_capture_node = statements_capture[0].node

    /*
        if statement_node.parent != node.parent
        {
          return .Ok((.none, scopes))
        }
    */
    var statements: [EvaluatableStatement] = Array()
    var parse_err: Error? = .none

    for statement in astatement_capture {
      if let statement_node = statement.node.child(
        at: 0) /*
        let statement_node_parent = statement_node.parent,
        statement_node_parent.parent == statements_capture_node
      */
      {
        switch P4Parser.Parser.Statements.Parse(
          node: statement_node, inTree: tree, withScope: scopes.enter())
        {
        case .Ok((let parsed_statement, _)): statements.append(parsed_statement)
        case .Error(let e):
          parse_err = e
          break
        }
      }
    }

    if let err = parse_err {
      return .Error(err)
    }

    return .Ok((BlockStatement(statements), scopes))
  }
}

extension ConditionalStatement: ParseableStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)> {

    guard let node_type = node.nodeType,
      node_type == "conditionalStatement"
    else {
      return Result.Ok((.none, scopes))
    }

    let maybe_condition_expression = node.child(at: 2)
    guard let condition_expression = maybe_condition_expression,
      condition_expression.nodeType == "expression"
    else {
      return Result.Ok((.none, scopes))
    }

    let maybe_thens = node.child(at: 4)
    guard let thens = maybe_thens,
      thens.nodeType == "statement"
    else {
      return Result.Ok((.none, scopes))
    }

    guard
      case .Ok(let condition) = Expression.Parse(
        node: condition_expression, inTree: tree, withScopes: scopes.enter())
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a conditional expression in a conditional statement"))
    }

    guard
      case .Ok((let thenns, _)) = Parser.Statements.Parse(
        node: thens, inTree: tree, withScope: scopes.enter())
    else {
      return Result.Error(
        Error(
          withMessage:
            "Could not parse the then block in a conditional statement"))
    }

    let optional_elss: Result<(any EvaluatableStatement, LexicalScopes)>? =
      if let elss = node.child(at: 6) {
        .some(
          Parser.Statements.Parse(
            node: elss, inTree: tree, withScope: scopes.enter()))
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
          VariableDeclarationStatement(
            identifier: Common.Identifier(name: variable_name), withInitializer: rvalue),
          scopes.declare(
            identifier: Common.Identifier(name: variable_name), withValue: declaration_p4_type)
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
