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
    guard case Result.Ok(let lvalue_type) = context.names.lookup(identifier: lvalue_identifier) else {
      return Result.Error(
        ErrorOnNode(
          node: lvalue_node,
          withError: "Cannot assign to variable \(lvalue_identifier) not in scope"))
    }

    if rvalue.type().eq(rhs: lvalue_type) {
      return Result.Ok(
        (
          ParserAssignmentStatement(
            withLValue: TypedIdentifier(name: lvalue_node.text!, withType: lvalue_type),
            withValue: rvalue
          ), context
        ))

    } else {
      return Result.Error(
        ErrorOnNode(
          node: node,
          withError:
            "Cannot assign value of type \(rvalue.type()) to \(lvalue_identifier) (with type \(lvalue_type))"
        ))
    }
  }
}

public struct Parser {
  public struct LocalElements {
    static func Compile(
      node: Node, withContext context: CompilerContext
    ) -> Result<(EvaluatableStatement, CompilerContext)> {
      let localElementsParsers: [String: CompilableStatement.Type] = [
        "variableDeclaration": VariableDeclarationStatement.self
      ]

      guard let parser = localElementsParsers[node.nodeType ?? ""] else {
        return Result.Error(
          ErrorOnNode(
            node: node,
            withError: "Unparseable statement type (\(node.nodeType ?? "Unknown Statement Type"))"))
      }

      switch parser.Compile(node: node, withContext: context) {
      case Result.Ok(let (parsed, parsed_updated_scopes)):
        return Result.Ok((parsed, parsed_updated_scopes))
      case Result.Error(let e):
        return Result.Error(Error(withMessage: "Failed to parse local element: \(e)"))
      }
    }
  }

  public struct Statement {
    static func Compile(
      node: Node, withContext context: CompilerContext
    ) -> Result<(EvaluatableStatement, CompilerContext)> {
      if node.nodeType != "parserStatement" && node.nodeType != "statement" {
        return Result.Error(ErrorOnNode(node: node, withError: "Missing expected parser statement"))
      }

      let statement = node.child(at: 0)!

      let statementParsers: [String: CompilableStatement.Type] = [
        "assignmentStatement": ParserAssignmentStatement.self,
        "expressionStatement": ExpressionStatement.self,
        "variableDeclaration": VariableDeclarationStatement.self,
        "conditionalStatement": ConditionalStatement.self, "blockStatement": BlockStatement.self,
      ]

      // Iterate through statement parsers and give each one a chance.

      guard let parser = statementParsers[statement.nodeType ?? ""] else {
        return Result.Error(
          ErrorOnNode(
            node: statement,
            withError:
              "Unparseable statement type (\(statement.nodeType ?? "Unknown Statement Type"))"))
      }
      switch parser.Compile(node: statement, withContext: context) {
      case Result.Ok(let (parsed, updated_context)):
        return .Ok((parsed, updated_context))
      case Result.Error(let e):
        return .Error(
          ErrorOnNode(node: node, withError: "Failed to parse a statement element: \(e)"))
      }
    }
  }

  public struct TransitionStatement {
    static func Compile(
      node: Node, forState state_identifier: Common.Identifier,
      withStatements stmts: [EvaluatableStatement], withContext context: CompilerContext
    ) -> Result<(ParserState, CompilerContext)> {

      #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
        node: node, type: "parserTransitionStatement", nice_type_name: "parser transition statement"
      )

      guard let tse_node = node.child(at: 1),
        tse_node.nodeType! == "transitionSelectionExpression"
      else {
        return .Error(
          ErrorOnNode(node: node, withError: "Could not find transition select expression"))
      }

      guard let next_node = tse_node.child(at: 0) else {
        return .Error(
          ErrorOnNode(
            node: node,
            withError: "Could not find the next token in a transition selection expression"))
      }

      // If the next node is an identifier, we have the simple form ...
      if next_node.nodeType == "identifier" {
        let maybe_parsed_next_state = Identifier.Compile(
          node: next_node, withContext: context)
        if case .Ok(let next_state) = maybe_parsed_next_state {
          return .Ok(
            (
              ParserStateDirectTransition(
                name: state_identifier, withStatements: stmts, withNextState: next_state), context
            ))
        } else {
          return .Error(
            Error(
              withMessage:
                "Could not parse the next state in a transition statement: \(maybe_parsed_next_state.error()!)"
            ))
        }
      }

