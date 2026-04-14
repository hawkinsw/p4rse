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
    let result = self.value.evaluate(execution: execution)
    guard case Result.Ok(let value) = result else {
      return (ControlFlow.Error, execution.setError(error: result.error()!))
    }

    let maybe_updated_scopes = self.lvalue.set(
      to: value, inScopes: execution.scopes, duringExecution: execution)
    guard case Result.Ok(let updated_scopes) = maybe_updated_scopes else {
      return (ControlFlow.Error, execution.setError(error: maybe_updated_scopes.error()!))
    }
    execution.scopes = updated_scopes.0

    return (ControlFlow.Next, execution)
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

    let res = self.selectExpression.evaluate(execution: program)

    if case .Ok(let value) = res {
      if value.type().dataType().eq(rhs: self) {
        return (value.dataValue() as! EvaluatableParserState, program.exit_scope())
      } else {
        return (
          self,
          program.setError(
            error: Error(withMessage: "Select transition transitioned to a none state"))
        )
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

extension Parser: CallableExecution {
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

    // Now that we are assured that there is a start state,
    // let's set the arguments.

    if case .Error(let e) = arguments.compatible(self.parameters) {
      return (
        reject, execution.setError(error: Error(withMessage: "Cannot call parser: \(e)"))
      )
    }

    for (parameter, argument) in zip(self.parameters.parameters, arguments.arguments) {
      let arg_idx = argument.index
      let arg_value = argument.argument
      let maybe_argument_value = arg_value.evaluate(execution: execution)
      guard case .Ok(let argument_value) = maybe_argument_value else {
        return (
          reject,
          execution.setError(
            error: Error(withMessage: "Cannot evaluate argument \(arg_idx): \(argument)"))
        )
      }
      execution = execution.declare(identifier: parameter.name, withValue: argument_value)
    }

    // Evaluate until the state is either accept or reject.
    while !current_state.done() && !execution.hasError() {
      (current_state, execution) = current_state.execute(program: execution)
    }

    return (AsInstantiatedParserState(current_state.state()), execution.exit_scope())
  }
}
