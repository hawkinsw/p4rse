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
  ) -> Result<(Declaration, CompilerContext)?> {

    let declaration_compilers: [String: CompilableDeclaration.Type] = [
      "function_declaration": FunctionDeclaration.self,
      "control_declaration": Control.self,
      "type_declaration": P4Struct.self,  // ASSUME: Type declarations are struct declarations.
      "extern_declaration": ExternDeclaration.self,
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
  ) -> Common.Result<(Declaration, CompilerContext)?> {
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

    var function_body: BlockStatement? = .none

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if currentChildIdxSafe <= function_declaration_node.childCount {
      currentChild = function_declaration_node.child(at: currentChildIdx)

      // Add the parameters into scope.
      var function_scope = context.instances.enter()
      for parameter in function_parameters.parameters {
        function_scope = function_scope.declare(
          identifier: parameter.name, withValue: parameter.type)
      }

      let maybe_function_body = BlockStatement.Compile(
        node: currentChild!,
        withContext: context.update(newInstances: function_scope).update(
          newExpectation: function_type))

      guard case .Ok((let parsed_function_body, _)) = maybe_function_body else {
        return .Error(maybe_function_body.error()!)
      }
      function_body = (parsed_function_body as! BlockStatement)
    } else {

      // If we are in an extern context, no body is okay!

      if !context.extern_context {
        return Result.Error(
          ErrorOnNode(
            node: function_declaration_node, withError: "Missing function declaration component"))
      }
    }

    let function_declaration = Declaration(
      TypedIdentifier(
        id: function_name,
        withType: P4Type(
          FunctionDeclaration(
            named: function_name, ofType: function_type, withParameters: function_parameters,
            withBody: function_body))))

    // Do not use the updated context returned by parsing the body
    // and do not use the function_scope, either.
    // And, do not update the context if we are compiling in an
    // extern context.
    return .Ok(
      (
        function_declaration,
        context.extern_context
          ? context
          : context.update(
            newTypes: context.types.declare(
              identifier: function_name, withValue: function_declaration.identifier.type.dataType())
          )
      ))
  }
}

extension P4Struct: CompilableDeclaration {
  static public func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(Declaration, CompilerContext)?> {

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
      let struc = Declaration(
        TypedIdentifier(
          id: struct_identifier,
          withType: P4Type(P4Struct(withName: struct_identifier, andFields: P4StructFields([])))))
      return Result.Ok(
        (
          struc,
          context.extern_context
            ? context
            : context.update(
              newTypes: context.types.declare(
                identifier: struct_identifier, withValue: struc.identifier.type.dataType()))
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

    let declared_struct = Declaration(
      TypedIdentifier(
        id: struct_identifier,
        withType: P4Type(
          P4Struct(
            withName: struct_identifier, andFields: P4StructFields(parsed_fields)))))
    return .Ok(
      (
        declared_struct,
        current_context.extern_context
          ? current_context
          : current_context.update(
            newTypes: current_context.types.declare(
              identifier: struct_identifier, withValue: declared_struct.identifier.type.dataType()))
      ))
  }
}

extension P4Lang.Parser: CompilableDeclaration {
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(Declaration, CompilerContext)?> {
    let parser_node = node
    #SkipUnlessNodeType<Node, (P4DataType, CompilerContext)?>(
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

    // TODO: Handle parser parameter lists.
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
      let parser_declaration = Declaration(
        TypedIdentifier(id: parser.name, withType: P4Type(parser)))
      // Create a new context with the name of the parser that was just compiled in scope.
      return .Ok(
        (
          parser_declaration,
          context.extern_context
            ? context
            : context.update(
              newInstances: updated_context.instances.declare(
                identifier: parser.name, withValue: parser_declaration.identifier.type))
        ))
    case Result.Error(let error): return .Error(error)
    }
  }
}

extension Control: CompilableDeclaration {
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(Declaration, CompilerContext)?> {

    #SkipUnlessNodeType<Node, (P4DataType, CompilerContext)?>(
      node: node, type: "control_declaration")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    var local_context = context

