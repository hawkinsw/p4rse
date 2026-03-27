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
public class Identifier: CustomStringConvertible, Comparable, Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.name)
  }

  var name: String

  public init(name: String) {
    self.name = name
  }

  public init(id: Identifier) {
    self.name = id.name
  }

  public var description: String {
    return "\(name)"
  }

  public static func == (lhs: Identifier, rhs: Identifier) -> Bool {
    return lhs.name == rhs.name
  }

  public static func < (lhs: Identifier, rhs: Identifier) -> Bool {
    return lhs.name < rhs.name
  }
}

/// A P4 identifier
public class TypedIdentifier: Identifier {
  public var type: P4Type

  public init(name: String, withType type: P4Type) {
    self.type = type
    super.init(name: name)
  }

  public init(id: Identifier, withType type: P4Type) {
    self.type = type
    super.init(id: id)
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
    return
      "\(super.description) = \(value?.description ?? "Missing Value") \(constant ? "(constant)" : "")"
  }

  public var value_type: P4Value? {
    value
  }
}

public typealias P4StructFieldIdentifier = TypedIdentifier

public struct P4StructFields: Sequence, CustomStringConvertible, Equatable {
  public typealias Element = [P4StructFieldIdentifier].Iterator.Element

  public typealias Iterator = [P4StructFieldIdentifier].Iterator

  public func makeIterator() -> Iterator {
    return self.fields.makeIterator()
  }

  let fields: [P4StructFieldIdentifier]

  public init(_ fields: [P4StructFieldIdentifier]) {
    self.fields = fields
  }

  public var description: String {
    return self.fields.map { field in
      field.name
    }.joined(separator: ",")
  }

  public func get_field_type(_ field: Identifier) -> P4Type? {
    if let found_field = self.fields.makeIterator().first(where: { current in
      return current.name == field.name
    }) {
      return found_field.type
    }
    return .none
  }

  public func count() -> Int {
    return self.fields.count
  }

  public func describe_with_values(values: [P4Value?]) -> String {
    assert(values.count == self.count())
    return zip(self.fields, values).map { (field, value) in
      let actual_value =
        if let v = value {
          v.description
        } else {
          "Unset"
        }
      return String("\(field): \(actual_value)")
    }.joined(separator: "; ")
  }
}

/// The type for a P4 struct
public struct P4Struct: P4Type {

  public let name: Identifier
  public let fields: P4StructFields

  public init(withName name: Identifier, andFields fields: P4StructFields) {
    self.name = name
    self.fields = fields
  }

  public init() {
    self.name = Identifier(name: "")
    self.fields = P4StructFields([])
  }

  public var description: String {
    return "Struct \(self.name) with fields: \(self.fields)"
  }

  public func eq(rhs: P4Type) -> Bool {
    return if let struct_rhs = rhs as? P4Struct {
      struct_rhs.name == self.name
    } else {
      false
    }
  }

  public func def() -> any P4Value {
    return P4StructValue(withType: self)
  }
}

/// An instance of a P4 struct
public class P4StructValue: P4Value {
  public func type() -> any P4Type {
    return self.stype
  }

  func bin_op_impl(lhs: P4StructValue, rhs: P4StructValue, op: (P4Value?, P4Value?) -> Bool) -> Bool
  {
    if lhs.stype.fields.count() != rhs.stype.fields.count() {
      // If there are a different number of fields, then we cannot
      // possibly be equal.
      return false
    }

    // Note: Because the number of values _always_ matches the number of fields, there
    // is no need to check there!

    for xx in zip(zip(lhs.stype.fields, lhs.values), zip(rhs.stype.fields, rhs.values)) {
      let left = xx.0
      let right = xx.1

      let left_field = left.0
      let left_value = left.1

      let right_field = right.0
      let right_value = right.1

      // If the field names do not match, then there is a problem.
      if left_field != right_field {
        return false
      }

      // Now that we know that the field names match, do the values match?
      if !op(left_value, right_value) {
        return false
      }
    }
    return true
  }

