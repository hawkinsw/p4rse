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

let p4lang = Language(tree_sitter_p4())

public func ErrorOnNode(node: Node, withError error: String) -> Error {
  return Error(withMessage: "\(node.range): \(error)")
}

extension ParserAssignmentStatement: CompilableStatement {
  public static func Compile(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement, LexicalScopes)> {

    if node.nodeType != "assignmentStatement" {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find expected assignment statement"))
    }

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
            node: node, withError: "Unparseable statement type (\(node.nodeType))"))
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
            node: statement, withError: "Unparseable statement type (\(statement.nodeType))"))
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

  public struct TransitionSelectExpressionCaseStatement {
    static func Compile(
      node: Node, inTree tree: MutableTree, withLexicalScopes scopes: LexicalScopes
    ) -> Result<(KeysetExpression, LexicalScopes)> {
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
        node: keysetexpression_node, inTree: tree, withScopes: scopes)
      guard case Result.Ok(let keysetexpression) = maybe_parsed_keysetexpression else {
        return Result.Error(maybe_parsed_keysetexpression.error()!)
      }

      let maybe_parsed_targetstate = Identifier.Compile(
        node: targetstate_node, inTree: tree, withScopes: scopes)
      guard case .Ok(let targetstate) = maybe_parsed_targetstate else {
        return Result.Error(maybe_parsed_targetstate.error()!)
      }

      return .Ok(
        (
          KeysetExpression(
            withKey: keysetexpression, withNextState: targetstate), scopes
        ))
    }
  }

  public struct TransitionSelectExpression {
    static func Compile(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(ParserTransitionSelectExpression, LexicalScopes)> {
      guard
        let transition_selection_expression_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserTransitionStatement (transition) (transitionSelectionExpression (selectExpression (select) (expression) @selector (selectBody) @body)))"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let qr = transition_selection_expression_query.execute(node: node, in: tree)

      guard let query_result = qr.next() else {
        return .Error(Error(withMessage: "Could not find transition select expression"))
      }

      let selector = query_result.captures(named: "selector")
      let body = query_result.captures(named: "body")

      if selector.isEmpty {
        return .Error(
          Error(withMessage: "Could not find transition select expression selector expression"))
      }
      let selector_node = selector[0].node
      let maybe_selector = Expression.Compile(node: selector_node, inTree: tree, withScopes: scopes)
      guard case .Ok(let selector) = maybe_selector else {
        return .Error(
          Error(
            withMessage:
              "Could not parse transition select expression selector expression: \(maybe_selector.error()!)"
          ))
      }

      if body.isEmpty {
        return .Error(Error(withMessage: "Could not find transition select expression body"))
      }
      let body_node = body[0].node
      var kses: [KeysetExpression] = Array()
      var kses_errors: [Error] = Array()

      body_node.enumerateNamedChildren { current_node in
        let maybe_parsed_kse = TransitionSelectExpressionCaseStatement.Compile(
          node: current_node, inTree: tree, withLexicalScopes: scopes)
        if case .Ok((let parsed_kse, _)) = maybe_parsed_kse {
          kses.append(parsed_kse)
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
        (
          ParserTransitionSelectExpression(withSelector: selector, withKeysetExpressions: kses),
          scopes
        ))
    }
  }

  public struct TransitionStatement {
    static func Compile(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(ParserTransitionStatement, LexicalScopes)> {
      guard
        let next_state_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserTransitionStatement (transition) (transitionSelectionExpression (identifier) @next-state))"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let qr = next_state_query.execute(node: node, in: tree)

      if let next_state_result = qr.next() {
        let transition_capture = next_state_result.captures(named: "next-state")
        let maybe_parsed_next_state = Identifier.Compile(
          node: transition_capture[0].node, inTree: tree, withScopes: scopes)
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

      return
        switch TransitionSelectExpression.Compile(node: node, inTree: tree, withScope: scopes)
      {
      case .Ok((let tse, _)):
        .Ok((ParserTransitionStatement(withTransitionExpression: tse), scopes))
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
