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
import Lang
import Runtime
import SwiftTreeSitter
import TreeSitterExtensions
import TreeSitterP4

let p4lang = Language(tree_sitter_p4())

public protocol ParseableParserStatement {
  static func Parse(
    node: Node, inTree tree: MutableTree, withScope scopes: Scopes
  ) -> Result<(EvaluatableParserStatement?, Scopes)>
}

extension ExpressionStatement: ParseableParserStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScope scopes: Scopes
  ) -> Result<(EvaluatableParserStatement?, Scopes)> {
    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expressionStatement (expression) @expression)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = parser_state_query.execute(node: node, in: tree)
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

extension ParserAssignmentStatement: ParseableParserStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScope scopes: Scopes
  ) -> Result<(EvaluatableParserStatement?, Scopes)> {

    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(assignmentStatement (expression) @lvalue (assignment) (expression) @value)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = parser_state_query.execute(node: node, in: tree)
    let parser_declaration = qr.next()!

    let lvalue_capture = parser_declaration.captures(named: "lvalue")
    let value_capture = parser_declaration.captures(named: "value")

    // There must be a type name and a variable name
    guard !lvalue_capture.isEmpty,
      !value_capture.isEmpty,
      let lvalue_expression_raw = lvalue_capture[0].node.text,
      let value_capture_raw = value_capture[0].node.text
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parser assignment statement"))
    }

    let lvalue_identifier = Identifier(name: lvalue_expression_raw)

    let value =
      if !value_capture_raw.isEmpty {
        value_capture_raw
      } else {
        ""
      }

    guard case Result.Ok(let declared_value) = scopes.evaluate(identifier: lvalue_identifier) else {
      return Result.Error(
        Error(withMessage: "Cannot assign to variable not in scope"))
    }

    return switch Parser.ParseValueType(type: declared_value.type(), withValue: value) {
    case Result.Ok(let value_type):
      Result.Ok(
        (ParserAssignmentStatement(withLValue: lvalue_identifier, withValue: value_type), scopes))
    case Result.Error(let e):
      Result.Error(
        Error(
          withMessage:
            "\(declared_value) has type \(declared_value.type()) but rvalue has mismatched type (\(e))"))
    }
  }
}

extension VariableDeclarationStatement: ParseableParserStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree, withScope scopes: Scopes
  ) -> Result<(EvaluatableParserStatement?, Scopes)> {
    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(variableDeclaration (annotations)? (typeRef) @type-name variable_name: (identifier) @identifier ((assignment) (expression) @value)?)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok((.none, scopes))
    }

    let qr = parser_state_query.execute(node: node, in: tree)
    guard let parser_declaration = qr.next() else {
      return .Ok((.none, scopes))
    }

    let type_name_capture = parser_declaration.captures(named: "type-name")
    let variable_name_capture = parser_declaration.captures(named: "identifier")
    let value_capture = parser_declaration.captures(named: "value")

    // There must be a type name and a variable name
    guard !type_name_capture.isEmpty,
      !variable_name_capture.isEmpty,
      let variable_name = variable_name_capture[0].node.text,
      let type_name = type_name_capture[0].node.text
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parser variable declaration statement"))
    }

    let value =
      if !value_capture.isEmpty {
        value_capture[0].node.text!
      } else {
        ""
      }

    guard case .Ok(let p4_type) = Parser.ParseBasicType(type: type_name) else {
      return Result.Error(
        Error(withMessage: "Could not parse a P4 type from \(type_name)"))
    }

    return switch Parser.ParseValueType(type: p4_type, withValue: value) {
    case Result.Ok(let value_type):
      // This scope should have an additional variable in scope.
      Result.Ok(
        (
          VariableDeclarationStatement(
            withVariable: Variable(name: variable_name, withValue: value_type, isConstant: false)),
          scopes.declare(
            variable: Variable(name: variable_name, withValue: value_type, isConstant: false))
        ))
    case Result.Error(let e):
      Result.Error(e)
    }
  }
}

