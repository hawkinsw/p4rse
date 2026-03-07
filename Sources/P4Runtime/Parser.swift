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
    let updated_scopes = execution.scopes.set(identifier: self.lvalue, withValue: value)

    execution.scopes = updated_scopes

    return execution
  }
}

public struct ParserStateDirectTransition: ParserStateInstance {

  public func type() -> any Common.P4Type {
    return P4ParserState.create()
  }

  public func eq(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let state as ParserStateInstance: return currrent_state == state.state()
    default: return false
    }
  }

  public var description: String {
    return "Instance of \(currrent_state)"
  }

  public let currrent_state: ParserState
  public let next_state_identifier: Identifier

  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    var program = program.enter_scope()

    for statement in currrent_state.statements {
      program = statement.evaluate(execution: program)
    }
    let res = program.scopes.lookup(identifier: next_state_identifier)

    if case .Ok(let value) = res {
      if value.type().eq(rhs: P4ParserState.create()) {
        return (value as! ParserStateInstance, program.exit_scope())
      }
    }

    program = program.setError(error: res.error()!).exit_scope()

    return (self, program.exit_scope())
  }

  public func done() -> Bool {
    return false
  }

  public func state() -> P4Lang.ParserState {
    return currrent_state
  }

}

public struct ParserStateNoTransition: ParserStateInstance {

  public func type() -> any Common.P4Type {
    return P4ParserState.create()
  }

  public func eq(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let state as ParserStateInstance: return currrent_state == state.state()
    default: return false
    }
  }

  public var description: String {
    return "Instance of \(currrent_state)"
  }

  public let currrent_state: ParserState

  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    return (self, program)
  }

  public func done() -> Bool {
    return true
  }

  public func state() -> P4Lang.ParserState {
    return currrent_state
  }
}

public struct ParserStateSelectTransition: ParserStateInstance {
  public func type() -> any Common.P4Type {
    return P4ParserState.create()
  }

  public func eq(rhs: any Common.P4Value) -> Bool {
    switch rhs {
    case let state as ParserStateInstance: return currrent_state == state.state()
    default: return false
    }
  }

  public var description: String {
    return "Instance of \(currrent_state)"
  }

  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    var program = program.enter_scope()

    // First, evaluate the statements.
    for statement in currrent_state.statements {
      program = statement.evaluate(execution: program)
    }

    let res = self.selectExpression.evaluate(execution: program)

    if case .Ok(let value) = res {
      if value.type().eq(rhs: P4ParserState.create()) {
        return (value as! ParserStateInstance, program.exit_scope())
      }
    }

    program = program.setError(error: res.error()!).exit_scope()
    return (self, program.exit_scope())
  }

  public func done() -> Bool {
    return false
  }

  public func state() -> P4Lang.ParserState {
    return currrent_state
  }

  public let selectExpression: SelectExpression
  public let currrent_state: ParserState
}

extension ParserState: Compilable {
  public typealias ToCompile = ParserState
  public typealias Compiled = ParserStateInstance
  public static func compile(_ state: ToCompile) -> Result<Compiled> {

    if state.direct_transition(),
      let transition_statement = state.transition
    {
      return .Ok(
        ParserStateDirectTransition(
          currrent_state: state, next_state_identifier: transition_statement.next_state!))
    }

    if let transition_select_statement = state.transition,
      let transition_select_expression = transition_select_statement.transition_expression
    {

      return .Ok(
        ParserStateSelectTransition(
          selectExpression: transition_select_expression, currrent_state: state))
    }

    return .Error(Error(withMessage: "Invalid parser state: No meaningful transition"))
  }
}

extension ParserStates: Compilable {
  public typealias ToCompile = ParserStates
  public typealias Compiled = (ParserStateInstance, [ParserStateInstance])
  public static func compile(_ parser: ToCompile) -> Result<Compiled> {
    var compiled_states: [ParserStateInstance] = Array()

    compiled_states.append(ParserStateNoTransition(currrent_state: accept))
    compiled_states.append(ParserStateNoTransition(currrent_state: reject))

    var start_state: ParserStateInstance? = .none

    // TODO: We assume that states are in transition-order!
    for state in parser.states {
      switch ParserState.compile(state) {
      case .Ok(let compiled):
        if compiled.state().state == Identifier(name: "start") {
          start_state = compiled
        }
        compiled_states.append(compiled)
      case .Error(let e): return .Error(e)
      }
    }

    // Now, find the start state:
    if let start_state = start_state {
      return .Ok((start_state, compiled_states))
    } else {
      return .Error(Error(withMessage: "No start state defined"))
    }
  }
}

public class ParserInstance: ProgramExecution {

  let states: [ParserStateInstance]
  let start_state: ParserStateInstance

  public init(start: ParserStateInstance, states: [ParserStateInstance]) {
    start_state = start
    self.states = states
  }

  public override var description: String {
    return "Execution: \(super.description)\nStates: \(states)"
  }
}

extension ParserInstance: Compilable {
  public typealias ToCompile = Parser
  public typealias Compiled = ParserInstance

  public static func compile(_ parser: ToCompile) -> Result<Compiled> {
    return switch ParserStates.compile(parser.states) {
    case .Ok(let (start_state, states)):
      Result.Ok(ParserInstance(start: start_state, states: states))
    case .Error(let e): Result.Error(e)
    }
  }
}
