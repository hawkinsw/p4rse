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

extension Direction: Compilable {
  public typealias T = Direction
  public static func Compile(
    node: Node, withContext context: CompilerContext
  ) -> Result<(Direction, CompilerContext)> {
    let direction_node = node
    #RequireNodeType<Node, (Direction, CompilerContext)>(
      node: direction_node, type: "direction", nice_type_name: "direction")
    let directions = [
      "in": Direction.In,
      "out": Direction.Out,
      "inout": Direction.InOut,
    ]

    guard let parsed_direction = directions[direction_node.text!] else {
      return .Error(
        ErrorOnNode(
          node: direction_node, withError: "\(direction_node.text!) is not a valid direction"))
    }

    return .Ok((parsed_direction, context))
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
    currentChild = node.child(at: currentChildIdx)

    var direction: Direction? = .none
    // Direction?
    if currentChild!.nodeType == "direction" {

      let maybe_parsed_direction = Direction.Compile(node: currentChild!, withContext: context)
      guard case .Ok((let parsed_direction, _)) = maybe_parsed_direction else {
        return .Error(maybe_parsed_direction.error()!)
      }
      direction = parsed_direction

      currentChildIdx += 1
      currentChildIdxSafe += 1
    }
    currentChild = node.child(at: currentChildIdx)

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
          identifier: parameter_name,
          withType: direction != nil
            ? parameter_type.update(addAttribute: P4TypeAttribute.Direction(direction!))
            : parameter_type),
        context
      ))
  }
}

func argument_list_compiler(
  node: SwiftTreeSitter.Node, withContext context: CompilerContext
) -> Common.Result<(ArgumentList, CompilerContext)> {

  var currentChildIdx = 0
  var currentChildIdxSafe = 1
  var currentChild: Node? = .none

  if node.text == ")" {
    // There are no arguments!
    return Result.Ok((ArgumentList([]), context))
  }

  #RequireNodeType<Node, (ArgumentList, CompilerContext)>(
    node: node, type: "argument_list", nice_type_name: "argument List")

  var arguments: ArgumentList = ArgumentList([])

  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing argument list component"))
  }

  currentChild = node.child(at: currentChildIdx)
  if currentChild?.nodeType == "argument_list" {
    switch argument_list_compiler(node: currentChild!, withContext: context) {
    case .Ok(let (ps, _)):
      arguments = ps
    case .Error(let e): return Result.Error(e)
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
  }

  // We may have moved nodes, check/reset currentChild.
  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing argument list component"))
  }
  currentChild = node.child(at: currentChildIdx)

  // If this is a ')', we are done.
  if currentChild?.text == ")" {
    return Result.Ok((arguments, context))
  }

  // If this is a comma, we skip it!
  if currentChild?.text == "," {
    currentChildIdx += 1
    currentChildIdxSafe += 1
  }

  if node.childCount < currentChildIdxSafe {
    return Result.Error(
      ErrorOnNode(node: node, withError: "Missing argument list component"))
  }
  currentChild = node.child(at: currentChildIdx)

  // Otherwise, there should be one argument left!
  switch Argument.Compile(node: currentChild!, withContext: context) {
  case .Ok(let (ce, updated_context)):
    return Result.Ok(
      (arguments.addArgument(Argument(ce, atIndex: arguments.count() + 1)), updated_context))
  case .Error(let e): return Result.Error(e)
  }
}

extension ArgumentList: Compilable {
  public typealias T = ArgumentList
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(ArgumentList, CompilerContext)> {

    let argument_node = node
    #RequireNodeType<Node, (ArgumentList, CompilerContext)>(
      node: argument_node, type: "arguments", nice_type_name: "arguments")

    var currentChildIdx = 0
    var currentChildIdxSafe = 1

    // Let's eat the '(' before we start ...
    if argument_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: argument_node, withError: "Missing '(' in argument list component"))
    }

    currentChildIdx += 1
    currentChildIdxSafe += 1
    if argument_node.childCount < currentChildIdxSafe {
      return .Error(
        ErrorOnNode(node: argument_node, withError: "Missing argument list component"))
    }
    let currentChild = argument_node.child(at: currentChildIdx)

    return argument_list_compiler(node: currentChild!, withContext: context)
  }
}

extension Argument: Compilable {
  public typealias T = EvaluatableExpression
  public static func Compile(
    node: SwiftTreeSitter.Node, withContext context: CompilerContext
  ) -> Common.Result<(EvaluatableExpression, CompilerContext)> {
    let argument_node = node
    #RequireNodeType<Node, (EvaluatableExpression, CompilerContext)>(
      node: argument_node, type: "argument", nice_type_name: "argument")

    let expression_node = node.child(at: 0)!

    return switch Expression.Compile(node: expression_node, withContext: context) {
    case .Ok(let compiled_expression): .Ok((compiled_expression, context))
    case .Error(let e): .Error(e)
    }
  }
}