  public func eq(rhs: any P4Value) -> Bool {
    guard let rrhs = rhs as? P4StructValue else {
      return false
    }
    return bin_op_impl(lhs: self, rhs: rrhs) { ilhs, irhs in
      if ilhs == nil && irhs == nil {
        return true
      }
      guard let llhs = ilhs,
        let rrhs = irhs
      else {
        return false
      }
      return llhs.eq(rhs: rrhs)
    }
  }
  public func lt(rhs: any P4Value) -> Bool {
    guard let rrhs = rhs as? P4StructValue else {
      return false
    }
    return bin_op_impl(lhs: self, rhs: rrhs) { ilhs, irhs in
      if ilhs == nil && irhs == nil {
        return true
      }
      guard let llhs = ilhs,
        let rrhs = irhs
      else {
        return false
      }
      return llhs.lt(rhs: rrhs)
    }
  }
  public func lte(rhs: any P4Value) -> Bool {
    guard let rrhs = rhs as? P4StructValue else {
      return false
    }
    return bin_op_impl(lhs: self, rhs: rrhs) { ilhs, irhs in
      if ilhs == nil && irhs == nil {
        return true
      }
      guard let llhs = ilhs,
        let rrhs = irhs
      else {
        return false
      }
      return llhs.lte(rhs: rrhs)
    }
  }
  public func gt(rhs: any P4Value) -> Bool {
    guard let rrhs = rhs as? P4StructValue else {
      return false
    }
    return bin_op_impl(lhs: self, rhs: rrhs) { ilhs, irhs in
      if ilhs == nil && irhs == nil {
        return true
      }
      guard let llhs = ilhs,
        let rrhs = irhs
      else {
        return false
      }
      return llhs.gt(rhs: rrhs)
    }
  }

  public func gte(rhs: any P4Value) -> Bool {
    guard let rrhs = rhs as? P4StructValue else {
      return false
    }
    return bin_op_impl(lhs: self, rhs: rrhs) { ilhs, irhs in
      if ilhs == nil && irhs == nil {
        return true
      }
      guard let llhs = ilhs,
        let rrhs = irhs
      else {
        return false
      }
      return llhs.gte(rhs: rrhs)
    }
  }

  public var description: String {
    return "Struct: \(self.stype.fields.describe_with_values(values: self.values))"
  }

  public let stype: P4Struct
  public let values: [P4Value?]

  public convenience init(withType type: P4Struct) {
    self.init(withType: type, andInitializers: [])
  }

  public init(withType type: P4Struct, andInitializers initializers: [P4Value?]) {
    var values: [P4Value?] = Array(repeating: .none, count: type.fields.count())

    for i in 0..<initializers.count {
      values[i] = initializers[i]
    }

    self.values = values
    self.stype = type
  }

  public func get(field: P4StructFieldIdentifier) -> P4Value? {
    for field_idx in 0..<stype.fields.count() {
      if stype.fields.fields[field_idx] == field {
        return values[field_idx]
      }
    }
    return .none
  }

  public func set(field: P4StructFieldIdentifier, to: P4Value) -> Result<P4StructValue> {
    var updated_values = self.values

    for field_idx in 0..<stype.fields.count() {
      if stype.fields.fields[field_idx] == field {
        if !stype.fields.fields[field_idx].type.eq(rhs: to.type()) {
          return .Error(
            Error(
              withMessage:
                "Cannot assign value with type \(to.type()) to field with type \(stype.fields.fields[field_idx].type))"
            ))
        }
        updated_values[field_idx] = to
        break
      }
    }

    return .Ok(P4StructValue(withType: self.stype, andInitializers: updated_values))
  }

}

/// A P4 boolean type
public struct P4Boolean: P4Type {
  public init() {}
  public var description: String {
    return "Boolean"
  }
  public func eq(rhs: P4Type) -> Bool {
    return switch rhs {
    case is P4Boolean: true
    default: false
    }
  }
  public func def() -> any P4Value {
    return P4BooleanValue(withValue: false)
  }
}

