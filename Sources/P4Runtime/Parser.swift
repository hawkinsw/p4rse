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
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    let result = self.value.evaluate(execution: execution)
    guard case Result.Ok(let value) = result else {
      return execution.setError(error: result.error()!)
    }

    let maybe_updated_scopes = self.lvalue.set(
      to: value, inScopes: execution.scopes, duringExecution: execution)
    guard case Result.Ok(let updated_scopes) = maybe_updated_scopes else {
      return execution.setError(error: maybe_updated_scopes.error()!)
    }
    execution.scopes = updated_scopes.0

    return execution
  }
}

extension ParserStateDirectTransition: EvaluatableParserState {
  public func execute(
    program: Common.ProgramExecution
  ) -> (any EvaluatableParserState, Common.ProgramExecution) {
    var program = program.enter_scope()

    for statement in statements {
      program = statement.evaluate(execution: program)
    }
    let res = program.scopes.lookup(identifier: get_next_state())

    if case .Ok(let value) = res {
      if value.type().eq(rhs: self) {
        return (value as! EvaluatableParserState, program.exit_scope())
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
      program = statement.evaluate(execution: program)
    }

    let res = self.selectExpression.evaluate(execution: program)

    if case .Ok(let value) = res {
      if value.type().eq(rhs: self) {
        return (value as! EvaluatableParserState, program.exit_scope())
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

extension Parser: ParserExecution {
  public func execute(execution: ProgramExecution) -> (ParserState, ProgramExecution) {
    var execution = execution.enter_scope()

    execution = execution.declare(identifier: accept.state().state, withValue: accept)
    execution = execution.declare(identifier: reject.state().state, withValue: reject)

    // Add initial values to the global scope
    if let initial = execution.initial_values() {
      for (name, value) in initial {
        execution = execution.declare(identifier: name, withValue: value)
      }
    }

    // First, add every state to the scope!
    for state in self.states.states {
      execution = execution.declare(identifier: state.state, withValue: state)
    }

    guard let _current_state = self.findStartState(),
      var current_state = _current_state as? EvaluatableParserState
    else {
      return (
        reject, execution.setError(error: Error(withMessage: "Could not find the start state"))
      )
    }

    // Evaluate until the state is either accept or reject.
    while !current_state.done() && !execution.hasError() {
      (current_state, execution) = current_state.execute(program: execution)
    }
    return (current_state.state(), execution)
  }
}
