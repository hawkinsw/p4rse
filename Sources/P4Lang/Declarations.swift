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

public struct Declaration: P4DataType {
  public let identifier: TypedIdentifier
  public let extern: Bool
  public let ffi: P4FFI?

  public init(_ id: TypedIdentifier) {
    identifier = id
    ffi = .none
    self.extern = false
  }

  public init(extern: Declaration, ffi: P4FFI) {
    identifier = extern.identifier
    self.ffi = ffi
    self.extern = true
  }

  public func eq(rhs: any Common.P4DataType) -> Bool {
    return switch rhs {
    case let rrhs as Declaration:
      self.identifier.type.dataType().eq(rhs: rrhs.identifier.type.dataType())
        && self.extern == rrhs.extern
    default: false
    }
  }

  public func def() -> any Common.P4DataValue {
    // TODO: Is a default of the extern'd type the right way to go?
    return self.identifier.type.dataType().def()
  }

  public func type() -> any Common.P4DataType {
    return self
  }
  public var description: String {
    return "Extern \(self.identifier)"
  }
}

public struct ExternDeclaration {}

public struct FunctionDeclaration: P4DataType, P4DataValue {
  public func type() -> any Common.P4DataType {
    return self
  }

  public func eq(rhs: any Common.P4DataType) -> Bool {
    print("Checking a type: me: \(self) vs them: \(rhs)!")
    switch rhs {
    case let frhs as FunctionDeclaration:
      return frhs.tipe.eq(self.tipe) && frhs.params == self.params
    default: return false
    }
  }

  public func eq(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.eq(rhs: frhs as P4DataType)
    default: return false
    }
  }

  public func lt(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name < frhs.name
    default: return false
    }
  }

  public func lte(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name <= frhs.name
    default: return false
    }

  }

  public func gt(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name > frhs.name
    default: return false
    }
  }

  public func gte(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let frhs as FunctionDeclaration: return self.name >= frhs.name
    default: return false
    }
  }

  public func def() -> any Common.P4DataValue {
    return FunctionDeclaration(
      named: Identifier(name: ""), ofType: P4Type(P4Boolean()),
      withParameters: ParameterList([]),
      withBody: .none)
  }

  public var description: String {
    return "Function named \(self.name) that returns \(self.tipe) with parameters \(self.params)"
  }

  public var body: BlockStatement?
  public var params: ParameterList
  public var name: Identifier
  public var tipe: P4Type

  public init(
    named name: Identifier, ofType type: P4Type, withParameters parameters: ParameterList,
    withBody body: BlockStatement?
  ) {
    self.name = name
    self.tipe = type
    self.params = parameters
    self.body = body
  }
}
