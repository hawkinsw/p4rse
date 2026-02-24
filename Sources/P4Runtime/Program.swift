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

extension BlockStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    var execution = execution
    for s in self.statements {
      execution = s.evaluate(execution: execution) 
    }
    return execution
  }
}

extension VariableDeclarationStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    guard case .Ok(let initial_value) = self.initializer.evaluate(execution: execution) else {
      return execution.setError(error: Error(withMessage: "Could not evaluate \(self.initializer)"))
    }
    let new_scopes = execution.scopes.declare(identifier: self.identifier, withValue: initial_value)
    execution.scopes = new_scopes
    return execution
  }
}

extension ConditionalStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    guard case .Ok(let initial_value) = self.condition.evaluate(execution: execution) else {
      return execution.setError(error: Error(withMessage: "Could not evaluate \(self.condition)"))
    }
    if !initial_value.type().eq(rhs: P4Boolean.create()) {
      return execution.setError(error: Error(withMessage: "Condition expression is not a Boolean"))
    }
    if initial_value.eq(rhs: P4BooleanValue.init(withValue: true)) {
      let execution = execution.enter_scope()
      var result = self.thenn.evaluate(execution: execution)
      result = result.exit_scope() 
      return result
    } else if let elss = self.elss {
      let execution = execution.enter_scope()
      var result = elss.evaluate(execution: execution)
      result = result.exit_scope() 
      return result
    }
    return execution
  }
}


extension ExpressionStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    return execution
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension TypedIdentifier: EvaluatableExpression {
  public func type() -> any Common.P4Type {
    return self.parsed_type
  }

  public func evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return execution.scopes.lookup(identifier: self)
  }
}