    // Skip control keyword
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing control declaration component"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing control declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    guard
      case .Ok(let control_name) = Identifier.Compile(
        node: currentChild!, withContext: local_context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a parameter name from \(currentChild!.text!)"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing control declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    let maybe_control_parameters = ParameterList.Compile(
      node: currentChild!, withContext: local_context)
    guard case .Ok((let control_parameters, let updated_context)) = maybe_control_parameters
    else {
      return .Error(maybe_control_parameters.error()!)
    }
    local_context = updated_context

    // Before continuing, make sure to put the parameters into context.
    var control_scope = local_context.instances.enter()
    for parameter in control_parameters.parameters {
      control_scope = control_scope.declare(
        identifier: parameter.name, withValue: parameter.type)
    }
    local_context = local_context.update(newInstances: control_scope)

    // Skip the '{'
    currentChildIdx += 2
    currentChildIdxSafe += 2
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing control declaration component"))
    }

    var actions: [Action] = Array()
    var tables: [Table] = Array()
    var apply: ApplyStatement? = .none

    //                                                       Because the final child
    //                                                       is the '}'.
    //                                                        \/\/
    for currentChildIdx in currentChildIdx..<(node.childCount - 1) {
      let currentChild = node.child(at: currentChildIdx)!
      if currentChild.nodeType == "action_declaration" {
        let maybe_action_declaration = Action.Compile(
          node: currentChild, withContext: local_context)
        guard
          case .Ok((let action_declaration, let updated_context)) = maybe_action_declaration
        else {
          return .Error(maybe_action_declaration.error()!)
        }
        actions.append(action_declaration)
        local_context = updated_context
      } else if currentChild.nodeType == "table_declaration" {
        let maybe_table_declaration = Table.Compile(
          node: currentChild, withContext: local_context)
        guard
          case .Ok((let table_declaration, let updated_context)) = maybe_table_declaration
        else {
          return .Error(maybe_table_declaration.error()!)
        }
        tables.append(table_declaration)
        local_context = updated_context
      } else if currentChild.nodeType == "apply_statement" {
        // When we see an apply, that is it for the actions and the tables.
        let maybe_apply_statement = ApplyStatement.Compile(
          node: currentChild, withContext: local_context)
        guard
          case .Ok((let apply_statement, let updated_context)) = maybe_apply_statement
        else {
          return .Error(maybe_apply_statement.error()!)
        }
        local_context = updated_context
        apply = (apply_statement as! ApplyStatement)

        // The apply is the last thing in a control declaration.
        break
      } else {
        return .Error(
          ErrorOnNode(node: currentChild, withError: "Uknown node type in control declaration"))
      }
    }

    // There should only be a single table!
    // TODO: Check the semantics here.
    if tables.count > 1 {
      // TODO: Make this error message better.
      // IDEA: Add a "compilation context" for the error message into the `CompilationContext`
      // that can be retrieved to make the error messages nicer.
      return .Error(
        ErrorOnNode(node: node, withError: "More than one table in control declaration"))
    }

    // Check to make sure that there is an apply.
    guard let apply = apply else {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing apply in control declaration"))
    }

    let declared_control =
      Declaration(
        TypedIdentifier(
          id: control_name,
          withType: P4Type(
            Control(
              named: control_name, withParameters: control_parameters, withTable: tables[0],
              withActions: Actions(withActions: actions), withApply: apply))))

    // Don't forget to add the newly declared Control to the instance that we were given
    // (and not the one that we entered to do the parsing of this Control).
    return .Ok(
      (
        declared_control,
        context.extern_context
          ? context
          : context.update(
            newInstances: context.instances.declare(
              identifier: control_name, withValue: declared_control.identifier.type))
      ))
  }
}

