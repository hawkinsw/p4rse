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
    var error: Error?
    var debug: DebugLevel = DebugLevel.Error

    public init() {}

    open var description: String {
        return "Runtime:\nScopes: \(scopes)"
    }

    public func hasError() -> Bool {
        return self.error != nil
    }

    public func getError() -> Error? {
        return self.error
    }

    public func setError(error: Error) -> ProgramExecution {
        let npe = self
        npe.error = error
        return npe
    }

    public func getDebugLevel() -> DebugLevel {
        return self.debug
    }

    public func setDebugLevel(_ dl: DebugLevel) -> ProgramExecution {
        let pe = self
        pe.debug = dl
        return pe
    }

    open func isDone() -> Bool {
        return false
    }

    open func setDone() -> ProgramExecution {
        // For a bare ProgramExecution, setDone is a noop.
        return self
    }

    public func enter_scope() -> ProgramExecution {
       let new_pe = self
       new_pe.scopes = self.scopes.enter()

       return new_pe
    }

    public func exit_scope() -> ProgramExecution {
       let new_pe = self
       new_pe.scopes = self.scopes.exit()

       return new_pe
    }

}


public struct Scope: CustomStringConvertible, Equatable {
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

    public func set(identifier: Identifier, value: P4Value) -> Scope? {
        var updated = false
        var updated_scope: [Variable] = Array()
        for v in variables {
            if v == identifier && v.value_type.type().eq(rhs: value.type()) {
                updated = true
                updated_scope.append(Variable(name: v.name, withValue: value, isConstant: false))
            } else {
                updated_scope.append(v)
            }
        }
        var new_scope = Scope()
        new_scope.variables = updated_scope
        return if updated {
            new_scope
        } else {
            .none
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

public struct Scopes: CustomStringConvertible, Equatable {
    var scopes: [Scope] = Array()

    public init() {}

    init(withScopes scopes: [Scope]) {
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

    public func evaluate(identifier: Identifier) -> Result<P4Value> {
        for scope in scopes {
            if let vari = scope.lookup(identifier: identifier) {
                return .Ok(vari.value)
            }
        }
        return .Error(Error(withMessage: "Cannot find \(identifier) in scope."))
    }

    public var count: Int {
        get {
            scopes.count
        }
    }

    public func set(identifier: Identifier, value: P4Value) -> Scopes {
        var new_scopes: [Scope] = Array()
        for scope in self.scopes {
            if let updated_scope = scope.set(identifier: identifier, value: value) {
                new_scopes.append(updated_scope)
            } else {
                new_scopes.append(scope)
            }
        }
        return Scopes(withScopes: new_scopes)
    }
}