/// An instance of a P4 boolean
public class P4BooleanValue: P4Value {
  public func type() -> any P4Type {
    return P4Boolean()
  }

  let value: Bool

  public func access() -> Bool {
    return self.value
  }

  public init(withValue value: Bool) {
    self.value = value
  }
  public func eq(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return self.value == bool_rhs.value
  }

  public func lt(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return (self.value ? 1 : 0) < (bool_rhs.value ? 1 : 0)
  }

  public func lte(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return (self.value ? 1 : 0) <= (bool_rhs.value ? 1 : 0)
  }

  public func gt(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return (self.value ? 1 : 0) > (bool_rhs.value ? 1 : 0)
  }

  public func gte(rhs: P4Value) -> Bool {
    guard let bool_rhs = rhs as? P4BooleanValue else {
      return false
    }
    return (self.value ? 1 : 0) >= (bool_rhs.value ? 1 : 0)
  }

  public var description: String {
    "\(self.value ? "true" : "false") of \(self.type()) type"
  }
}

/// A P4 int type
public struct P4Int: P4Type {
  public init() {}

  public var description: String {
    return "Int"
  }
  public func eq(rhs: P4Type) -> Bool {
    return switch rhs {
    case is P4Int: true
    default: false
    }
  }
  public func def() -> any P4Value {
    return P4IntValue(withValue: 0)
  }
}

/// An instance of a P4 integer
public class P4IntValue: P4Value {
  public func type() -> any P4Type {
    return P4Int()
  }

  let value: Int
  public init(withValue value: Int) {
    self.value = value
  }

  public func access() -> Int {
    return self.value
  }

  public func eq(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value == int_rhs.value
  }

  public func lt(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value < int_rhs.value
  }

  public func lte(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value <= int_rhs.value
  }

  public func gt(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value > int_rhs.value
  }

  public func gte(rhs: P4Value) -> Bool {
    guard let int_rhs = rhs as? P4IntValue else {
      return false
    }
    return self.value >= int_rhs.value
  }

  public var description: String {
    "\(self.value) of \(self.type()) type"
  }
}

/// A P4 string type
public struct P4String: P4Type {
  public init() {}
  public var description: String {
    return "String"
  }
  public func eq(rhs: any P4Type) -> Bool {
    return switch rhs {
    case is P4String: true
    default: false
    }
  }
  public func def() -> any P4Value {
    return P4StringValue(withValue: "")
  }
}
/// An instance of a P4 string
public class P4StringValue: P4Value {
  public func type() -> any P4Type {
    return P4String()
  }

  let value: String
  public init(withValue value: String) {
    self.value = value
  }
  public func eq(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value == string_rhs.value
  }

  public func lt(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value < string_rhs.value
  }

  public func lte(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value <= string_rhs.value
  }

  public func gt(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value > string_rhs.value
  }

  public func gte(rhs: P4Value) -> Bool {
    guard let string_rhs = rhs as? P4StringValue else {
      return false
    }
    return self.value >= string_rhs.value
  }

  public var description: String {
    "\(self.value) of \(self.type()) type"
  }
}

public class Packet {
  public init() {}
}

/// A P4 array type
public struct P4Array: P4Type {
  public init(withValueType vtype: P4Type) {
    self.vtype = vtype
  }

  let vtype: P4Type

  public func value_type() -> P4Type {
    return self.vtype
  }

  public var description: String {
    return "Array"
  }

  public func eq(rhs: any P4Type) -> Bool {
    return switch rhs {
    case is P4Array: true
    default: false
    }
  }

  public func def() -> P4Value {
    return P4ArrayValue(withType: self, withValue: [])
  }
}

/// An instance of a P4 array
public class P4ArrayValue: P4Value {
  public func type() -> any P4Type {
    return P4Array(withValueType: self.vtype)
  }

  let value: [P4Value]
  let vtype: P4Type

  public init(withType type: P4Type, withValue value: [P4Value]) {
    self.vtype = type
    self.value = value
  }