      // We know that the next node is a select expression.
      return
        switch SelectExpression.compile(node: next_node, withContext: context)
      {
      case .Ok(let tse):
        .Ok(
          (
            ParserStateSelectTransition(
              name: state_identifier, withStatements: stmts,
              withTransitioniExpression: tse as! SelectExpression), context
          ))
      case .Error(let e): .Error(e)
      }
    }
  }

  public struct Statements {
    static func Compile(
      node: Node, withContext context: CompilerContext
    ) -> Result<([EvaluatableStatement], CompilerContext)> {
      if node.nodeType != "statements" && node.nodeType != "parserStatements" {
        return Result.Error(ErrorOnNode(node: node, withError: "Did not find expected statements"))
      }

      var parse_err: Error? = .none
      var current_context = context
      var parsed_s: [EvaluatableStatement] = Array()

      node.enumerateNamedChildren { node in
        switch Statement.Compile(
          node: node, withContext: current_context)
        {
        case .Ok((let parsed_statement, let updated_context)):
          current_context = updated_context
          parsed_s.append(parsed_statement)
        case .Error(let e):
          parse_err = e
        }
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }
      return Result.Ok((parsed_s, current_context))
    }
  }

  public struct State {
    static func Compile(
      node: Node, withContext context: CompilerContext
    ) -> Result<(ParserState, CompilerContext)> {

      var currentChildIdx = 0
      var currentChildIdxSafe = 1

      var currentChild: Node? = .none

      guard let node_type = node.nodeType,
        node_type == "parserState"
      else {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Did not find a parser state declaration"))
      }

      if node.childCount < currentChildIdxSafe {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Missing elements in parser state declaration"))
      }

      currentChild = node.child(at: currentChildIdx)
      if currentChild!.nodeType == "annotations" {
        return Result.Error(
          ErrorOnNode(
            node: currentChild!, withError: "Annotations in parser state are not yet handled."))

        // Would increment here.
      }

      // Skip the keyword state
      currentChildIdx += 1
      currentChildIdxSafe += 1
      if node.childCount < currentChildIdxSafe {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Missing elements in parser state declaration"))
      }

      currentChild = node.child(at: currentChildIdx)
      let maybe_state_identifier = Identifier.Compile(
        node: currentChild!, withContext: context)
      guard case Result.Ok(let state_identifier) = maybe_state_identifier else {
        return Result.Error(maybe_state_identifier.error()!)
      }

      // Skip the '{'
      currentChildIdx += 2
      currentChildIdxSafe += 2

      var parse_err: Error? = .none
      var current_context = context
      var parsed_s: [EvaluatableStatement] = Array()

      if node.childCount < currentChildIdxSafe {
        return Result.Error(ErrorOnNode(node: node, withError: "Missing body of state declaration"))
      }
      currentChild = node.child(at: currentChildIdx)
      if currentChild!.nodeType == "parserStatements" {
        switch Statements.Compile(
          node: currentChild!, withContext: current_context)
        {
        case .Ok(let (state_statements, updated_context)):
          parsed_s = state_statements
          current_context = updated_context
        case .Error(let error):
          parse_err = error
        }
        currentChildIdx += 1
        currentChildIdxSafe += 1
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }

      if node.childCount < currentChildIdxSafe {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Missing transition statement of state declaration"))
      }
      currentChild = node.child(at: currentChildIdx)
      return TransitionStatement.Compile(
        node: currentChild!, forState: state_identifier, withStatements: parsed_s,
        withContext: current_context)
    }
  }

  static func Compile(
    withName name: Common.Identifier, node: Node,
    withContext context: CompilerContext
  ) -> Result<(P4Lang.Parser, CompilerContext)> {

    var parser = P4Lang.Parser(withName: name)

    // Build a state from each one listed.
    var error: Error? = .none

    var current_context = context
    // TODO: Assert that there is only one.
    node.enumerateNamedChildren { parser_state in
      if parser_state.nodeType != "parserState" {
        return
      }

      // Parse a state in a nested scope.
      switch Parser.State.Compile(
        node: parser_state, withContext: CompilerContext(withNames: current_context.names.enter()))
      {
      case Result.Ok(let (state, updated_context)):
        parser.states = parser.states.append(state: state)
        current_context = updated_context
      case Result.Error(let e): error = e
      }
    }

    if let error = error {
      return .Error(error)
    }

    return Result.Ok((parser, current_context))
  }
}
