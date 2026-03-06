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

import SwiftCompilerPlugin
import SwiftSyntax
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros

public func remove_embedded_quotes(_ from: String) -> String {
  return from.replacing("\"", with: [])
}

struct MacroError: Error, CustomStringConvertible {
    var message: String
    var description: String {
      get {
        return message 
      }
    }
    public init(withMessage _message: String) {
      message = _message
    }
}

public struct UseOkResult: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    guard let argument = node.arguments.first?.expression else {
      throw Require.Error.SyntaxError
    }

    return """
      {
          switch \(argument) {
              case Result.Ok(let __good): return __good
              case Result.Error(let __error):
                  print("Unexpected result: \\(__error)")
                  throw Require.Error.UnexpectedResult
          }
      }()
      """
  }
}

public struct UseErrorResult: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    guard let argument = node.arguments.first?.expression else {
      throw Require.Error.SyntaxError
    }

    return """
      {
          switch \(argument) {
              case Result.Error(let __error): return __error
              case Result.Ok(let __good):
                  print("Unexpected result: \\(__good)")
                  throw Require.Error.UnexpectedResult
          }
      }()
      """
  }
}

public struct Require {
  public enum Error: Swift.Error {
    case UnexpectedResult
    case SyntaxError
  }
}

public struct RequireResult: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    guard let argument = node.arguments.first?.expression else {
      throw Require.Error.SyntaxError
    }

    return """
      {
          switch \(argument) {
              case Result.Ok(_): return true
              case Result.Error(let __error):
                  print("Unexpected result: \\(__error)")
                  return false
          }
      }()
      """
  }
}

public struct RequireErrorResult: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    let arguments = node.arguments.indices
    let expected_error = node.arguments[arguments.startIndex].expression
    let error_producer = node.arguments[arguments.index(after: arguments.startIndex)].expression

    return ExprSyntax(
      """
      {
          let __expected_error = \(expected_error)
          let __actual_error = \(error_producer)
          if case Result.Error(__expected_error) = __actual_error {
              return true
          } else {
              print("Expected Error: \\(__expected_error) but got Error: \\(__actual_error)")
              return false
          }
      }()
      """)
  }
}

public struct RequireNodeType: CodeItemMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {
    let arguments = node.arguments.indices
    var arg_index = arguments.startIndex
    let node_to_check = node.arguments[arg_index].expression
    arg_index = arguments.index(after: arg_index)
    let expected_type = node.arguments[arg_index].expression
    arg_index = arguments.index(after: arg_index)
    let expected_type_nice_name = node.arguments[arg_index].expression

    let error_message = "Did not find " + remove_embedded_quotes(expected_type_nice_name.description)

    return [CodeBlockItemSyntax(
      """
      if \(node_to_check).nodeType != \(expected_type) {
        return Result.Error(
          ErrorOnNode(node: \(node_to_check), withError: "\(raw: error_message)"))
      }
      """)]
  }
}
public struct RequireNodesType: CodeItemMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {
    let arguments = node.arguments.indices
    var arg_index = arguments.startIndex

    let node_to_check = node.arguments[arg_index].expression

    arg_index = arguments.index(after: arg_index)
    guard let expected_types = node.arguments[arg_index].expression.as(ArrayExprSyntax.self) else {
      throw MacroError(withMessage: "Node(s) to check must be in an array")
    }

    arg_index = arguments.index(after: arg_index)
    guard
      let expected_type_nice_names = node.arguments[arg_index].expression.as(ArrayExprSyntax.self)
    else {
      throw MacroError(withMessage: "Node nice names must be in an array")
    }

    let error_message = "Did not find one of the expected types: " + expected_type_nice_names.elements.map(){ l in 
      remove_embedded_quotes("\(l.expression)")
    }.joined(separator: ",")


    let ifs = expected_types.elements.map(){ l in 
      "\(node_to_check).nodeType != \(l.expression)"
    }.joined(separator: " && ")

    return [CodeBlockItemSyntax(
      """
      if \(raw: ifs) {
        return Result.Error(
          ErrorOnNode(node: \(node_to_check), withError: "\(raw: error_message)"))
      }
      """)]
  }
}
public struct SkipUnlessNodeType: CodeItemMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [CodeBlockItemSyntax] {
    let arguments = node.arguments.indices
    var arg_index = arguments.startIndex
    let node_to_check = node.arguments[arg_index].expression
    arg_index = arguments.index(after: arg_index)
    let expected_type = node.arguments[arg_index].expression

    return [CodeBlockItemSyntax(
      """
      if \(node_to_check).nodeType != \(expected_type) {
        return Result.Ok(.none)
      }
      """)]
  }
}

@main
struct P4Macros: CompilerPlugin {
  var providingMacros: [Macro.Type] = [
    RequireResult.self, RequireErrorResult.self, UseOkResult.self, UseErrorResult.self, RequireNodeType.self, SkipUnlessNodeType.self, RequireNodesType.self
  ]
}
