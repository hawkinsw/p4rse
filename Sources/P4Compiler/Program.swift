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

public struct Program {
  public static func Compile(_ source: String) -> Result<P4Lang.Program> {

    let maybe_parser = ConfigureP4Parser()
    guard case .Ok(let p) = maybe_parser else {
      return .Error(maybe_parser.error()!)
    }

    let result = p.parse(source)
    guard let tree = result,
      !tree.isError(lang: p4lang),
      !tree.containsMissing(lang: p4lang)
    else {
      return Result.Error(Error(withMessage: "Could not compile the P4 program"))
    }

    var program = P4Lang.Program()

    // Set up a context for parsing.
    var compilation_context = CompilerContext(withNames: LexicalScopes().enter())

    var errors: [Error] = Array()

    result?.rootNode?.enumerateNamedChildren { declaration_node in
      if declaration_node.nodeType != "declaration" {
        return
      }

      let parser_node = declaration_node.child(at: 0)!
      if parser_node.nodeType != "parserDeclaration" {
        return
      }

      var currentChildIdx = 0
      var currentChildIdxSafe = 1
      var currentChild: Node? = .none

      if parser_node.childCount < currentChildIdxSafe {
        errors.append(
          ErrorOnNode(node: parser_node, withError: "Missing elements of parser declaration"))
        return
      }
      currentChild = parser_node.child(at: currentChildIdx)
      if currentChild!.nodeType != "parserType" {
        errors.append(
          ErrorOnNode(node: currentChild!, withError: "Missing type for parser declaration"))
        return
      }

      let type_node = currentChild
      var parser_name: Common.Identifier? = .none

      do {
        // Parse the parser type (type_node)
        var currentChildIdx = 0
        var currentChildIdxSafe = 1

        if type_node!.childCount < currentChildIdxSafe {
          errors.append(
            ErrorOnNode(
              node: parser_node, withError: "Missing elements of parser type in parser declaration")
          )
          return
        }

        var currentChild = type_node!.child(at: currentChildIdx)
        if currentChild!.nodeType == "annotations" {
          errors.append(
            ErrorOnNode(
              node: currentChild!, withError: "Annotations in parser type are not yet handled."))
          return

          // Will increment indexes here.
        }

        // Skip the parser keyword
        currentChildIdx += 1
        currentChildIdxSafe += 1
        if type_node!.childCount < currentChildIdxSafe {
          errors.append(
            ErrorOnNode(node: type_node!, withError: "Missing name in parser type declaration"))
          return
        }
        currentChild = type_node?.child(at: currentChildIdx)

        switch Identifier.Compile(node: currentChild!, withContext: compilation_context) {
        case .Ok(let id): parser_name = id
        case .Error(let e):
          errors.append(e)
          return
        }
      }

      // It's an error if there is no parser name.
      if parser_name == .none {
        return
      }

      currentChildIdx += 1
      currentChildIdxSafe += 1
      if parser_node.childCount < currentChildIdxSafe {
        errors.append(
          ErrorOnNode(node: parser_node, withError: "Constructor parameters are not yet handled."))
        return
      }

      if currentChild!.nodeType == "constructorParameters" {
        errors.append(
          ErrorOnNode(node: currentChild!, withError: "Constructor parameters are not yet handled.")
        )
        return

        // Will increment indexes here.
      }

      // Skip the '{'
      currentChildIdx += 1
      currentChildIdxSafe += 1
      if parser_node.childCount < currentChildIdxSafe {
        errors.append(Error(withMessage: "Missing body of parser declaration"))
        return
      }
      currentChild = parser_node.child(at: currentChildIdx)

      if currentChild!.nodeType == "parserLocalElements" {
        errors.append(
          ErrorOnNode(node: currentChild!, withError: "Parser Local Elements are not yet handled."))
        return
        // Will increment indexes here.
      }

      if parser_node.childCount < currentChildIdxSafe {
        errors.append(Error(withMessage: "Missing body of parser declaration"))
        return
      }

      if currentChild!.nodeType != "parserStates" {
        errors.append(Error(withMessage: "Missing parser states in parser declaration"))
        return
      }

      switch Parser.Compile(
        withName: parser_name!, node: currentChild!, withContext: compilation_context)
      {
      case Result.Ok((let parser, let updated_context)):
        // Create a new context with the name of the parser that was just compiled in scope.
        compilation_context = compilation_context.update(newNames: updated_context.names.declare(identifier: parser.name, withValue: parser))
      case Result.Error(let error): errors.append(error)
      }

      // Assume that there is only '}' after -- the parser guaranteed that for us!
    }

    if !errors.isEmpty {
      return Result.Error(
        Error(
          withMessage: errors.map { error in
            return error.msg
          }.joined(separator: ";")))
    }

    // Any of the types that are in the top-level scope should go into the program!
    program.types = Array(compilation_context.names)
    return Result.Ok(program)
  }
}
