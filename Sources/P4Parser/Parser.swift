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

extension ParserAssignmentStatement: ParseableStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScopes scopes: LexicalScopes
  ) -> Result<(EvaluatableStatement?, LexicalScopes)> {

    if node.nodeType != "assignmentStatement" {
      return Result.Ok((.none, scopes))
    }

    guard let lvalue_node = node.child(at: 0),
      lvalue_node.nodeType == "expression"
    else {
      return Result.Error(Error(withMessage: "Missing lvalue in assignment statement"))
    }

    guard let rvalue_node = node.child(at: 2),
      rvalue_node.nodeType == "expression"
    else {
      return Result.Error(Error(withMessage: "Missing lvalue in assignment statement"))
    }

    let maybe_parsed_rvalue = Expression.Parse(node: rvalue_node, inTree: tree, withScopes: scopes)
    guard case Result.Ok(let rvalue) = maybe_parsed_rvalue else {
      return Result.Error(maybe_parsed_rvalue.error()!)
    }

    let maybe_parsed_lvalue = LValue.Parse(node: lvalue_node, inTree: tree, withScopes: scopes)
    guard case .Ok(let lvalue_identifier) = maybe_parsed_lvalue else {
      return Result.Error(maybe_parsed_lvalue.error()!)
    }
    guard case Result.Ok(let lvalue_type) = scopes.lookup(identifier: lvalue_identifier) else {
      return Result.Error(
        Error(withMessage: "Cannot assign to variable \(lvalue_identifier) not in scope"))
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
        Error(
          withMessage:
            "Cannot assign value of type \(rvalue.type()) to \(lvalue_identifier) (with type \(lvalue_type))"
        ))

    }
  }
}

public struct Parser {
  public struct LocalElements {
    static func Parse(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(EvaluatableStatement, LexicalScopes)> {
      let localElementsParsers: [ParseableStatement.Type] = [
        VariableDeclarationStatement.self
      ]

      for local_element_parser in localElementsParsers {
        switch local_element_parser.Parse(node: node, inTree: tree, withScopes: scopes) {
        case Result.Ok((.some(let parsed), let parsed_updated_scopes)):
          return Result.Ok((parsed, parsed_updated_scopes))
        case Result.Error(let e):
          return Result.Error(Error(withMessage: "Failed to parse local element: \(e)"))
        default: continue
        }
      }

      return Result.Error(
        Error(
          withMessage:
            "Failed to parse any local elements from specified local elements: \(node.text!)")
      )
    }
  }

  public struct Statements {
    static func Parse(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(EvaluatableStatement, LexicalScopes)> {
      let statementParsers: [ParseableStatement.Type] = [
        ParserAssignmentStatement.self, ExpressionStatement.self,
        VariableDeclarationStatement.self, ConditionalStatement.self, BlockStatement.self,
      ]

      // Iterate through statement parsers and give each one a chance.
      for parser in statementParsers {
        switch parser.Parse(node: node, inTree: tree, withScopes: scopes) {
        case Result.Ok((.some(let parsed), let updatedLexicalScopes)):
          return .Ok((parsed, updatedLexicalScopes))
        case Result.Error(let e):
          return .Error(Error(withMessage: "Failed to parse a statement element: \(e)"))
        default: continue
        }
      }
      return Result.Error(
        Error(withMessage: "Failed to parse a statement element: \(node.text!)"))
    }
  }

