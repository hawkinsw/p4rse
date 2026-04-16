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

import Common
import P4Lang

extension ParserAssignmentStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    let updated_execution = execution
    let result = self.value.evaluate(execution: updated_execution)
    guard case (.Ok(let value), let updated_execution) = result else {
      return (ControlFlow.Error, execution.setError(error: result.0.error()!))
    }

    let maybe_updated_scopes = self.lvalue.set(
      to: value, inScopes: execution.scopes, duringExecution: updated_execution)
    guard case Result.Ok(let updated_scopes) = maybe_updated_scopes else {
      return (ControlFlow.Error, execution.setError(error: maybe_updated_scopes.error()!))
    }
    execution.scopes = updated_scopes.0

    return (ControlFlow.Next, updated_execution)
  }
}

extension ParserStateDirectTransition: EvaluatableParserState {
  public func execute(
    program: Common.ProgramExecution
  ) -> (any EvaluatableParserState, Common.ProgramExecution) {
    var program = program.enter_scope()

    for statement in statements {
      let (control_flow, next_program) = statement.evaluate(execution: program)
      switch control_flow {
      case .Next: program = next_program  // Ok!
      case .Error: return (reject, next_program)
      default:
        return (
          reject,
          next_program.setError(
            error: Error(withMessage: "Invalid control flow (\(control_flow) in parser)"))
        )
      }
    }
    let res = program.scopes.lookup(identifier: get_next_state())

    if case .Ok(let value) = res {
      if value.type().dataType().eq(rhs: self) {
        return (value.dataValue() as! EvaluatableParserState, program.exit_scope())
      }
    }

    program = program.setError(error: res.error()!).exit_scope()

    return (self, program.exit_scope())
  }

  public func done() -> Bool {
    return false
  }

  public func state() -> P4Lang.ParserState {
    return self
  }
}

extension ParserStateNoTransition: EvaluatableParserState {

  public func execute(
    program: Common.ProgramExecution
  ) -> (any EvaluatableParserState, Common.ProgramExecution) {
    return (self, program)
  }

  public func done() -> Bool {
    return true
  }

  public func state() -> P4Lang.ParserState {
    return self
  }
}

extension ParserStateSelectTransition: EvaluatableParserState {

  public func execute(
    program: Common.ProgramExecution
  ) -> (any EvaluatableParserState, Common.ProgramExecution) {
    var program = program.enter_scope()

    // First, evaluate the statements.
    for statement in statements {
      let (control_flow, next_program) = statement.evaluate(execution: program)
      switch control_flow {
      case .Next: program = next_program  // Ok!
      case .Error: return (reject, next_program)
      default:
        return (
          reject,
          next_program.setError(
            error: Error(withMessage: "Invalid control flow (\(control_flow) in parser)"))
        )
      }
    }

    switch self.selectExpression.evaluate(execution: program) {
    case (.Ok(let value), let program):
      if value.type().dataType().eq(rhs: self) {
        return (value.dataValue() as! EvaluatableParserState, program.exit_scope())
      } else {
        return (
          self,
          program.setError(
            error: Error(withMessage: "Select transition transitioned to a none state"))
        )
      }
    case (.Error(let e), let program): return (self, program.setError(error: e).exit_scope())
    }
  }

  public func done() -> Bool {
    return false
  }

  public func state() -> P4Lang.ParserState {
    return self
  }
}

extension Parser: LibraryCallable {
  public typealias T = InstantiatedParserState
  public func call(
    execution: Common.ProgramExecution, arguments: P4Lang.ArgumentList
  ) -> (P4Lang.InstantiatedParserState, Common.ProgramExecution) {
    var execution = execution.enter_scope()

    execution = execution.declare(
      identifier: AsInstantiatedParserState(accept.state()).state,
      withValue: P4Value(accept, P4Type.ReadOnly(accept.type())))
    execution = execution.declare(
      identifier: AsInstantiatedParserState(reject.state()).state,
      withValue: P4Value(reject, P4Type.ReadOnly(reject.type())))

    // Add initial values to the global scope
    if let initial = execution.initial_values() {
      for (name, value) in initial {
        execution = execution.declare(identifier: name, withValue: value)
      }
    }

    // First, add every state to the scope!
    for state in self.states.states {
      execution = execution.declare(
        identifier: state.state, withValue: P4Value(state))
    }

    guard let _current_state = self.findStartState(),
      var current_state = _current_state as? EvaluatableParserState
    else {
      return (
        reject, execution.setError(error: Error(withMessage: "Could not find the start state"))
      )
    }

    let call_body: (ProgramExecution) -> (Result<P4Value>, ProgramExecution) = {
      (execution: ProgramExecution) in
      var current_execution = execution
      // Evaluate until the state is either accept or reject.
      while !current_state.done() && !current_execution.hasError() {
        (current_state, current_execution) = current_state.execute(program: current_execution)
      }
      return (.Ok(P4Value(AsInstantiatedParserState(current_state.state()))), current_execution)
    }

    return
      switch Call(
        body: call_body, withArguments: arguments, withParameters: parameters, inExecution: execution)
    {
    case (.Ok(let value), let updated_execution):
      (value.dataValue() as! InstantiatedParserState, updated_execution)
    case (.Error(let e), let updated_execution):
      (reject, updated_execution.setError(error: Error(withMessage: "Cannot call parser: \(e)")))
    }
  }
}
