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

public struct Scope<T>: CustomStringConvertible {
    var symbols: Dictionary<Identifier, T> = Dictionary()
    public init() {}

    public var description: String {
        var result = String()
        for (k,v) in symbols {
            result += "\(k): \(v)\n"
        }
        return result
    }

    public var count: Int {
        get {
            symbols.count
        }
    }

    public func lookup(identifier: Identifier) -> T? {
        if let symbol = symbols[identifier] {
            return symbol
        }
        return .none
    }

    public func declare(identifier: Identifier, withValue value: T) -> Scope {
        var s = self
        s.symbols[identifier] = value
        return s
    }
}

public struct Scopes<T>: CustomStringConvertible {
    var scopes: [Scope<T>] = Array()

    public init() {}

    init(withScopes scopes: [Scope<T>]) {
        self.scopes = scopes
    }

    public func enter() -> Scopes {
        var new_scopes = scopes
        new_scopes.append(Scope())

        return Scopes(withScopes: new_scopes)
    }

    public func exit() -> Scopes {
        var old_scopes = scopes
        _ = old_scopes.popLast()
        return Scopes(withScopes: old_scopes)
    }

    public var description: String {
        var result = String()
        for s in scopes {
            result += "LexicalScope:\n\(s)\n"
        }

        return result
    }

    public var current: Scope<T>? {
        get {
            scopes.last
        }
    }

    public func set(identifier: Identifier, withValue value: T) -> Scopes {
        var scopes = self.scopes
        var scopes_to_read: [Scope<T>] = Array()

        // Find the scope that has `identifier`
        while let scope = scopes.popLast() {
            if scope.lookup(identifier: identifier) != nil {
                // Update that scope and add it to scopes
                scopes.append(scope.declare(identifier: identifier, withValue: value))
                break
            } else {
                // If there was no match, we'll put it back
                scopes_to_read.append(scope)
            }
        }
        return Scopes<T>(withScopes: (scopes + scopes_to_read))
    }

    public func declare(identifier: Identifier, withValue value: T) -> Scopes {
        var s = self
        if let scope = s.scopes.popLast() {
            s.scopes.append(scope.declare(identifier: identifier, withValue: value))
        }
        return s
    }

    public func lookup(identifier: Identifier) -> Result<T> {
        for scope in scopes {
            if let vari = scope.lookup(identifier: identifier) {
                return .Ok(vari)
            }
        }
        return .Error(Error(withMessage: "Cannot find \(identifier) in lexical scope."))
    }

    public var count: Int {
        get {
            scopes.count
        }
    }
}
