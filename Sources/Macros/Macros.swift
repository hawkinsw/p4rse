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
import SwiftSyntaxMacros

public struct UseOkResult: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    guard let argument = node.argumentList.first?.expression else {
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

    guard let argument = node.argumentList.first?.expression else {
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

    let arguments = node.argumentList.indices
    let expected_error = node.argumentList[arguments.startIndex].expression
    let error_producer = node.argumentList[arguments.index(after: arguments.startIndex)].expression

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

@main
struct P4Macros: CompilerPlugin {
  var providingMacros: [Macro.Type] = [
    RequireResult.self, RequireErrorResult.self, UseOkResult.self,
  ]
}
