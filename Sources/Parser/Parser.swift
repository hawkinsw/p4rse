// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

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

import P4
import SwiftTreeSitter
import TreeSitterP4
import TreeSitterExtensions

let p4lang = Language(tree_sitter_p4())

public protocol ParseableValueType {
  static func Parse(type: String, withValue value: String) -> Result<P4.ValueType>
}

// This seems unnecessary because all the value types are in a single enum?
extension P4.ValueType: ParseableValueType {
  public static func Parse(type: String, withValue value: String) -> Result<P4.ValueType> {
    if type == "bool" {
      // Default
      if value == "" {
        return .Ok(P4.ValueType.Boolean(false))
      }

      if value == "true" {
        return .Ok(P4.ValueType.Boolean(true))
      } else if value == "false" {
        return .Ok(P4.ValueType.Boolean(false))
      }
      return .Error(Error(withMessage: "Cannot convert \(value) into boolean value"))

    } else if type == "string" {
      return .Ok(P4.ValueType.String(value))

    } else if type == "int" {
      // Default
      if value == "" {
        return .Ok(P4.ValueType.Int(0))
      }

      guard let parsed_value = Swift.Int(value) else {
        return .Error(Error(withMessage: "Cannot convert \(value) into integer value"))
      }
      return .Ok(P4.ValueType.Int(parsed_value))
    }

    return .Error(Error(withMessage: "Invalid type"))
  }
}

public protocol ParseableParserStatement {
  static func Parse(node: Node, inTree tree: MutableTree) -> Result<P4.ParserStatement?>
}

extension P4.ExpressionStatement: ParseableParserStatement {
  public static func Parse(node: Node, inTree tree: MutableTree) -> Result<P4.ParserStatement?> {
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
      return Result.Ok(P4.ExpressionStatement())
    }

    return Result.Ok(.none)

  }
}

extension P4.VariableDeclarationStatement: ParseableParserStatement {
  public static func Parse(node: Node, inTree tree: MutableTree) -> Result<P4.ParserStatement?> {
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

    return switch P4.ValueType.Parse(type: type_name, withValue: value) {
    case Result.Ok(let value_type):
      Result.Ok(
        P4.VariableDeclarationStatement(
          withVariable: Variable(name: variable_name, withValue: value_type, isConstant: false)))
    case Result.Error(let e):
      Result.Error(e)
    }
  }
}

public struct Parser {

  public struct P4Parser {
    static func LocalElements(
      node: Node, inTree tree: MutableTree
    ) -> Result<[P4.ParserStatement]> {

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
        P4.VariableDeclarationStatement.self
      ]

      var localElements: [P4.ParserStatement] = Array()

      let qr = parser_le_statement_query.execute(node: node, in: tree)
      for raw_le_statement in qr {
        let raw_le_statement_capture = raw_le_statement.captures(named: "parser-local-element")
        var parsed_le_statement: P4.ParserStatement? = .none

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
    ) -> Result<[P4.ParserStatement]> {

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
        P4.ExpressionStatement.self, P4.VariableDeclarationStatement.self,
      ]

      var statements: [P4.ParserStatement] = Array()

      let qr = parser_statement_query.execute(node: node, in: tree)
      for raw_statement in qr {
        let raw_statement_capture = raw_statement.captures(named: "parser-statement")

        var parsed_statement: P4.ParserStatement? = .none

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

    static func TransitionStatement(
      node: Node, inTree tree: MutableTree
    ) -> P4.ParserTransitionStatement?
    {
      return P4.ParserTransitionStatement()
    }

    static func State(node: Node, inTree tree: MutableTree) -> Result<P4.ParserState> {
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
        let transition_statement = TransitionStatement(
          node: transition_capture[0].node, inTree: tree)
      else {
        return Result.Error(Error(withMessage: "Could not parse a parser declaration"))
      }

      let maybe_parsed_les =
        if !state_le_capture.isEmpty {
          LocalElements(node: state_le_capture[0].node, inTree: tree)
        } else {
          Result.Ok([P4.ParserStatement]())
        }

      guard case Result<[P4.ParserStatement]>.Ok(let parsed_les) = maybe_parsed_les else {
        return Result.Error(maybe_parsed_les.error()!)
      }

      let maybe_parsed_statements =
        if !statements_capture.isEmpty {
          Statements(node: statements_capture[0].node, inTree: tree)
        } else {
          Result.Ok([P4.ParserStatement]())
        }
      guard case Result<[P4.ParserStatement]>.Ok(let parsed_statements) = maybe_parsed_statements
      else {
        return Result.Error(maybe_parsed_statements.error()!)
      }

      // TODO: Validate that there is only one!
      return Result.Ok(
        P4.ParserState(
          name: parsed_state_name, withLocalElements: parsed_les,
          withStatements: parsed_statements,
          withTransition: transition_statement))
    }
  }
  static func Parser(node: Node, inTree tree: MutableTree) -> Result<P4.Parser> {
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

    var parser = P4.Parser()

    // Build a state from each one listed.
    for parser_states in parser_state_query.execute(node: node, in: tree) {
      switch P4Parser.State(node: parser_states.nodes[0], inTree: tree) {
      case Result.Ok(let state): parser.states.append(state)
      case Result.Error(let error): return Result.Error(error)
      }
    }
    return Result.Ok(parser)
  }

  public static func Program(_ source: String) -> Result<P4.Program> {
    let p = SwiftTreeSitter.Parser.init()

    do {
      try p.setLanguage(p4lang)
    } catch {
      return Result.Error(Error(withMessage: "Could not configure the P4 parser"))
    }

    let result = p.parse(source)
    guard let tree = result,
      !tree.isError(lang: p4lang)
    else {
      return Result.Error(Error(withMessage: "Could not compile the P4 program"))
    }

    guard
      let parser_declaration_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(parserDeclaration (parserType) (parserStates) @parser-states)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(
        Error(withMessage: "Could not compile the parser declaration tree sitter query"))
    }

    var program: P4.Program = P4.Program()

    let parser_qc = parser_declaration_query.execute(in: tree)

    for parser_declaration in parser_qc {
      switch Parser(node: parser_declaration.nodes[0], inTree: tree) {
      case Result.Ok(let parser): program.parsers.append(parser)
      case Result.Error(let error): return Result.Error(error)
      }
    }

    return Result.Ok(program)
  }
}
