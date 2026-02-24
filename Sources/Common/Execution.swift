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
    public var scopes: ValueScopes = ValueScopes()
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

public typealias ValueScope = Scope<P4Value>
public typealias ValueScopes = Scopes<P4Value>