extension Action: Compilable {
  public typealias T = Action
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.Action, CompilerContext)> {
    #RequireNodeType<Node, (P4DataType, CompilerContext)>(
      node: node, type: "action_declaration", nice_type_name: "Action Declaration")

    var currentChildIdx = 1
    var currentChildIdxSafe = 2
    var currentChild: Node? = .none
    var current_context = context

    // Skip action keyword
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing action declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    guard
      case .Ok(let action_name) = Identifier.Compile(
        node: currentChild!, withContext: current_context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse an action name from \(currentChild!.text!)"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing action declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    let maybe_action_parameters = ParameterList.Compile(
      node: currentChild!, withContext: current_context)
    guard case .Ok((let action_parameters, let updated_context)) = maybe_action_parameters
    else {
      return .Error(maybe_action_parameters.error()!)
    }
    current_context = updated_context

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if node.childCount < currentChildIdxSafe {
      return Result.Error(
        ErrorOnNode(
          node: node, withError: "Missing action declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    // Add the parameters into scope.
    var function_scope = context.instances.enter()
    for parameter in action_parameters.parameters {
      function_scope = function_scope.declare(
        identifier: parameter.name, withValue: parameter.type)
    }

    let maybe_action_body = BlockStatement.Compile(
      node: currentChild!, withContext: context.update(newInstances: function_scope))
    guard case .Ok((let action_body, _)) = maybe_action_body else {
      return .Error(maybe_action_body.error()!)
    }

    // TODO: Actions cannot contain switches!

    return .Ok(
      (
        Action(
          named: action_name, withParameters: action_parameters,
          withBody: (action_body as! BlockStatement)),
        current_context
      ))
  }
}

extension TableKeyEntry: Compilable {
  public typealias T = TableKeyEntry
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.TableKeyEntry, CompilerContext)> {

    #RequireNodeType<Node, (P4DataType, CompilerContext)>(
      node: node, type: "table_key_entry", nice_type_name: "Table Key Entry")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1
    var currentChild: Node? = .none

    let current_context = context

    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing table key entry declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    let maybe_keyset_expression = KeysetExpression.compile(
      node: currentChild!, withContext: current_context)
    guard case .Ok(let keyset_expression) = maybe_keyset_expression else {
      return Result.Error(maybe_keyset_expression.error()!)
    }

    // Skip the ':'
    currentChildIdx += 2
    currentChildIdxSafe += 2
    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: node, withError: "Missing table key entry declaration component"))
    }
    currentChild = node.child(at: currentChildIdx)

    let maybe_match_type = TableKeyMatchType.Compile(
      node: currentChild!, withContext: current_context)
    guard case .Ok((let match_type, _)) = maybe_match_type else {
      return .Error(maybe_match_type.error()!)
    }

    return .Ok((TableKeyEntry(keyset_expression as! KeysetExpression, match_type), current_context))
  }
}

extension TableKeyMatchType: Compilable {
  public typealias T = TableKeyMatchType
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.TableKeyMatchType, CompilerContext)> {
    #RequireNodeType<Node, (TableKeyMatchType, CompilerContext)>(
      node: node, type: "table_key_match_type", nice_type_name: "Table Key Match Type")

    if node.text! == "exact" {
      return .Ok((TableKeyMatchType.Exact, context))
    }
    return .Error(ErrorOnNode(node: node, withError: "\(node.text!) is not a valid match type)"))
  }
}

extension TableKeys: Compilable {
  public typealias T = TableKeys
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.TableKeys, CompilerContext)> {
    #RequireNodeType<Node, (TableKeyMatchType, CompilerContext)>(
      node: node, type: "table_keys", nice_type_name: "Table Keys")

    // Skip the
    // keys = {
    // 0    1 2
    let currentChildIdx = 3
    let currentChildIdxSafe = 4
    var currentChild: Node? = .none
    var current_context = context

    if node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(
          node: node, withError: "Missing table keys declaration component in control declaration"))
    }
    currentChild = node.child(at: currentChildIdx)

    var entries: [TableKeyEntry] = Array()
    var errors: [Error] = Array()

    currentChild!.enumerateNamedChildren { entry in
      switch TableKeyEntry.Compile(node: currentChild!, withContext: current_context) {
      case .Ok((let keyset_expression, let updated_context)):
        entries.append(keyset_expression)
        current_context = updated_context
      case .Error(let e): errors.append(e)
      }
    }

    if !errors.isEmpty {
      return .Error(
        Error(
          withMessage: "Error(s) parsing table key: "
            + (errors.map { error in
              return "\(error.msg)"
            }.joined(separator: ";"))))
    }

    return .Ok((TableKeys(withEntries: entries), current_context))
  }
}