  public struct TransitionSelectExpressionCaseStatement {
    static func Parse(
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

      let maybe_parsed_keysetexpression = Expression.Parse(
        node: keysetexpression_node, inTree: tree, withScopes: scopes)
      guard case Result.Ok(let keysetexpression) = maybe_parsed_keysetexpression else {
        return Result.Error(maybe_parsed_keysetexpression.error()!)
      }

      let maybe_parsed_targetstate = Identifier.Parse(
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
    static func Parse(
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
      let maybe_selector = Expression.Parse(node: selector_node, inTree: tree, withScopes: scopes)
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
      for childidx in 0..<body_node.childCount {

        if !childidx.isMultiple(of: 2) {
          let maybe_semicolon = body_node.child(at: childidx)!
          if maybe_semicolon.nodeType != "semicolon" {
            return .Error(Error(withMessage: "Expected a semicolon but saw \(maybe_semicolon)"))
          }
          continue
        }

        let maybe_parsed_kse = TransitionSelectExpressionCaseStatement.Parse(
          node: body_node.child(at: childidx)!, inTree: tree, withLexicalScopes: scopes)
        if case .Ok((let parsed_kse, _)) = maybe_parsed_kse {
          kses.append(parsed_kse)
        } else {
          return .Error(
            Error(withMessage: "Error when parsing select case: \(maybe_parsed_kse.error()!)"))
        }
      }

      return .Ok(
        (
          ParserTransitionSelectExpression(withSelector: selector, withKeysetExpressions: kses),
          scopes
        ))
    }
  }

  public struct TransitionStatement {
    static func Parse(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(ParserTransitionStatement?, LexicalScopes)> {
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
        let maybe_parsed_next_state = Identifier.Parse(
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

      return switch TransitionSelectExpression.Parse(node: node, inTree: tree, withScope: scopes) {
      case .Ok((let tse, _)):
        .Ok((ParserTransitionStatement(withTransitionExpression: tse), scopes))
      case .Error(let e): .Error(e)
      }
    }
  }

  public struct State {
    static func Parse(
      node: Node, inTree tree: MutableTree, withLexicalScopes scopes: LexicalScopes
    ) -> Result<(ParserState, LexicalScopes)> {
      guard
        let parser_state_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserState (state) (identifier) @state-name (parserLocalElements ((parserLocalElement) @state-local-element (semicolon))*)* (parserStatements ((parserStatement) @state-statement (semicolon))*)* (parserTransitionStatement) @transition)"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let qr = parser_state_query.execute(node: node, in: tree)

      let parser_declaration = qr.next()!

      let transition_capture = parser_declaration.captures(named: "transition")
      let state_name_capture = parser_declaration.captures(named: "state-name")
      let state_le_capture = parser_declaration.captures(named: "state-local-element")
      let statements_capture = parser_declaration.captures(named: "state-statement")

      var parsed_les: [EvaluatableStatement] = Array()
      var parse_err: Error? = .none
      var current_scopes = scopes.enter()

      defer {
        current_scopes = current_scopes.exit()
      }

      for state_le in state_le_capture {
        state_le.node.enumerateChildren { node in
          switch LocalElements.Parse(
            node: node, inTree: tree, withScope: current_scopes)
          {
          case .Ok((let le, let le_parsed_scopes)):
            current_scopes = le_parsed_scopes
            parsed_les.append(le)
          case .Error(let e):
            parse_err = e
          }
        }
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }

      var parsed_s: [EvaluatableStatement] = Array()

      if !statements_capture.isEmpty {
        for statement in statements_capture {
          statement.node.enumerateChildren { node in
            switch Statements.Parse(
              node: node, inTree: tree, withScope: current_scopes)
            {
            case .Ok((let le, let le_parsed_scopes)):
              current_scopes = le_parsed_scopes
              parsed_s.append(le)
            case .Error(let e):
              parse_err = e
            }
          }
        }
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }

      // TODO: Now that scopes are involved, doing this out of order will not work!
      guard !state_name_capture.isEmpty,
        !transition_capture.isEmpty,
        case .Ok(let parsed_state_name) = Identifier.Parse(
          node: state_name_capture[0].node, inTree: tree, withScopes: scopes)
      else {
        return Result.Error(Error(withMessage: "Could not parse a parser declaration"))
      }

      switch TransitionStatement.Parse(
        node: transition_capture[0].node, inTree: tree, withScope: current_scopes)
      {
      case .Ok((.some(let transition_statement), let current_scopes)):
        return Result.Ok(
          (
            ParserState(
              name: parsed_state_name, withLocalElements: parsed_les,
              withStatements: parsed_s,
              withTransition: transition_statement), current_scopes
          ))
      case .Error(let e): return .Error(e)
      case .Ok((.none, _)): return .Error(Error(withMessage: "Missing transition statement"))
      }

    }
  }

  static func Parse(
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
      switch Parser.State.Parse(node: parser_state, inTree: tree, withLexicalScopes: scopes) {
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
