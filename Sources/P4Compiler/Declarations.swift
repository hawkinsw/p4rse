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

    let declaration_compilers: [String: CompilableDeclaration.Type] = [
      "function_declaration": FunctionDeclaration.self,
      "type_declaration": StructDeclaration.self,  // Assume that type declarations are struct declarations.
    ]

    guard let declaration_compiler = declaration_compilers[node.nodeType!] else {
      return .Ok(.none)
    }

    return declaration_compiler.Compile(node: node, withContext: context)
  }
}

extension FunctionDeclaration: CompilableDeclaration {
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(any Common.P4Type, CompilerContext)?> {
    let function_declaration_node = node
    #RequireNodeType<Node, (ParameterList, CompilerContext)>(
      node: function_declaration_node, type: "function_declaration",
      nice_type_name: "Function Declaration")

    var context = context
    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none
    if function_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: function_declaration_node, withError: "Missing function declaration component"))
    }
    currentChild = function_declaration_node.child(at: currentChildIdx)

    let maybe_function_type = Types.CompileType(type: currentChild!, withContext: context)
    guard case .Ok(let function_type) = maybe_function_type else {
      return .Error(maybe_function_type.error()!)
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if function_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: function_declaration_node, withError: "Missing function declaration component"))
    }
    currentChild = function_declaration_node.child(at: currentChildIdx)

    let maybe_function_name = Identifier.Compile(node: currentChild!, withContext: context)
    guard case .Ok(let function_name) = maybe_function_name else {
      return .Error(maybe_function_name.error()!)
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if function_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: function_declaration_node, withError: "Missing function declaration component"))
    }
    currentChild = function_declaration_node.child(at: currentChildIdx)

    let maybe_function_parameters = ParameterList.Compile(node: currentChild!, withContext: context)
    guard case .Ok((let function_parameters, let updated_context)) = maybe_function_parameters
    else {
      return .Error(maybe_function_parameters.error()!)
    }
    context = updated_context

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if function_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: function_declaration_node, withError: "Missing function declaration component"))
    }
    currentChild = function_declaration_node.child(at: currentChildIdx)

    // Add the parameters into scope.
    var function_scope = context.instances.enter()
    for parameter in function_parameters.parameters {
      function_scope = function_scope.declare(identifier: parameter.name, withValue: parameter.type)
    }

    let maybe_function_body = Parser.Statement.Compile(
      node: currentChild!, withContext: context.update(newInstances: function_scope))
    guard case .Ok((let function_body, _)) = maybe_function_body else {
      return .Error(maybe_function_body.error()!)
    }

    let function_declaration = FunctionDeclaration(
      named: function_name, ofType: function_type, withParameters: function_parameters,
      withBody: function_body)

    // Do not use the updated context returned by parsing the body
    // and do not use the function_scope, either.
    return .Ok(
      (
        function_declaration,
        context.update(
          newTypes: context.types.declare(
            identifier: function_name, withValue: function_declaration))
      ))
  }
}

struct StructDeclaration {}

extension StructDeclaration: CompilableDeclaration {
  static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(P4Type, CompilerContext)?> {

    let struct_declaration_node = node.child(at: 0)!
    var currentChildIdx = 0
    var currentChildIdxSafe = 1

    var currentChild: Node? = .none

    guard let node_type = struct_declaration_node.nodeType,
      node_type == "struct_declaration"
    else {
      return Result.Error(
        ErrorOnNode(node: struct_declaration_node, withError: "Did not find a struct declaration"))
    }

    if struct_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: struct_declaration_node, withError: "Missing elements in struct declaration"))
    }

    // Skip the keyword struct
    currentChildIdx += 1
    currentChildIdxSafe += 1
    if struct_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: struct_declaration_node, withError: "Missing elements in struct declaration"))
    }

    // The name of the struct type.
    currentChild = struct_declaration_node.child(at: currentChildIdx)
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
    if struct_declaration_node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: struct_declaration_node, withError: "Missing element of struct declaration"))
    }

    currentChild = struct_declaration_node.child(at: currentChildIdx)

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
    #SkipUnlessNodeType<Node, (P4Type, CompilerContext)?>(
      node: parser_node, type: "parserDeclaration")

    var current_context = context

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

    // Assume that the parameter list is empty!
    var parameter_list = ParameterList()

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

      switch Identifier.Compile(node: currentChild!, withContext: current_context) {
      case .Ok(let id): parser_name = id
      case .Error(let e):
        return .Error(e)
      }

      currentChildIdx += 1
      currentChildIdxSafe += 1
      if type_node!.childCount < currentChildIdxSafe {
        return .Error(
          ErrorOnNode(node: type_node!, withError: "Missing parser parameters"))
      }

      currentChild = type_node?.child(at: currentChildIdx)
      switch ParameterList.Compile(node: currentChild!, withContext: current_context) {
      case .Ok(let (parsed_parameter_list, updated_context)):
        parameter_list = parsed_parameter_list
        current_context = updated_context
      case .Error(let e):
        return .Error(e)
      }
    }

    // Now, let's put the parameters into scope.
    for parameter in parameter_list.parameters {
      current_context = current_context.update(
        newInstances: current_context.instances.declare(
          identifier: parameter.name, withValue: parameter.type))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if parser_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: parser_node, withError: "Missing parser declaration component"))
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
      withName: parser_name!, withParameters: parameter_list, node: currentChild!,
      withContext: current_context)
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
  }
}