extension TablePropertyList: Compilable {
  public typealias T = TablePropertyList
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.TablePropertyList, CompilerContext)> {

    #RequireNodeType<Node, (P4DataType, CompilerContext)>(
      node: node, type: "table_property_list", nice_type_name: "Table Property List")

    var current_context = context

    var keys: [TableKeys] = Array()
    var _: [Action] = Array()  // Actions are not yet supported
    var errors: [Error] = Array()

    node.enumerateNamedChildren { child in
      if child.nodeType == "table_keys" {
        switch TableKeys.Compile(node: child, withContext: current_context) {
        case .Ok((let table_key, let updated_context)):
          current_context = updated_context
          keys.append(table_key)
        case .Error(let e): errors.append(e)
        }
      } else if child.nodeType == "table_actions" {
        errors.append(
          ErrorOnNode(
            node: child, withError: "Actions in table property lists are not yet supported"))
      } else {
        errors.append(
          ErrorOnNode(node: child, withError: "Uknown node type in control declaration"))
      }
    }

    if !errors.isEmpty {
      return .Error(
        Error(
          withMessage: "Error(s) parsing property list: "
            + (errors.map { error in
              return "\(error.msg)"
            }.joined(separator: ";"))))
    }

    // There should be only one table keys!
    if keys.count > 1 {
      // Todo: Make this error message better.
      return .Error(
        ErrorOnNode(node: node, withError: "More than one key set in table property list"))
    }

    return .Ok((TablePropertyList(withActions: TableActions(), withKeys: keys[0]), current_context))

  }
}

extension Table: Compilable {
  public typealias T = Table
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(P4Lang.Table, CompilerContext)> {

    let table_declaration_node = node
    #RequireNodeType<Node, (P4DataType, CompilerContext)>(
      node: table_declaration_node, type: "table_declaration", nice_type_name: "Table Declaration")

    var currentChildIdx = 1
    var currentChildIdxSafe = 2
    var currentChild: Node? = .none

    let current_context = context

    if table_declaration_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: table_declaration_node, withError: "Missing table declaration component"))
    }
    currentChild = table_declaration_node.child(at: currentChildIdx)

    guard
      case .Ok(let table_name) = Identifier.Compile(
        node: currentChild!, withContext: current_context)
    else {
      return Result.Error(
        Error(withMessage: "Could not parse a table name from \(currentChild!.text!)"))
    }

    // Skip the '{'
    currentChildIdx += 2
    currentChildIdxSafe += 2
    if table_declaration_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: table_declaration_node, withError: "Missing table declaration component"))
    }
    currentChild = table_declaration_node.child(at: currentChildIdx)

    let maybe_table_property_list = TablePropertyList.Compile(
      node: currentChild!, withContext: current_context)
    guard case .Ok((let table_property_list, _)) = maybe_table_property_list else {
      return Result.Error(maybe_table_property_list.error()!)
    }

    return .Ok(
      (Table(withName: table_name, withPropertyList: table_property_list), current_context))
  }
}

extension ExternDeclaration: CompilableDeclaration {
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(Declaration, CompilerContext)?> {
    let extern_declaration_node = node
    #RequireNodeType<Node, (Declaration, CompilerContext)>(
      node: extern_declaration_node, type: "extern_declaration",
      nice_type_name: "Extern Declaration")
    let declaration_node = extern_declaration_node.child(at: 1)!
    #RequireNodeType<Node, (Declaration, CompilerContext)>(
      node: declaration_node, type: "declaration", nice_type_name: "Declaration")
    let declarationed_node = declaration_node.child(at: 0)!

    let maybe_declared = Declaration.Compile(
      node: declarationed_node, withContext: context.update(newExtern: true))

    guard case .Ok(let maybe_declared) = maybe_declared else {
      return .Error(maybe_declared.error()!)
    }

    guard case .some((let declared, _)) = maybe_declared else {
      return .Ok(.none)
    }

    // Before we are okay with this declaration, it must already be registered as an extern
    // with the matching "stuff".

    let found_ffi = context.ffis.first { ffi in
      ffi.type().dataType().eq(rhs: declared.identifier.type.dataType())
    }

    guard let found_ffi = found_ffi else {
      return .Error(
        ErrorOnNode(
          node: declarationed_node,
          withError:
            "Could not find a foreign function that matches the extern declaration (\(declared))"))
    }

    let extern_declaration = Declaration(extern: declared, ffi: found_ffi)

    return .Ok(
      (
        extern_declaration,
        context.update(
          newExterns: context.externs.declare(
            identifier: declared.identifier, withValue: extern_declaration))
      ))
  }
}
