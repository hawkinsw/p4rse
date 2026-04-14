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

public enum Direction: Equatable, CustomStringConvertible {
  case In
  case Out
  case InOut

  public var description: String {
    return switch self {
    case Direction.In: "In"
    case Direction.Out: "Out"
    case Direction.InOut: "InOut"
    }
  }

  /// Compare two optional ``Direction``s
  static public func eqopt(_ lhs: Direction?, _ rhs: Direction?) -> Bool {
    // If both are empty, they are the same.
    if lhs == .none && rhs == .none {
      return true
    }

    // If one is empty, they are different
    if lhs == .none || rhs == .none {
      return false
    }

    // Both have values -- compare them natively.
    return lhs! == rhs!
  }
}

public enum P4TypeAttribute: Equatable {
  case Direction(Direction)
  case Readonly  // Not yet used -- here to keep Swift warnings at bay
}

public struct P4TypeAttributes: CustomStringConvertible {
  let _attributes: [P4TypeAttribute]

  public init(_ attributes: [P4TypeAttribute]) {
    self._attributes = attributes
  }

  public func direction() -> Direction? {
    let result = _attributes.firstIndex { attribute in
      return switch attribute {
      case .Direction(_): true
      default: false
      }
    }
    return result.flatMap { index in
      return switch _attributes[index] {
      case .Direction(let d): d
      default: Optional<Direction>.none
      }
    }
  }

  public func readOnly() -> Bool {
    return _attributes.contains { attribute in
      return switch attribute {
      case .Readonly: true
      default: false
      }
    }
  }

  public func update(removeAttribute attributeToRemove: P4TypeAttribute) -> P4TypeAttributes {
    var new_attributes = self._attributes
    new_attributes.removeAll { item in
      return item == attributeToRemove
    }
    return P4TypeAttributes(new_attributes)
  }

  public func update(addAttribute attributeToAdd: P4TypeAttribute) -> P4TypeAttributes {
    return P4TypeAttributes(self._attributes + [attributeToAdd])
  }

  public var description: String {
    return self._attributes.map { attribute in
      return "\(attribute)"
    }.joined(separator: ",")
  }

  public static func ReadOnly() -> P4TypeAttributes {
    return P4TypeAttributes([P4TypeAttribute.Readonly])
  }

}

public struct P4Type: CustomStringConvertible {
  let _attributes: P4TypeAttributes
  let _data_type: P4DataType

  public init(_ type: P4DataType, _ attributes: P4TypeAttributes = P4TypeAttributes([])) {
    self._attributes = attributes
    self._data_type = type
  }

  public func update(removeAttribute attribute: P4TypeAttribute) -> P4Type {
    return P4Type(self._data_type, self._attributes.update(addAttribute: attribute))
  }

  public func update(addAttribute attribute: P4TypeAttribute) -> P4Type {
    return P4Type(self._data_type, self._attributes.update(removeAttribute: attribute))
  }

  public func direction() -> Direction? {
    return self._attributes.direction()
  }

  public func readOnly() -> Bool {
    return self._attributes.readOnly()
  }

  public func dataType() -> P4DataType {
    return self._data_type
  }

  public func def() -> P4Value {
    return P4Value(self._data_type.def(), self)
  }

  public func eq(_ rhs: P4Type) -> Bool {
    return self.direction() == rhs.direction() && self.readOnly() == self.readOnly()
      && self.dataType().eq(rhs: rhs.dataType())
  }

  public static func ReadOnly(_ type: P4DataType) -> P4Type {
    return P4Type(type, P4TypeAttributes.ReadOnly())
  }

  public var description: String {
    var attributes_description = "\(self._attributes)"
    if !attributes_description.isEmpty {
      attributes_description += " "
    }
    return "\(attributes_description)\(self._data_type)"
  }
}

public struct P4Value: CustomStringConvertible {
  let _value: P4DataValue
  let _type: P4Type

  public init(_ value: P4DataValue, _ type: P4Type? = .none) {
    self._value = value
    self._type = type != nil ? type! : P4Type(value.type())
  }

  public func update(withNewValue value: P4DataValue) -> Result<P4Value> {
    // TODO: Check that the types match.
    return .Ok(P4Value(value, self._type))
  }

  public var description: String {
    return "Value: \(self._value) of type \(self._type)"
  }

  public func type() -> P4Type {
    return self._type
  }

  public func dataValue() -> P4DataValue {
    return self._value
  }
  public func eq(_ rhs: P4Value) -> Bool {
    return self._value.eq(rhs: rhs.dataValue())
  }
  public func lt(_ rhs: P4Value) -> Bool {
    return self._value.lt(rhs: rhs.dataValue())
  }
  public func lte(_ rhs: P4Value) -> Bool {
    return self._value.lte(rhs: rhs.dataValue())
  }
  public func gt(_ rhs: P4Value) -> Bool {
    return self._value.gt(rhs: rhs.dataValue())
  }
  public func gte(_ rhs: P4Value) -> Bool {
    return self._value.gte(rhs: rhs.dataValue())
  }

}
