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

extension KeysetExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return execution.scopes.lookup(identifier: next_state_identifier)
  }

  public func type() -> any Common.P4Type {
    return P4ParserState.create()
  }
}

extension SelectExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    switch self.selector.evaluate(execution: execution) {
    case .Ok(let selector_value):
      for kse in self.keyset_expressions {
        if case .Ok(let kse_key) = kse.key.evaluate(execution: execution),
          kse_key.eq(rhs: selector_value)
        {
          let result = kse.evaluate(execution: execution)
          return result
        }
      }
      return .Error(Error(withMessage: "No key matched the selector"))
    case .Error(let e): return .Error(e)
    }
  }

  public func type() -> any Common.P4Type {
    return P4ParserState.create()
  }
}

extension P4StringValue: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return .Ok(self)
  }
}

extension P4BooleanValue: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return .Ok(self)
  }
}

extension P4StructValue: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return .Ok(self)
  }
}

extension P4IntValue: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return .Ok(self)
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
