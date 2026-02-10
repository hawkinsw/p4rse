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

extension ParserState: EvaluatableParserTransition {
  public func evaluate(execution: ProgramExecution) -> (ParserState, ProgramExecution) {
    var currentExecution = execution

    // First, evaluate the local elements.
    for local_element in local_elements {
      currentExecution = local_element.evaluate(execution: currentExecution)
    }

    // Then, evaluate the statements.
    for statement in statements {
      currentExecution = statement.evaluate(execution: currentExecution)
    }

    if direct_transition() {
      return (next_state!, currentExecution)
    }

    if let transition_expression = self.transition,
      let transition_select_expression = transition_expression.transition_expression
    {
      return transition_select_expression.evaluate(execution: currentExecution)
    }
    return (reject, currentExecution)
  }
}

extension ParserTransitionSelectExpression: EvaluatableParserTransition {
  func evaluate(execution: Common.ProgramExecution) -> (Lang.ParserState, Common.ProgramExecution) {
    // First, evaluate the selector.

    switch self.selector.evaluate(execution: execution) {
    case .Ok(let selector_value):
        for kse in self.keyset_expressions {
          if case .Ok(let kse_key) = kse.key.evaluate(execution: execution),
            kse_key.eq(rhs: selector_value)
          {
            return (kse.next_state!, execution)
          }
        }
    case .Error(let e): return (reject, execution.setError(error: e))
    }
    return (reject, execution)
  }
}