func parameter_list_compiler(
  node: SwiftTreeSitter.Node, withContext context: CompilerContext
) -> Common.Result<(ParameterList, CompilerContext)> {

  var currentChildIdx = 0
  var currentChildIdxSafe = 1
  var currentChild: Node? = .none

  if node.text == ")" {
    // There are no parameters!
    return Result.Ok((ParameterList([]), context))
  }

  #RequireNodeType<Node, (ParameterList, CompilerContext)>(
    node: node, type: "parameter_list", nice_type_name: "Parameter List")

  var parameters: ParameterList = ParameterList([])

  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing parameter list component"))
  }

  currentChild = node.child(at: currentChildIdx)
  if currentChild?.nodeType == "parameter_list" {
    switch parameter_list_compiler(node: currentChild!, withContext: context) {
    case .Ok(let (ps, _)):
      parameters = ps
    case .Error(let e): return Result.Error(e)
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
  }

  // We may have moved nodes, check/reset currentChild.
  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing parameter list component"))
  }
  currentChild = node.child(at: currentChildIdx)

  // If this is a ')', we are done.
  if currentChild?.text == ")" {
    return Result.Ok((parameters, context))
  }

  // If this is a comma, we skip it!
  if currentChild?.text == "," {
    currentChildIdx += 1
    currentChildIdxSafe += 1
  }

  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing parameter list component"))
  }
  currentChild = node.child(at: currentChildIdx)

  // Otherwise, there should be one parameter left!
  switch Parameter.Compile(node: currentChild!, withContext: context) {
  case .Ok(let (vds, updated_context)):
    return Result.Ok((parameters.addParameter(vds), updated_context))
  case .Error(let e): return Result.Error(e)
  }
}

extension ParameterList: Compilable {
  public typealias T = ParameterList
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(ParameterList, CompilerContext)> {

    let parameter_node = node
    #RequireNodeType<Node, (ParameterList, CompilerContext)>(
      node: parameter_node, type: "parameters", nice_type_name: "Parameters")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1

    // Let's eat the '(' before we start ...
    if parameter_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: parameter_node, withError: "Missing '(' in parameter list component"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if parameter_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: parameter_node, withError: "Missing parameter list component"))
    }
    let currentChild = parameter_node.child(at: currentChildIdx)

    return parameter_list_compiler(node: currentChild!, withContext: context)
  }
}

extension Parameter: Compilable {
  public typealias T = Parameter
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(Parameter, CompilerContext)> {

    #RequireNodeType<Node, (EvaluatableStatement, CompilerContext)>(
      node: node, type: "parameter", nice_type_name: "parameter")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing parameter declaration component"))
    }

    currentChild = node.child(at: currentChildIdx)

    // Annotation?
    if currentChild!.nodeType == "annotations" {
      return .Error(
        ErrorOnNode(
          node: currentChild!,
          withError: "Annotations in parameter declarations are not yet handled"))
      // Will increment indexes here.
    }

    // Direction?
    if currentChild!.nodeType == "direction" {
      return .Error(
        ErrorOnNode(
          node: currentChild!, withError: "Direction in parameter declarations are not yet handled"
        ))
      // Will increment indexes here.
    }

    if currentChild!.nodeType != "typeRef" {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Did not find type name for parameter declaration"))
    }

    guard
      case .Ok(let parameter_type) = Types.CompileType(type: currentChild!, withContext: context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a P4 type from \(currentChild!.text!)"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing parameter declaration component"))
    }

    currentChild = node.child(at: currentChildIdx)
    if currentChild!.nodeType != "identifier" {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Did not find identifier for parameter statement"))
    }

    guard
      case .Ok(let parameter_name) = Identifier.Compile(node: currentChild!, withContext: context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parameter name from \(currentChild!.text!)"))
    }

    return Result.Ok(
      (
        Parameter(
          identifier: parameter_name, withType: parameter_type),
        context
      ))
  }
}
