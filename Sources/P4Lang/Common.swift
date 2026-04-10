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

public struct Parameter: CustomStringConvertible, Equatable {
  public static func == (lhs: Parameter, rhs: Parameter) -> Bool {
    return lhs.name == rhs.name && lhs.type.eq(rhs: rhs.type)
  }

  public var name: Identifier
  public var type: P4Type

  public init(
    identifier: Identifier, withType type: P4Type
  ) {
    self.name = identifier
    self.type = type
  }

  public var description: String {
    return "Parameter: \(self.name) with type \(self.type)"
  }
}

public struct ParameterList: CustomStringConvertible, Equatable {
  public static func == (lhs: ParameterList, rhs: ParameterList) -> Bool {
    if lhs.parameters.count != rhs.parameters.count {
      return false
    }

    return 0
      == zip(lhs.parameters, rhs.parameters).count { (lparam, rparam) in
        return lparam != rparam
      }
  }

  public var parameters: [Parameter]

  public init() {
    self.parameters = Array()
  }

  public init(_ parameters: [Parameter]) {
    self.parameters = parameters
  }

  public func addParameter(_ parameter: Parameter) -> ParameterList {
    return ParameterList(self.parameters + [parameter])
  }

  public var description: String {
    let parameters = self.parameters.map { parameter in
      parameter.description
    }.joined(separator: ";")
    return "Parameter list: \(parameters)"
  }
}

public struct ArgumentList {
  public let arguments: [Argument]

  public init(_ arguments: [Argument]) {
    self.arguments = arguments
  }

  public func compatible(_ parameters: ParameterList) -> Result<()> {
    if self.arguments.count != parameters.parameters.count {
      return .Error(
        Error(
          withMessage:
            "\(self.arguments.count) arguments found but \(parameters.parameters.count) required"))
    }

    for (arg, param) in zip(self.arguments, parameters.parameters) {
      let arg_index = arg.index
      let arg_type = arg.argument.type()
      if !arg_type.eq(rhs: param.type) {
        return .Error(
          Error(
            withMessage:
              "Argument \(arg_index)'s type (\(arg_type)) is incompatible with the parameter type (\(param.type))"
          ))
      }
    }
    return .Ok(())
  }

  public func addArgument(_ argument: Argument) -> ArgumentList {
    return ArgumentList(self.arguments + [argument])
  }

  public func count() -> Int {
    return self.arguments.count
  }
}

public struct Argument {
  public let index: Int
  public let argument: EvaluatableExpression

  public init(_ argument: EvaluatableExpression, atIndex index: Int) {
    self.argument = argument
    self.index = index
  }
}
