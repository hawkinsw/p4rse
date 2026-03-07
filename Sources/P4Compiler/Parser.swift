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
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {

    #RequireNodeType<Node, (EvaluatableStatement, LexicalScopes)>(
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
      node: rvalue_node, inTree: tree, withScopes: scopes)
    guard case Result.Ok(let rvalue) = maybe_parsed_rvalue else {
      return Result.Error(maybe_parsed_rvalue.error()!)
    }

    let maybe_parsed_lvalue = LValue.Compile(node: lvalue_node, inTree: tree, withScopes: scopes)
    guard case .Ok(let lvalue_identifier) = maybe_parsed_lvalue else {
      return Result.Error(maybe_parsed_lvalue.error()!)
    }
    guard case Result.Ok(let lvalue_type) = scopes.lookup(identifier: lvalue_identifier) else {
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
          ), scopes
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
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(EvaluatableStatement, LexicalScopes)> {
      let localElementsParsers: [String: CompilableStatement.Type] = [
        "variableDeclaration": VariableDeclarationStatement.self
      ]

      guard let parser = localElementsParsers[node.nodeType ?? ""] else {
        return Result.Error(
          ErrorOnNode(
            node: node,
            withError: "Unparseable statement type (\(node.nodeType ?? "Unknown Statement Type"))"))
      }

      switch parser.Compile(node: node, inTree: tree, withScopes: scopes) {
      case Result.Ok(let (parsed, parsed_updated_scopes)):
        return Result.Ok((parsed, parsed_updated_scopes))
      case Result.Error(let e):
        return Result.Error(Error(withMessage: "Failed to parse local element: \(e)"))
      }
    }
  }

  public struct Statement {
    static func Compile(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(EvaluatableStatement, LexicalScopes)> {
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
      switch parser.Compile(node: statement, inTree: tree, withScopes: scopes) {
      case Result.Ok(let (parsed, updatedLexicalScopes)):
        return .Ok((parsed, updatedLexicalScopes))
      case Result.Error(let e):
        return .Error(
          ErrorOnNode(node: node, withError: "Failed to parse a statement element: \(e)"))
      }
    }
  }

  public struct TransitionStatement {
    static func Compile(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(ParserTransitionStatement, LexicalScopes)> {

      #RequireNodeType<Node, (EvaluatableStatement, LexicalScopes)>(node: node, type: "parserTransitionStatement", nice_type_name: "parser transition statement")

      guard let tse_node = node.child(at: 1),
      tse_node.nodeType! == "transitionSelectionExpression" else {
        return .Error(ErrorOnNode(node: node, withError: "Could not find transition select expression"))
      }

      guard let next_node = tse_node.child(at: 0) else {
        return .Error(ErrorOnNode(node: node, withError: "Could not find the next token in a transition selection expression"))
      }

      // If the next node is an identifier, we have the simple form ...
      if next_node.nodeType == "identifier" {
        let maybe_parsed_next_state = Identifier.Compile(
          node: next_node, inTree: tree, withScopes: scopes)
        if case .Ok(let next_state) = maybe_parsed_next_state {
          return .Ok(
            (ParserTransitionStatement(withNextState: next_state), scopes))
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
        switch SelectExpression.compile(node: next_node, inTree: tree, withScopes: scopes)
      {
      case .Ok(let tse):
        .Ok((ParserTransitionStatement(withTransitionExpression: tse! as! SelectExpression), scopes))
      case .Error(let e): .Error(e)
      }
    }
  }

  public struct Statements {
    static func Compile(
      node: Node, inTree tree: MutableTree, withLexicalScopes scopes: LexicalScopes
    ) -> Result<([EvaluatableStatement], LexicalScopes)> {
      if node.nodeType != "statements" && node.nodeType != "parserStatements" {
        return Result.Error(ErrorOnNode(node: node, withError: "Did not find expected statements"))
      }

      var parse_err: Error? = .none
      var current_scopes = scopes
      var parsed_s: [EvaluatableStatement] = Array()

      node.enumerateNamedChildren { node in
        switch Statement.Compile(
          node: node, inTree: tree, withScope: current_scopes)
        {
        case .Ok((let parsed_statement, let updated_scopes)):
          current_scopes = updated_scopes
          parsed_s.append(parsed_statement)
        case .Error(let e):
          parse_err = e
        }
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }
      return Result.Ok((parsed_s, current_scopes))
    }
  }

  public struct State {
    static func Compile(
      node: Node, inTree tree: MutableTree, withLexicalScopes scopes: LexicalScopes
    ) -> Result<(ParserState, LexicalScopes)> {

      var currentChildIdx = 1
      var currentChildIdxSafe = 2

      var currentChild: Node? = .none

      guard let node_type = node.nodeType,
        node_type == "parserState"
      else {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Did not find a parser state declaration"))
      }

      if node.childCount < currentChildIdxSafe {
        return Result.Error(
          ErrorOnNode(node: node, withError: "Missing state name in state declaration"))
      }
      currentChild = node.child(at: 1)
      let maybe_state_identifier = Identifier.Compile(
        node: currentChild!, inTree: tree, withScopes: scopes)
      guard case Result.Ok(let state_identifier) = maybe_state_identifier else {
        return Result.Error(maybe_state_identifier.error()!)
      }

      // Skip the '{'
      currentChildIdx += 2
      currentChildIdxSafe += 2

      var parse_err: Error? = .none
      var current_scopes: LexicalScopes = LexicalScopes()
      var parsed_s: [EvaluatableStatement] = Array()

      if node.childCount < currentChildIdxSafe {
        return Result.Error(ErrorOnNode(node: node, withError: "Missing body of state declaration"))
      }
      currentChild = node.child(at: currentChildIdx)
      if currentChild!.nodeType == "parserStatements" {
        switch Statements.Compile(
          node: currentChild!, inTree: tree, withLexicalScopes: scopes.enter())
        {
        case .Ok(let (state_statements, updated_scopes)):
          parsed_s = state_statements
          current_scopes = updated_scopes
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
      switch TransitionStatement.Compile(
        node: currentChild!, inTree: tree, withScope: current_scopes)
      {
      case .Ok(let (transition_statement, new_scopes)):
        return Result.Ok(
          (
            ParserState(
              name: state_identifier, withStatements: parsed_s,
              withTransition: transition_statement), new_scopes
          ))
      case .Error(let e): return .Error(e)
      }
    }
  }

  static func Compile(
    withName name: Common.Identifier, node: Node, inTree tree: MutableTree,
    withLexicalScopes scopes: LexicalScopes
  ) -> Result<(P4Lang.Parser, LexicalScopes)> {
    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(parserStates) @parser-states"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(
        Error(withMessage: "Could not compile the parser state tree sitter query"))
    }

    var parser = P4Lang.Parser(withName: name)

    // Build a state from each one listed.
    let qr = parser_state_query.execute(node: node, in: tree)
    let qr_value = qr.next()!
    let captures = qr_value.captures(named: "parser-states")

    var error: Error? = .none

    var parser_scopes = scopes

    // TODO: Assert that there is only one.
    captures[0].node.enumerateChildren { parser_state in
      switch Parser.State.Compile(node: parser_state, inTree: tree, withLexicalScopes: scopes) {
      case Result.Ok(let (state, new_parser_scopes)):
        parser.states = parser.states.append(state: state)
        parser_scopes = new_parser_scopes
      case Result.Error(let e): error = e
      }
    }

    if let error = error {
      return .Error(error)
    }

    return Result.Ok((parser, parser_scopes))
  }
}
