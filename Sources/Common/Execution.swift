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

open class ProgramExecution: CustomStringConvertible {
    public var scopes: Scopes = Scopes()

    public init() {}

    open var description: String {
        return "Runtime:\nScopes: \(scopes)"
    }
}


public struct Scope: CustomStringConvertible{
    var variables: [Variable] = Array()
    public init() {}

    public var description: String {
        var result = String()
        for v in variables {
            result += "\(v)\n"
        }
        return result
    }

    public var count: Int {
        get {
            variables.count
        }
    }

    public func lookup(identifier: Identifier) -> Variable? {
        for v in variables {
            if v == identifier {
                return v
            }
        }
        return .none
    }

    public mutating func declare(variable: Variable) -> Scope {
        var s = self
        s.variables.append(variable)
        return s
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
            result += "Scope:\n\(s)\n"
        }

        return result
    }

    public var current: Scope? {
        get {
            scopes.last
        }
    }

    public func declare(variable: Variable) -> Scopes {
        var s = self
        if var scope = s.scopes.popLast() {
            s.scopes.append(scope.declare(variable: variable))
        }
        return s
    }

    public var count: Int {
        get {
            scopes.count
        }
    }
}
