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

public struct Declaration {}

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

public struct FunctionDeclaration: P4Type, P4Value {
  public func type() -> any Common.P4Type {
    return self
  }

  public func eq(rhs: any Common.P4Type) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration:
      return frhs.tipe.eq(rhs: self.tipe) && frhs.params == self.params
    default: return false
    }
  }

  public func eq(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.eq(rhs: frhs as P4Type)
    default: return false
    }
  }

  public func lt(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name < frhs.name
    default: return false
    }
  }

  public func lte(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name <= frhs.name
    default: return false
    }

  }

  public func gt(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name > frhs.name
    default: return false
    }
  }

  public func gte(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name >= frhs.name
    default: return false
    }
  }

  public func def() -> any Common.P4Value {
    return FunctionDeclaration(
      named: Identifier(name: ""), ofType: P4Boolean(), withParameters: ParameterList([]),
      withBody: .none)
  }

  public var description: String {
    return "Function named \(self.name) that returns \(self.tipe) with parameters \(self.params)"
  }

  public var body: EvaluatableStatement?
  public var params: ParameterList
  public var name: Identifier
  public var tipe: P4Type

  public init(
    named name: Identifier, ofType type: P4Type, withParameters parameters: ParameterList,
    withBody body: EvaluatableStatement?
  ) {
    self.name = name
    self.tipe = type
    self.params = parameters
    self.body = body
  }
}