public struct Parser {
  static func ParseBasicType(type: String) -> Result<P4Type> {
    if type == "bool" {
      return .Ok(P4Boolean.create())
    } else if type == "string" {
      return .Ok(P4String.create())
    } else if type == "int" {
      return .Ok(P4Int.create())
    }
    return Result.Error(Error(withMessage: "Type name not recognized"))
  }

  static func ParseValueType(type: P4Type, withValue value: String) -> Result<P4Value> {
    if type.eq(rhs: P4Boolean.create()) {
      // Default
      if value == "" {
        return .Ok(P4BooleanValue(withValue: false))
      }
      if value == "true" {
        return .Ok(P4BooleanValue(withValue: true))
      } else if value == "false" {
        return .Ok(P4BooleanValue(withValue: false))
      }
      return .Error(Error(withMessage: "Cannot convert \(value) into boolean value"))

    } else if type.eq(rhs: P4String.create()) {
      return .Ok(P4StringValue.init(withValue: value))

    } else if type.eq(rhs: P4Int.create()) {
      // Default
      if value == "" {
        return .Ok(P4IntValue.init(withValue: 0))
      }

      guard let parsed_value = Swift.Int(value) else {
        return .Error(Error(withMessage: "Cannot convert \(value) into integer value"))
      }
      return .Ok(P4IntValue.init(withValue: parsed_value))
    }

    return .Error(Error(withMessage: "Invalid type"))
  }

  public struct P4Parser {

    static func LocalElements(
      node: Node, inTree tree: MutableTree, withScope scopes: Scopes
    ) -> Result<(EvaluatableParserStatement, Scopes)> {
      let localElementsParsers: [ParseableParserStatement.Type] = [
        VariableDeclarationStatement.self
      ]

      for local_element_parser in localElementsParsers {
        if case Result.Ok((.some(let parsed), let parsed_updated_scopes)) =
          local_element_parser.Parse(
            node: node, inTree: tree, withScope: scopes)
        {
          return Result.Ok((parsed, parsed_updated_scopes))
        }
      }

      return Result.Error(
        Error(
          withMessage:
            "Failed to parse any local elements from specified local elements: \(node.text!)")
      )
    }

    static func Statements(
      node: Node, inTree tree: MutableTree, withScope scopes: Scopes
    ) -> Result<(EvaluatableParserStatement, Scopes)> {
      let statementParsers: [ParseableParserStatement.Type] = [
        ExpressionStatement.self, VariableDeclarationStatement.self, ParserAssignmentStatement.self
      ]

      // Iterate through statement parsers and give each one a chance.
      for parser in statementParsers {
        if case Result.Ok((.some(let parsed), let updatedScopes)) = parser.Parse(
          node: node, inTree: tree, withScope: scopes)
        {
          return .Ok((parsed, updatedScopes))
        }

      }
      return Result.Error(
        Error(withMessage: "Failed to parse a statement element: \(node.text!)"))
    }

    static func TransitionKeysetExpression(
      node: Node, inTree tree: MutableTree, withScopes scopes: Scopes
    ) -> Result<([KeysetExpression], Scopes)> {
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

    static func TransitionSelectExpression(
      node: Node, inTree tree: MutableTree, withScope scopes: Scopes
    ) -> Result<(ParserTransitionStatement?, Scopes)> {
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
          switch TransitionKeysetExpression(node: body[0].node, inTree: tree, withScopes: scopes)
        {
        case .Ok((let kse, let newScopes)):
          Result<(ParserTransitionStatement?, Scopes)>.Ok(
            (
              ParserTransitionStatement(
                withTransitionExpression: ParserTransitionSelectExpression(
                  withSelector: expression, withKeysetExpressions: kse)), newScopes
            ))
        case .Error(let e): Result.Error(e)
        }
      }
    }

