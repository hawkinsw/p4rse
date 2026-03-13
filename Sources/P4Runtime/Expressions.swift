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
    // TODO
    return reject
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

  // TODO
  public func type() -> any Common.P4Type {
    return reject
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

public func binary_equal_operator_evaluator(left: P4Value, right: P4Value) -> P4Value {
  if left.eq(rhs: right) {
    return P4BooleanValue(withValue: true)
  }
  return P4BooleanValue(withValue: false)
}

extension BinaryOperatorExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    let maybe_evaluated_left = self.left.evaluate(execution: execution)
    guard case Result.Ok(let evaluated_left) = maybe_evaluated_left else {
      return maybe_evaluated_left
    }

    let maybe_evaluated_right = self.right.evaluate(execution: execution)
    guard case Result.Ok(let evaluated_right) = maybe_evaluated_right else {
      return maybe_evaluated_right
    }

    return Result.Ok(self.evaluator.2(evaluated_left, evaluated_right))
  }

  public func type() -> any Common.P4Type {
    return self.evaluator.1
  }
}

extension ArrayAccessExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    let maybe_name = self.name.evaluate(execution: execution)
    guard case Result.Ok(let name) = maybe_name else {
      return maybe_name
    }

    let maybe_indexor = self.indexor.evaluate(execution: execution)
    guard case Result.Ok(let indexor) = maybe_indexor else {
      return maybe_indexor
    }

    guard let indexor_int = indexor as? P4IntValue else {
      return Result.Error(Error(withMessage: "\(indexor) cannot index an array"))
    }

    guard let array = name as? P4ArrayValue else {
      return Result.Error(Error(withMessage: "\(name) does not name an array"))
    }
    let accessed = array.access(indexor_int.access())

    return accessed.evaluate(execution: execution)
  }

  public func type() -> any Common.P4Type {
    return P4Int.create()
  }
}
