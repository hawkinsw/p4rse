// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

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

public enum ValueType: CustomStringConvertible {
    case Boolean(Bool)

    public var description: String {
        switch self {
            case ValueType.Boolean(let b):
                return "\(b) of Boolean"
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