    static func TransitionStatement(
      node: Node, inTree tree: MutableTree, withScope scopes: Scopes
    ) -> Result<(ParserTransitionStatement?, Scopes)> {
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

      return TransitionSelectExpression(node: node, inTree: tree, withScope: scopes)
    }

    static func State(
      node: Node, inTree tree: MutableTree, withScopes scopes: Scopes
    ) -> Result<(ParserState, Scopes)> {
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

      // TODO: Now that scopes are involved, doing this out of order will not work!
      guard !state_name_capture.isEmpty,
        !transition_capture.isEmpty,
        let parsed_state_name = state_name_capture[0].node.text,
        case .Ok((let transition_statement, (var newStateScopes))) = TransitionStatement(
          node: transition_capture[0].node, inTree: tree, withScope: scopes)
      else {
        return Result.Error(Error(withMessage: "Could not parse a parser declaration"))
      }

      var parsed_les: [EvaluatableParserStatement] = Array()
      var parse_err: Error? = .none

      for state_le in state_le_capture {
        state_le.node.enumerateChildren { node in
          switch LocalElements(
            node: node, inTree: tree, withScope: newStateScopes)
          {
          case .Ok((let le, let le_parsed_scopes)):
            newStateScopes = le_parsed_scopes
            parsed_les.append(le)
          case .Error(let e):
            parse_err = e
          }
        }
      }

      if let parse_err = parse_err {
        return Result.Error(parse_err)
      }

      var parsed_s: [EvaluatableParserStatement] = Array()

      if !statements_capture.isEmpty {
        for statement in statements_capture {
          statement.node.enumerateChildren { node in
            switch Statements(
              node: node, inTree: tree, withScope: newStateScopes)
            {
            case .Ok((let le, let le_parsed_scopes)):
              newStateScopes = le_parsed_scopes
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

      return Result.Ok(
        (
          ParserState(
            name: parsed_state_name, withLocalElements: parsed_les,
            withStatements: parsed_s,
            withTransition: transition_statement!), newStateScopes
        ))
    }
  }
  static func Parser(
    withName name: Identifier, node: Node, inTree tree: MutableTree, withScopes scopes: Scopes
  ) -> Result<(Lang.Parser, Scopes)> {
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

    var parser = Lang.Parser(withName: name)

    // Build a state from each one listed.
    let qr = parser_state_query.execute(node: node, in: tree)
    let qr_value = qr.next()!
    let captures = qr_value.captures(named: "parser-states")

    var error: Error? = .none

    var parser_scopes = scopes

    // TODO: Assert that there is only one.
    captures[0].node.enumerateChildren { parser_state in
      switch P4Parser.State(node: parser_state, inTree: tree, withScopes: scopes) {
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

  public static func Program(_ source: String) -> Result<Program> {
    let p = SwiftTreeSitter.Parser.init()

    do {
      try p.setLanguage(p4lang)
    } catch {
      return Result.Error(Error(withMessage: "Could not configure the P4 parser"))
    }

    let result = p.parse(source)
    guard let tree = result,
      !tree.isError(lang: p4lang),
      !tree.containsMissing(lang: p4lang)
    else {
      return Result.Error(Error(withMessage: "Could not compile the P4 program"))
    }

    guard
      let parser_declaration_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(parserDeclaration (parserType parser_name: (identifier) @parser-name) (parserStates) @parser-states)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(
        Error(withMessage: "Could not compile the parser declaration tree sitter query"))
    }

    var program = Lang.Program()

    // Set up a lexical scope for parsing.
    var program_scope = Scopes().enter()

    let parser_qc = parser_declaration_query.execute(in: tree)

    for parser_declaration in parser_qc {
      switch Parser(
        withName: Identifier(name: parser_declaration.nodes[0].text!),
        node: parser_declaration.nodes[1], inTree: tree, withScopes: program_scope)
      {
      case Result.Ok((let parser, let new_program_scope)):
        program.types.append(parser)
        program_scope = new_program_scope
      case Result.Error(let error): return Result.Error(error)
      }
    }

    return Result.Ok(program)
  }
}
