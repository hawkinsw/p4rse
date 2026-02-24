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

    guard
      let parser_assignment_statement_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(assignmentStatement (expression) @lvalue (assignment) (expression) @value)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = parser_assignment_statement_query.execute(node: node, in: tree)
    guard let parser_assignment_statement = qr.next() else {
      return Result.Ok((.none, scopes))
    }

    let lvalue_capture = parser_assignment_statement.captures(named: "lvalue")
    let rvalue_capture = parser_assignment_statement.captures(named: "value")

    // There must be a type name and a variable name
    guard !lvalue_capture.isEmpty,
      !rvalue_capture.isEmpty,
      let lvalue_expression_raw = lvalue_capture[0].node.text
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parser assignment statement"))
    }

    let rvalue_raw = rvalue_capture[0].node
    let maybe_parsed_rvalue = Expression.Parse(node: rvalue_raw, inTree: tree, withScopes: scopes)
    guard case Result.Ok(let rvalue) = maybe_parsed_rvalue else {
      return Result.Error(maybe_parsed_rvalue.error()!)
    }

    let lvalue_identifier = Identifier(name: lvalue_expression_raw)
    guard case Result.Ok(let lvalue_type) = scopes.lookup(identifier: lvalue_identifier) else {
      return Result.Error(
        Error(withMessage: "Cannot assign to variable \(lvalue_identifier) not in scope"))
    }

    if rvalue.type().eq(rhs: lvalue_type) {
      return Result.Ok(
        (
          ParserAssignmentStatement(
            withLValue: TypedIdentifier(name: lvalue_expression_raw, withType: lvalue_type),
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
        VariableDeclarationStatement.self,
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
    ) -> Result<([KeysetExpression], LexicalScopes)> {
      guard
        let transition_selection_expression_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "((keysetExpression (expression) @ks) (colon) (identifier) @next-state)"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let qr = transition_selection_expression_query.execute(node: node, in: tree)

      var kses: [KeysetExpression] = Array()

      for expression in qr {
        let next_state_name = expression.captures[1].node.text!
        if case .Error(let e) = Expression.Parse(
          node: expression.captures[0].node, inTree: tree, withScopes: scopes
        )
        .map(block: { expression in
          kses.append(
            KeysetExpression(
              withKey: expression, withNextStateName: next_state_name))
          return .Ok(expression)
        }) {
          return .Error(e)
        }
      }

      return .Ok((kses, scopes))
    }
  }

  public struct TransitionSelectExpression {
    static func Parse(
      node: Node, inTree tree: MutableTree, withScope scopes: LexicalScopes
    ) -> Result<(ParserTransitionStatement?, LexicalScopes)> {
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

      return Expression.Parse(node: selector[0].node, inTree: tree, withScopes: scopes).map {
        expression in
        return
          switch TransitionSelectExpressionCaseStatement.Parse(
            node: body[0].node, inTree: tree, withLexicalScopes: scopes)
        {
        case .Ok((let kse, let newLexicalScopes)):
          Result<(ParserTransitionStatement?, LexicalScopes)>.Ok(
            (
              ParserTransitionStatement(
                withTransitionExpression: ParserTransitionSelectExpression(
                  withSelector: expression, withKeysetExpressions: kse)), newLexicalScopes
            ))
        case .Error(let e): Result.Error(e)
        }
      }
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
        return .Ok(
          (ParserTransitionStatement(withNextState: transition_capture[0].node.text!), scopes))
      }

      return TransitionSelectExpression.Parse(node: node, inTree: tree, withScope: scopes)
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
        let parsed_state_name = state_name_capture[0].node.text
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
    withName name: Identifier, node: Node, inTree tree: MutableTree,
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
