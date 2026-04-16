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
  public var scopes: VarValueScopes = VarValueScopes()
  let initialValues: VarValueScopes?
  var error: Error?
  var debug: DebugLevel = DebugLevel.Error

  init(copy: ProgramExecution) {
    self.scopes = copy.scopes
    self.initialValues = copy.initialValues
    self.error = copy.error
    self.debug = copy.debug
  }

  public init() {
    initialValues = .none
  }

  public init(withGlobalValues values: VarValueScopes) {
    initialValues = values
  }

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
    let npe = ProgramExecution(copy: self)
    npe.error = error
    return npe
  }

  public func getDebugLevel() -> DebugLevel {
    return self.debug
  }

  public func setDebugLevel(_ dl: DebugLevel) -> ProgramExecution {
    let pe = ProgramExecution(copy: self)
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
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_pe.scopes.enter()

    return new_pe
  }

  public func exit_scope() -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_pe.scopes.exit()

    return new_pe
  }

  public func replaceScopes(_ new_scopes: VarValueScopes) -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_scopes
    return new_pe
  }

  public func declare(identifier: Identifier, withValue value: P4Value) -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    let new_scopes = new_pe.scopes.declare(identifier: identifier, withValue: value)

    new_pe.scopes = new_scopes
    return new_pe
  }

  public func initial_values() -> VarValueScopes? {
    return self.initialValues
  }
}

/// A scope that resolves variable identifiers to their values.
public typealias VarValueScope = Scope<P4Value>

/// Scopes that resolves variable identifiers to their values.
public typealias VarValueScopes = Scopes<P4Value>

/// Indicate the control flow result of a particular statement.
public enum ControlFlow {
  case Next
  case Continue
  case Break
  case Return(P4Value?)
  case Error
}