  public func access(_ index: Int) -> P4Value {
    return self.value[index]
  }

  public func set(index: Int, to: P4Value) -> Result<P4ArrayValue> {
    // TODO: Check for OOB
    var updated_values = self.value
    updated_values[index] = to
    return Result.Ok(P4ArrayValue(withType: self.vtype, withValue: updated_values))
  }

  public func eq(rhs: P4Value) -> Bool {
    guard rhs as? P4ArrayValue != nil else {
      return false
    }
    // TODO!!
    return true
  }

  public func lt(rhs: P4Value) -> Bool {
    guard rhs as? P4ArrayValue != nil else {
      return false
    }
    // TODO!!
    return true
  }

  public func lte(rhs: P4Value) -> Bool {
    guard rhs as? P4ArrayValue != nil else {
      return false
    }
    // TODO!!
    return true
  }

  public func gt(rhs: P4Value) -> Bool {
    guard rhs as? P4ArrayValue != nil else {
      return false
    }
    // TODO!!
    return true
  }

  public func gte(rhs: P4Value) -> Bool {
    guard rhs as? P4ArrayValue != nil else {
      return false
    }
    // TODO!!
    return true
  }

  public var description: String {
    "\(self.value) of \(self.type()) type"
  }
}

/// A P4 set type
public struct P4Set: P4Type {
  public init(withSetType stype: P4Type) {
    self.stype = stype
  }

  let stype: P4Type

  public func set_type() -> P4Type {
    return self.stype
  }

  public var description: String {
    return "P4Set"
  }

  public func eq(rhs: any P4Type) -> Bool {
    return switch rhs {
    // If rhs is a set type, then they are the same if the types in the set are the same.
    case let srhs as P4Set: srhs.eq(rhs: self.stype)
    default: false
    }
  }

  public func def() -> P4Value {
    return P4ArrayValue(withType: self, withValue: [])
  }
}

/// An instance of a P4 set
public class P4SetValue: P4Value {
  public func type() -> any P4Type {
    return P4Set(withSetType: self.stype)
  }

  let value: P4Value
  let stype: P4Type

  public init(withType type: P4Type, withValue value: P4Value) {
    self.stype = type
    self.value = value
  }

  public func access() -> P4Value {
    return self.value
  }

  public func eq(rhs: P4Value) -> Bool {
    guard let rrhs = rhs as? P4SetValue else {
      return false
    }
    return rrhs.access().eq(rhs: self.value)
  }
  public func lt(rhs: P4Value) -> Bool {
    guard let rrhs = rhs as? P4SetValue else {
      return false
    }
    return rrhs.access().lt(rhs: self.value)
  }
  public func lte(rhs: P4Value) -> Bool {
    guard let rrhs = rhs as? P4SetValue else {
      return false
    }
    return rrhs.access().lte(rhs: self.value)
  }
  public func gt(rhs: P4Value) -> Bool {
    guard let rrhs = rhs as? P4SetValue else {
      return false
    }
    return rrhs.access().gt(rhs: self.value)
  }
  public func gte(rhs: P4Value) -> Bool {
    guard let rrhs = rhs as? P4SetValue else {
      return false
    }
    return rrhs.access().gte(rhs: self.value)
  }

  public var description: String {
    "P4Set with \(self.value) of \(self.type()) type"
  }
}

public class P4SetDefaultValue: P4Value {
  public func type() -> any P4Type {
    return P4Set(withSetType: self.stype)
  }

  let stype: P4Type

  public init(withType type: P4Type) {
    self.stype = type
  }

  // Snarf up everything!
  public func eq(rhs: P4Value) -> Bool {
    return true
  }
  public func lt(rhs: P4Value) -> Bool {
    return true
  }
  public func lte(rhs: P4Value) -> Bool {
    return true
  }
  public func gt(rhs: P4Value) -> Bool {
    return true
  }
  public func gte(rhs: P4Value) -> Bool {
    return true
  }

  public var description: String {
    "Default of P4Set of \(self.type()) type"
  }
}
