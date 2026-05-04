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

public enum TypeCheckResults: Equatable {
  case Ok
  case ReadOnly
  case WrongDirection
  case IncompatibleTypes
}

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

public enum P4TypeQualifier: Equatable {
  case Direction(Direction)
  case Readonly  // Not yet used -- here to keep Swift warnings at bay
}

public struct P4TypeQualifiers: CustomStringConvertible {
  let _qualifiers: [P4TypeQualifier]

  public init(_ qualifiers: [P4TypeQualifier]) {
    self._qualifiers = qualifiers
  }

  public func direction() -> Direction? {
    let result = _qualifiers.firstIndex { attribute in
      return switch attribute {
      case .Direction(_): true
      default: false
      }
    }
    return result.flatMap { index in
      return switch _qualifiers[index] {
      case .Direction(let d): d
      default: Optional<Direction>.none
      }
    }
  }

  public func readOnly() -> Bool {
    return _qualifiers.contains { attribute in
      return switch attribute {
      case .Readonly: true
      default: false
      }
    }
  }

  public func update(removeAttribute attributeToRemove: P4TypeQualifier) -> P4TypeQualifiers {
    var new_attributes = self._qualifiers
    new_attributes.removeAll { item in
      return item == attributeToRemove
    }
    return P4TypeQualifiers(new_attributes)
  }

  public func update(addAttribute attributeToAdd: P4TypeQualifier) -> P4TypeQualifiers {
    return P4TypeQualifiers(self._qualifiers + [attributeToAdd])
  }

  public var description: String {
    return self._qualifiers.map { qualifier in
      return "\(qualifier)"
    }.joined(separator: ",")
  }

  public static func ReadOnly() -> P4TypeQualifiers {
    return P4TypeQualifiers([P4TypeQualifier.Readonly])
  }

}

public struct P4QualifiedType: CustomStringConvertible {
  let _attributes: P4TypeQualifiers
  let base_type: P4Type

  public init(_ base_type: P4Type, _ attributes: P4TypeQualifiers = P4TypeQualifiers([])) {
    self._attributes = attributes
    self.base_type = base_type
  }

  public func update(removeAttribute attribute: P4TypeQualifier) -> P4QualifiedType {
    return P4QualifiedType(self.base_type, self._attributes.update(removeAttribute: attribute))
  }

  public func update(addAttribute attribute: P4TypeQualifier) -> P4QualifiedType {
    return P4QualifiedType(self.base_type, self._attributes.update(addAttribute: attribute))
  }

  public func direction() -> Direction? {
    return self._attributes.direction()
  }

  public func readOnly() -> Bool {
    return self._attributes.readOnly()
  }

  public func baseType() -> P4Type {
    return self.base_type
  }

  public func def() -> P4Value? {
    if let default_value = self.base_type.def() {
      return P4Value(default_value, self)
    }
    return .none
  }

  public func eq(_ rhs: P4QualifiedType) -> Bool {
    return self.direction() == rhs.direction() && self.readOnly() == self.readOnly()
      && self.baseType().eq(rhs: rhs.baseType())
  }

  public func assignable() -> TypeCheckResults {
    if self.readOnly() {
      return TypeCheckResults.ReadOnly
    }

    if let direction = direction(),
      direction == Direction.In
    {
      return TypeCheckResults.WrongDirection
    }
    return TypeCheckResults.Ok
  }

  public func assignableFromType(_ rhs: P4QualifiedType) -> TypeCheckResults {
    if !self.baseType().eq(rhs: rhs.baseType()) {
      return TypeCheckResults.IncompatibleTypes
    }

    if self.readOnly() {
      return TypeCheckResults.ReadOnly
    }

    if let direction = direction(),
      direction == Direction.In
    {
      return TypeCheckResults.WrongDirection
    }

    return TypeCheckResults.Ok
  }

  public static func ReadOnly(_ type: P4Type) -> P4QualifiedType {
    return P4QualifiedType(type, P4TypeQualifiers.ReadOnly())
  }

  public var description: String {
    var attributes_description = "\(self._attributes)"
    if !attributes_description.isEmpty {
      attributes_description += " "
    }
    return "\(attributes_description)\(self.base_type)"
  }
}

public struct P4Value: CustomStringConvertible {
  let _value: P4DataValue
  let _type: P4QualifiedType

  public init(_ value: P4DataValue, _ type: P4QualifiedType? = .none) {
    self._value = value
    self._type = type != nil ? type! : P4QualifiedType(value.type())
  }

  public func update(withNewValue value: P4DataValue) -> Result<P4Value> {
    /// TODO: Check that the types match.
    return .Ok(P4Value(value, self._type))
  }

  public var description: String {
    return "Value: \(self._value) of type \(self._type)"
  }

  public func type() -> P4QualifiedType {
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
