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
import Lang

extension ParserAssignmentStatement: EvaluatableParserStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    let updated_scopes = execution.scopes.set(identifier: self.lvalue, value: self.value)

    execution.scopes = updated_scopes

    return execution
  }
}

public struct ParserStateDirectTransition: ParserStateInstance {
  public let currrent_state: ParserState
  public let next_state: ParserStateInstance

  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    var program = program.exit_scope()
    program = program.enter_scope()

    for local_element in currrent_state.local_elements {
      program = local_element.evaluate(execution: program)
    }

    for statement in currrent_state.statements {
      program = statement.evaluate(execution: program)
    }

    return (self.next_state, program)
  }

  public func done() -> Bool {
    return false
  }

  public func current() -> Lang.ParserState {
    return currrent_state
  }

}

public struct ParserStateNoTransition: ParserStateInstance {
  public let currrent_state: ParserState
  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    let program = program.exit_scope()
    return (self, program)
  }

  public func done() -> Bool {
    return true
  }

  public func current() -> Lang.ParserState {
    return currrent_state
  }
}

public struct ParserStateSelectTransition: ParserStateInstance {
  public func execute(
    program: Common.ProgramExecution
  ) -> (any ParserStateInstance, Common.ProgramExecution) {
    // Otherwise, we exit the scope from the previous state and enter a new one!
    var program = program.exit_scope()
    program = program.enter_scope()

    // First, evaluate the local elements.
    for local_element in currrent_state.local_elements {
      program = local_element.evaluate(execution: program)
    }

    // Then, evaluate the statements.
    for statement in currrent_state.statements {
      program = statement.evaluate(execution: program)
    }


    switch self.selector.evaluate(execution: program) {
    case .Ok(let selector_value):
      for (key, target) in zip(self.keys, self.states) {
        if case .Ok(let kse_key) = key.evaluate(execution: program),
          kse_key.eq(rhs: selector_value)
        {
          return (target, program)
        }
      }
      return (
        self, program.setError(error: Error(withMessage: "No selector key matched")).setDone()
      )
    case .Error(let e): return (self, program.setError(error: e))
    }
  }

  public func done() -> Bool {
    return false
  }

  public func current() -> Lang.ParserState {
    return currrent_state
  }

  public let keys: [any EvaluatableExpression]
  public let states: [ParserStateInstance]
  public let selector: any EvaluatableExpression
  public let currrent_state: ParserState
}

extension ParserState: Compilable {
  public typealias ToCompile = (ParserState, [String: ParserStateInstance])
  public typealias Compiled = ParserStateInstance
  public static func compile(_ parser: ToCompile) -> Result<Compiled> {
    let (state, current) = parser
    if state == accept || state == reject {
      return .Ok(ParserStateNoTransition(currrent_state: state))
    }

    if state.direct_transition(), 
    let transition_statement = state.transition {
      return .Ok(
        ParserStateDirectTransition(
          currrent_state: state, next_state: current[transition_statement.next_state_name!]!))
    }

    if let transition_select_statement = state.transition,
    let transition_select_expression = transition_select_statement.transition_expression {

      var keys: Array<any EvaluatableExpression> = Array()
      var states: Array<any ParserStateInstance> = Array()

      for kse in transition_select_expression.keyset_expressions {
        guard let next_state = current[kse.next_state_name] else {
          return .Error(Error(withMessage: "Cannot find \(kse.next_state_name) as transition target"))
        }
        keys.append(kse.key)
        states.append(next_state)
      }
      return .Ok(ParserStateSelectTransition(keys: keys, states: states, selector: transition_select_expression.selector, currrent_state: state))
    }

    return .Error(Error(withMessage: "Invalid parser state: No meaningful transition"))
  }
}

extension ParserStates: Compilable {
  public typealias ToCompile = ParserStates
  public typealias Compiled = ParserStateInstance
  public static func compile(_ parser: ToCompile) -> Result<Compiled> {
    var compiled_states = [String: ParserStateInstance]()

    compiled_states["accept"] = ParserStateNoTransition(currrent_state: accept)
    compiled_states["reject"] = ParserStateNoTransition(currrent_state: reject)

    // TODO: We assume that states are in transition-order!
    for state in parser.states {
      switch ParserState.compile((state, compiled_states)) {
        case .Ok(let compiled): compiled_states[state.state_name] = compiled
        case .Error(let e): return .Error(e)
      }
    }

    // Now, find the start state:
    if let start_state = compiled_states["start"] {
      return .Ok(start_state)
    } else {
      return .Error(Error(withMessage: "No start state defined"))
    }
  }
}

public class ParserInstance: ProgramExecution {

  let start_state: ParserStateInstance

  public init(_ _start_state: ParserStateInstance) {
    self.start_state = _start_state
  }

  public override var description: String {
    return "Execution: \(super.description)\nStart State: \(start_state)"
  }
}

extension ParserInstance: Compilable {
  public typealias ToCompile = Parser
  public typealias Compiled = ParserInstance

  public static func compile(_ parser: ToCompile) -> Result<Compiled> {
    return switch ParserStates.compile(parser.states) {
    case .Ok(let start_state): Result.Ok(ParserInstance(start_state))
    case .Error(let e): Result.Error(e)
    }
  }
}
