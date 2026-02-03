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


public class Identifier: CustomStringConvertible, Equatable {
    var name: String

    public init(name: String) {
        self.name = name
    }

    public var description: String {
        return "\(name)"
    }

    public static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
        return lhs.name == rhs.name
    }
}

public class Variable: Identifier {
    var constant: Bool
    var value: ValueType

    public init(name: String, withValue value: ValueType, isConstant constant: Bool) {
        self.constant = constant
        self.value = value
        super.init(name: name)
    }

    public override var description: String {
        return "\(super.description) = \(value) \(constant ? "(constant)" : "")"
    }

    public var value_type: ValueType {
        get {
            value
        }
    }
}

public enum ValueType: CustomStringConvertible, Equatable {
    case Boolean(Bool)
    case Int(Int)
    case String(String)

    public var description: String {
        switch self {
            case ValueType.Boolean(let b):
                return "\(b) of Boolean"
            case ValueType.Int(let i):
                return "\(i) of Int"
            case ValueType.String(let s):
                return "\(s) of String"
        }
    }

    public static func==(lhs: ValueType, rhs: ValueType) -> Bool {
        switch (lhs,rhs) {
            case (ValueType.Boolean(let lhsb), ValueType.Boolean(let rhsb)):
                return lhsb == rhsb
            case (ValueType.String(let lhsb), ValueType.String(let rhsb)):
                return lhsb == rhsb
            case (ValueType.Int(let lhsb), ValueType.Int(let rhsb)):
                return lhsb == rhsb
            default: return false
        }
    }

}

public struct Value: CustomStringConvertible {
    public var value_type: ValueType

    public init(withValue value: ValueType) {
        self.value_type = value
    }
    public var description: String {
        return "\(value_type)"
    }
}

public class Packet {
    public init() {}
}