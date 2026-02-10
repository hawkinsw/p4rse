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
  static func Parse(node: Node, inTree tree: MutableTree) -> Result<EvaluatableParserStatement?>
}

extension ExpressionStatement: ParseableParserStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree
  ) -> Result<EvaluatableParserStatement?> {
    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(expressionStatement (expression) @expression)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok(.none)
    }

    let qr = parser_state_query.execute(node: node, in: tree)
    let query_result = qr.next()!
    let expression_capture = query_result.captures(named: "expression")
    if !expression_capture.isEmpty {
      // TODO: Actually create an ExpressionStatement
      return Result.Ok(ExpressionStatement())
    }
    return Result.Ok(.none)
  }
}

extension VariableDeclarationStatement: ParseableParserStatement {
  public static func Parse(
    node: Node, inTree tree: MutableTree
  ) -> Result<EvaluatableParserStatement?> {
    guard
      let parser_state_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "((annotations)? (typeRef) @type-name variable_name: (identifier) @identifier ((assignment) (expression) @value)?)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Ok(.none)
    }

    let qr = parser_state_query.execute(node: node, in: tree)
    let parser_declaration = qr.next()!

    let type_name_capture = parser_declaration.captures(named: "type-name")
    let variable_name_capture = parser_declaration.captures(named: "identifier")
    let value_capture = parser_declaration.captures(named: "value")

    // There must be a type name and a variable name
    guard !type_name_capture.isEmpty,
      !variable_name_capture.isEmpty,
      let variable_name = variable_name_capture[0].node.text,
      let type_name = type_name_capture[0].node.text
    else {
      return Result.Error(Error(withMessage: "Could not parse a parser declaration"))
    }

    let value =
      if !value_capture.isEmpty {
        value_capture[0].node.text!
      } else {
        ""
      }

    return switch Parser.ParseValueType(type: type_name, withValue: value) {
    case Result.Ok(let value_type):
      Result.Ok(
        VariableDeclarationStatement(
          withVariable: Variable(name: variable_name, withValue: value_type, isConstant: false)))
    case Result.Error(let e):
      Result.Error(e)
    }
  }
}

public struct Parser {
  static func ParseValueType(type: String, withValue value: String) -> Result<P4Value> {
    if type == "bool" {
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

    } else if type == "string" {
      return .Ok(P4StringValue.init(withValue: value))

    } else if type == "int" {
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
      node: Node, inTree tree: MutableTree
    ) -> Result<[EvaluatableParserStatement]> {

      guard
        let parser_le_statement_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserLocalElement) @parser-local-element"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let localElementsParsers: [ParseableParserStatement.Type] = [
        VariableDeclarationStatement.self
      ]

      var localElements: [EvaluatableParserStatement] = Array()

      let qr = parser_le_statement_query.execute(node: node, in: tree)
      for raw_le_statement in qr {
        let raw_le_statement_capture = raw_le_statement.captures(named: "parser-local-element")
        var parsed_le_statement: EvaluatableParserStatement? = .none

        for le_parser in localElementsParsers {
          if case Result.Ok(.some(let parsed)) = le_parser.Parse(
            node: raw_le_statement_capture[0].node, inTree: tree)
          {
            parsed_le_statement = parsed
            break
          }
        }

        if let le_statement = parsed_le_statement {
          localElements.append(le_statement)
        } else {
          // There were no parseable statements.
          return Result.Error(
            Error(withMessage: "Failed to parse a local element: \(raw_le_statement)"))
        }
      }

