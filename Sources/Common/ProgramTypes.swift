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

/// A P4 identifier
public class Identifier: CustomStringConvertible, Equatable, Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.name)
  }

  var name: String

  public init(name: String) {
    self.name = name
  }

  public var description: String {
    return "\(name)"
  }

  public static func == (lhs: Identifier, rhs: Identifier) -> Bool {
    return lhs.name == rhs.name
  }
}

/// A P4 identifier
public class TypedIdentifier: Identifier {
  public var parsed_type: P4Type

  public init(name: String, withType type: P4Type) {
    self.parsed_type = type
    super.init(name: name)
  }

  public override var description: String {
    return "\(name)"
  }
}

/// A P4 variable
public class Variable: TypedIdentifier {
  var constant: Bool
  var value: P4Value?

  public init(
    name: String, withType type: P4Type, withValue value: P4Value?, isConstant constant: Bool
  ) {
    self.constant = constant
    self.value = value
    super.init(name: name, withType: type)
  }

  public override var description: String {
    return "\(super.description) = \(value) \(constant ? "(constant)" : "")"
  }

  public var value_type: P4Value? {
    value
  }
}

/// A base for all instances of P4 types
open class P4ValueBase<T: P4Type>: P4Value {
  public init() {}

  public func type() -> P4Type {
    return T.create()
  }

  public func eq(rhs: P4Value) -> Bool {
    return false
  }

  public var description: String {
    "Value of \(self.type()) type"
  }

}

extension P4ValueBase: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> Result<P4Value> {
    return .Ok(self)
  }
}

/// The type for a P4 struct
public struct P4Struct: P4Type {

  public let name: String
  // The type of the struct created is always anonymous.
  public static func create() -> any P4Type {
    return P4Struct()
  }

  public init(withName name: String) {
    self.name = name
  }
  public init() {
    self.name = ""
  }
  public var description: String {
    return "Struct \(self.name)"
  }

  public func eq(rhs: P4Type) -> Bool {
    return if let struct_rhs = rhs as? P4Struct {
      struct_rhs.name == self.name
    } else {
      false
    }
  }
}

/// The field of a P4 struct
public struct P4StructField {
  public let name: TypedIdentifier
  public let type: P4Type

  public init(withName name: TypedIdentifier, withType type: P4Type) {
    self.name = name
    self.type = type
  }
}

/// An instance of a P4 struct
public class P4StructValue: P4ValueBase<P4Struct> {
  public let fields: [P4StructField]
  public init(withFields fields: [P4StructField]) {
    self.fields = fields
  }
}

/// A P4 boolean type
public struct P4Boolean: P4Type {

  public static func create() -> any P4Type {
    return P4Boolean()
  }
  public var description: String {
    return "Boolean"
  }
  public func eq(rhs: P4Type) -> Bool {
    return switch rhs {
    case is P4Boolean: true
    default: false
    }
  }
}

/// An instance of a P4 boolean
public class P4BooleanValue: P4ValueBase<P4Boolean> {
  let value: Bool

  public init(withValue value: Bool) {
    self.value = value
  }
  public override func eq(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return self.value == bool_rhs.value
  }

  public override var description: String {
    "\(self.value ? "true" : "false") of \(self.type()) type"
  }
}

/// A P4 int type
public struct P4Int: P4Type {
  public static func create() -> any P4Type {
    return P4Int()
  }
  public var description: String {
    return "Int"
  }
  public func eq(rhs: P4Type) -> Bool {
    return switch rhs {
    case is P4Int: true
    default: false
    }
  }
}

/// An instance of a P4 integer
public class P4IntValue: P4ValueBase<P4Int> {
  let value: Int
  public init(withValue value: Int) {
    self.value = value
  }
  public override func eq(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value == int_rhs.value
  }
  public override var description: String {
    "\(self.value) of \(self.type()) type"
  }
}

/// A P4 string type
public struct P4String: P4Type {

  public static func create() -> any P4Type {
    return P4String()
  }
  public var description: String {
    return "String"
  }
  public func eq(rhs: any P4Type) -> Bool {
    return switch rhs {
    case is P4String: true
    default: false
    }
  }
}
/// An instance of a P4 string
public class P4StringValue: P4ValueBase<P4String> {
  let value: String
  public init(withValue value: String) {
    self.value = value
  }
  public override func eq(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value == string_rhs.value
  }

  public override var description: String {
    "\(self.value) of \(self.type()) type"
  }
}

public class Packet {
  public init() {}
}
