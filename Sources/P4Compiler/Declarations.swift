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

extension Declaration: CompilableDeclaration {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(P4Type, CompilerContext)?> {

    guard let node_type = node.nodeType,
      node_type == "type_declaration"
    else {
      return .Ok(.none)
    }

    // Assume that it is a struct declaration
    return StructDeclaration.Compile(node: node.child(at: 0)!, withContext: context)
  }
}

struct StructDeclaration {
  static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(P4Type, CompilerContext)?> {

    var currentChildIdx = 0
    var currentChildIdxSafe = 1

    var currentChild: Node? = .none

    guard let node_type = node.nodeType,
      node_type == "struct_declaration"
    else {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Did not find a struct declaration"))
    }

    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing elements in struct declaration"))
    }

    // Skip the keyword struct
    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing elements in struct declaration"))
    }

    // The name of the struct type.
    currentChild = node.child(at: currentChildIdx)
    let maybe_struct_identifier = Identifier.Compile(
      node: currentChild!, withContext: context)
    guard case Result.Ok(let struct_identifier) = maybe_struct_identifier else {
      return Result.Error(maybe_struct_identifier.error()!)
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1

    // Skip the '{'
    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(node: node, withError: "Missing element of struct declaration"))
    }

    currentChild = node.child(at: currentChildIdx)

    // If there are no fields, it will be a "}"
    if currentChild!.nodeType == "}" {
      let struc = P4Struct(withName: struct_identifier, andFields: P4StructFields([]))
      return Result.Ok(
        (
          struc,
          context.update(
            newTypes: context.types.declare(identifier: struct_identifier, withValue: struc))
        ))
    }

    var parse_errs: [Error] = Array()
    var current_context = context
    var parsed_fields: [P4StructFieldIdentifier] = Array()

    if currentChild!.nodeType == "struct_declaration_fields" {
      currentChild!.enumerateNamedChildren { declaration_field in
        print("declaration field: \(declaration_field)")
        switch VariableDeclarationStatement.Compile(
          node: declaration_field, withContext: current_context)
        {
        case .Ok((let declaration, let updated_context)):
          let variable_declaration = declaration as! VariableDeclarationStatement
          parsed_fields.append(
            P4StructFieldIdentifier(
              id: variable_declaration.identifier, withType: variable_declaration.initializer.type()
            ))
          current_context = updated_context
        case .Error(let e): parse_errs.append(e)
        }
      }
    }

    if !parse_errs.isEmpty {
      return .Error(
        Error(
          withMessage: "Error(s) parsing select cases: "
            + (parse_errs.map { error in
              return "\(error.msg)"
            }.joined(separator: ";"))))
    }

    let declared_struct = P4Struct(
      withName: struct_identifier, andFields: P4StructFields(parsed_fields))
    return .Ok(
      (
        declared_struct,
        current_context.update(
          newTypes: current_context.types.declare(
            identifier: struct_identifier, withValue: declared_struct))
      ))
  }
}

extension P4Lang.Parser: CompilableDeclaration {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(P4Type, CompilerContext)?> {

    let parser_node = node
    if parser_node.nodeType != "parserDeclaration" {
      return .Ok(.none)
    }

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    if parser_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: parser_node, withError: "Missing elements of parser declaration"))
    }

    currentChild = parser_node.child(at: currentChildIdx)
    if currentChild!.nodeType != "parserType" {
      return .Error(
        ErrorOnNode(node: currentChild!, withError: "Missing type for parser declaration"))
    }

    let type_node = currentChild
    var parser_name: Common.Identifier? = .none

    do {
      // Parse the parser type (type_node)
      var currentChildIdx = 0
      var currentChildIdxSafe = 1

      if type_node!.childCount < currentChildIdxSafe {
        return .Error(
          ErrorOnNode(
            node: parser_node, withError: "Missing elements of parser type in parser declaration"))
      }

      var currentChild = type_node!.child(at: currentChildIdx)
      if currentChild!.nodeType == "annotations" {
        return .Error(
          ErrorOnNode(
            node: currentChild!, withError: "Annotations in parser type are not yet handled."))
        // Will increment indexes here.
      }

      // Skip the parser keyword
      currentChildIdx += 1
      currentChildIdxSafe += 1
      if type_node!.childCount < currentChildIdxSafe {
        return .Error(
          ErrorOnNode(node: type_node!, withError: "Missing name in parser type declaration"))
      }
      currentChild = type_node?.child(at: currentChildIdx)

      switch Identifier.Compile(node: currentChild!, withContext: context) {
      case .Ok(let id): parser_name = id
      case .Error(let e):
        return .Error(e)
      }
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if parser_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: parser_node, withError: "Missing elements of parser declaration"))
    }

    if currentChild!.nodeType == "constructorParameters" {
      return .Error(
        ErrorOnNode(node: currentChild!, withError: "Constructor parameters are not yet handled.")
      )
      // Will increment indexes here.
    }

    // Skip the '{'
    currentChildIdx += 1
    currentChildIdxSafe += 1
    if parser_node.childCount < currentChildIdxSafe {
      return .Error((Error(withMessage: "Missing body of parser declaration")))
    }
    currentChild = parser_node.child(at: currentChildIdx)

    if currentChild!.nodeType == "parserLocalElements" {
      return .Error(
        ErrorOnNode(node: currentChild!, withError: "Parser Local Elements are not yet handled."))
      // Will increment indexes here.
    }

    if parser_node.childCount < currentChildIdxSafe {
      return .Error((Error(withMessage: "Missing body of parser declaration")))
    }

    if currentChild!.nodeType != "parserStates" {
      return .Error(Error(withMessage: "Missing parser states in parser declaration"))
    }

    switch Parser.Compile(
      withName: parser_name!, node: currentChild!, withContext: context)
    {
    case Result.Ok((let parser, let updated_context)):
      // Create a new context with the name of the parser that was just compiled in scope.
      return .Ok(
        (
          parser,
          context.update(
            newInstances: updated_context.instances.declare(
              identifier: parser.name, withValue: parser))
        ))
    case Result.Error(let error): return .Error(error)
    }

    // Assume that there is only '}' after -- the parser guaranteed that for us!
  }
}
