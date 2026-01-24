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

public class Identifier: CustomStringConvertible {
    var name: String
    var value: Value

    public init(name: String, withValue value: Value) {
        self.name = name
        self.value = value
    }

    public var description: String {
        return "\(name) = \(value)"
    }
}

public class Variable: Identifier {
    var constant: Bool

    public init(name: String, withValue value: Value, isConstant constant: Bool) {
        self.constant = constant
        super.init(name: name, withValue: value)
    }

    public override var description: String {
        return "\(super.description) \(constant ? "(constant)" : "")"
    }
}

public struct Scope: CustomStringConvertible{
    var variables: [Variable] = Array()
    public init() {}

    public var description: String {
        var result = String()
        for v in variables {
            result += "\(v)"
        }
        return result
    }
}

public struct Scopes: CustomStringConvertible {
    var scopes: [Scope] = Array()

    public init() {}

    public mutating func enter() {
        scopes.append(Scope())
    }

    public mutating func exit() {
        let _ = scopes.popLast()
    }

    public var description: String {
        var result = String()
        for s in scopes {
            result += "Scope: \(s)\n"
        }

        return result
    }
}

public struct Program {
    public var parsers: [P4.Parser] = Array()
    public init() {}
}
