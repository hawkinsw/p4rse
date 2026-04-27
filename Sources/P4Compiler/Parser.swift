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
        "return_statement": ReturnStatement.self,
      ]
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
    ) -> Result<(InstantiatedParserState, CompilerContext)> {

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

      var parse_errs: [Error] = Array()
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
          parse_errs.append(e)
        }
      }

      if !parse_errs.isEmpty {
        return Result.Error(
          Error(
            withMessage: parse_errs.map { err in
              return String(err.msg)
            }.joined(separator: ";")))
      }
      return Result.Ok((parsed_s, current_context))
    }
  }

  public struct State {
    static func Compile(
      node: Node, withContext context: CompilerContext
    ) -> Result<(InstantiatedParserState, CompilerContext)> {
      var walker = Walker(node: node)

      var current_node: Node? = .none

      guard let node_type = node.nodeType,
        node_type == "parserState"
      else {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Did not find a parser state declaration"))
      }

      #MustOr(
        result: current_node, thing: walker.getNext(),
        or: Result<(InstantiatedParserState, CompilerContext)>.Error(
          ErrorOnNode(
            node: node, withError: "Missing elements in parser state declaration")))

      if current_node!.nodeType == "annotations" {
        return Result.Error(
          ErrorOnNode(
            node: current_node!, withError: "Annotations in parser state are not yet handled."))

        // Would increment here.
      }

      // Skip the keyword state
      walker.next()
      #MustOr(
        result: current_node, thing: walker.getNext(),
        or: Result<(InstantiatedParserState, CompilerContext)>.Error(
          ErrorOnNode(
            node: node, withError: "Missing elements in parser state declaration")))

      let maybe_state_identifier = Identifier.Compile(
        node: current_node!, withContext: context)
      guard case Result.Ok(let state_identifier) = maybe_state_identifier else {
        return Result.Error(maybe_state_identifier.error()!)
      }

      walker.next()
      // Skip the '{'
      walker.next()
      #MustOr(
        result: current_node, thing: walker.getNext(),
        or: Result<(InstantiatedParserState, CompilerContext)>.Error(
          ErrorOnNode(
            node: node, withError: "Missing body of state declaration")))

      var parse_errs: [Error] = Array()
      var current_context = context
      var parsed_s: [EvaluatableStatement] = Array()

      if current_node!.nodeType == "parserStatements" {
        switch Statements.Compile(
          node: current_node!, withContext: current_context)
        {
        case .Ok(let (state_statements, updated_context)):
          parsed_s = state_statements
          current_context = updated_context
        case .Error(let error):
          parse_errs.append(error)
        }
        walker.next()
      }

      if !parse_errs.isEmpty {
        return Result.Error(
          Error(
            withMessage: parse_errs.map { err in
              return String(err.msg)
            }.joined(separator: ";")))
      }

      #MustOr(
        result: current_node, thing: walker.getNext(),
        or: Result<(InstantiatedParserState, CompilerContext)>.Error(
          ErrorOnNode(
            node: node, withError: "Missing transition statement of state declaration")))

      return TransitionStatement.Compile(
        node: current_node!, forState: state_identifier, withStatements: parsed_s,
        withContext: current_context)
    }
  }

  static func Compile(
    withName name: Common.Identifier, withParameters parameters: ParameterList, node: Node,
    withContext context: CompilerContext
  ) -> Result<(P4Lang.Parser, CompilerContext)> {

    var parser = P4Lang.Parser(withName: name, withParameters: parameters)

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
        node: parser_state,
        withContext: context.update(newInstances: current_context.instances.enter()))
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