      return Result.Ok(localElements)
    }

    static func Statements(
      node: Node, inTree tree: MutableTree
    ) -> Result<[EvaluatableParserStatement]> {

      guard
        let parser_statement_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserStatement) @parser-statement"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let statementParsers: [ParseableParserStatement.Type] = [
        ExpressionStatement.self, VariableDeclarationStatement.self,
      ]

      var statements: [EvaluatableParserStatement] = Array()

      let qr = parser_statement_query.execute(node: node, in: tree)
      for raw_statement in qr {
        let raw_statement_capture = raw_statement.captures(named: "parser-statement")

        var parsed_statement: EvaluatableParserStatement? = .none

        // Iterate through statement parsers and give each one a chance.
        for parser in statementParsers {
          if case Result.Ok(.some(let parsed)) = parser.Parse(
            node: raw_statement_capture[0].node, inTree: tree)
          {
            parsed_statement = parsed
            break
          }
        }

        if let statement = parsed_statement {
          statements.append(statement)
        } else {
          // There were no parseable statements.
          return Result.Error(
            Error(withMessage: "Failed to parse a statement element: \(raw_statement)"))
        }
      }
      return Result.Ok(statements)
    }

    static func TransitionKeysetExpression(
      node: Node, inTree tree: MutableTree
    ) -> Result<[KeysetExpression]> {
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
        if case .Error(let e) = Expression.Parse(node: expression.captures[0].node, inTree: tree)
          .map(block: { expression in
            kses.append(
              KeysetExpression(
                withKey: expression, withNextStateName: next_state_name))
            return .Ok(expression)
          })
        {
          return .Error(e)
        }
      }

      return .Ok(kses)
    }

    static func TransitionSelectExpression(
      node: Node, inTree tree: MutableTree
    ) -> Result<ParserTransitionStatement> {
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

      return Expression.Parse(node: selector[0].node, inTree: tree).map { expression in
        return switch TransitionKeysetExpression(node: body[0].node, inTree: tree) {
        case .Ok(let kse):
          Result<ParserTransitionStatement>.Ok(
            ParserTransitionStatement(
              withTransitionExpression: ParserTransitionSelectExpression(
                withSelector: expression, withKeysetExpressions: kse)))
        case .Error(let e): Result<ParserTransitionStatement>.Error(e)
        }
      }
    }

    static func TransitionStatement(
      node: Node, inTree tree: MutableTree
    ) -> Result<ParserTransitionStatement> {
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
        return .Ok(ParserTransitionStatement(withNextState: transition_capture[0].node.text!))
      }

      return TransitionSelectExpression(node: node, inTree: tree)
    }

    static func State(node: Node, inTree tree: MutableTree) -> Result<ParserState> {
      guard
        let parser_state_query = try? SwiftTreeSitter.Query(
          language: p4lang,
          data: String(
            "(parserState (state) (identifier) @state-name (parserLocalElements)? @state-local-elements (parserStatements)? @state-statements (parserTransitionStatement) @transition)"
          ).data(using: String.Encoding.utf8)!)
      else {
        return Result.Error(Error(withMessage: "Could not compile the tree sitter query"))
      }

      let qr = parser_state_query.execute(node: node, in: tree)

      let parser_declaration = qr.next()!

      let transition_capture = parser_declaration.captures(named: "transition")
      let state_name_capture = parser_declaration.captures(named: "state-name")
      let state_le_capture = parser_declaration.captures(named: "state-local-elements")
      let statements_capture = parser_declaration.captures(named: "state-statements")

      // There must be a state name and there must be a transition statement.
      guard !state_name_capture.isEmpty,
        !transition_capture.isEmpty,
        let parsed_state_name = state_name_capture[0].node.text,
        case .Ok(let transition_statement) = TransitionStatement(
          node: transition_capture[0].node, inTree: tree)
      else {
        return Result.Error(Error(withMessage: "Could not parse a parser declaration"))
      }

      let maybe_parsed_les =
        if !state_le_capture.isEmpty {
          LocalElements(node: state_le_capture[0].node, inTree: tree)
        } else {
          Result.Ok([EvaluatableParserStatement]())
        }

      guard case Result<[EvaluatableParserStatement]>.Ok(let parsed_les) = maybe_parsed_les else {
        return Result.Error(maybe_parsed_les.error()!)
      }

      let maybe_parsed_statements =
        if !statements_capture.isEmpty {
          Statements(node: statements_capture[0].node, inTree: tree)
        } else {
          Result.Ok([EvaluatableParserStatement]())
        }
      guard
        case Result<[EvaluatableParserStatement]>.Ok(let parsed_statements) =
          maybe_parsed_statements
      else {
        return Result.Error(maybe_parsed_statements.error()!)
      }

      // TODO: Validate that there is only one!
      return Result.Ok(
        ParserState(
          name: parsed_state_name, withLocalElements: parsed_les,
          withStatements: parsed_statements,
          withTransition: transition_statement))
    }
  }
  static func Parser(
    withName name: Identifier, node: Node, inTree tree: MutableTree
  ) -> Result<Lang.Parser> {
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

    // TODO: Assert that there is only one.
    captures[0].node.enumerateChildren { parser_state in
      switch P4Parser.State(node: parser_state, inTree: tree) {
      case Result.Ok(let state): parser.states = parser.states.append(state: state)
      case Result.Error(let e): error = e
      }
    }

    if let error = error {
      return .Error(error)
    }
    return Result.Ok(parser)
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

    let parser_qc = parser_declaration_query.execute(in: tree)

    for parser_declaration in parser_qc {
      switch Parser(
        withName: Identifier(name: parser_declaration.nodes[0].text!),
        node: parser_declaration.nodes[1], inTree: tree)
      {
      case Result.Ok(let parser): program.types.append(parser)
      case Result.Error(let error): return Result.Error(error)
      }
    }

    return Result.Ok(program)
  }
}
