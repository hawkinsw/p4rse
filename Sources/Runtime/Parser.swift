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



extension ParserTransitionStatement: EvaluatableParserTransitionStatement {
  // TODO: Currently transitions to accept.
  func transition(execution: ProgramExecution) -> (ParserState, ProgramExecution) {
    return (accept, execution)
  }
}

extension ParserState: EvaluatableParserState {
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

    return if let transition = transition {
      transition.transition(execution: currentExecution)
    } else {
      (reject, currentExecution)
    }
  }
}
