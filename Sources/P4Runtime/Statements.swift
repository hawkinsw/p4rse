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
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    return execution.evaluator.ExecuteStatement(
      self.statements,
      handleResult: { (cf, execution) in
        switch cf {
        case ControlFlow.Return(let value): return (ControlFlow.Return(value), execution)
        case ControlFlow.Next: return (cf, execution)
        case ControlFlow.Error: return (ControlFlow.Error, execution)
        default:
          return (
            ControlFlow.Error,
            execution.setError(
              error: Error(withMessage: "Invalid control flow \(cf) in block statement"))
          )
        }
      },
      inExecution: execution)
  }
}

extension VariableDeclarationStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    guard
      //case (.Ok(let initial_value), let execution) = self.initializer.evaluate(execution: execution)
      case (.Ok(let initial_value), let execution) = execution.evaluator.EvaluateExpression(
        self.initializer, inExecution: execution)
    else {
      return (
        ControlFlow.Error,
        execution.setError(error: Error(withMessage: "Could not evaluate \(self.initializer)"))
      )
    }
    let new_scopes = execution.scopes.declare(identifier: self.identifier, withValue: initial_value)
    execution.scopes = new_scopes
    return (ControlFlow.Next, execution)
  }
}

extension ConditionalStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    guard
      //case (.Ok(let evaluated_condition), let execution) = self.condition.evaluate(execution: execution)
      case (.Ok(let evaluated_condition), let execution) = execution.evaluator.EvaluateExpression(
        self.condition, inExecution: execution)
    else {
      return (
        ControlFlow.Error,
        execution.setError(error: Error(withMessage: "Could not evaluate \(self.condition)"))
      )
    }

    if !evaluated_condition.type().dataType().eq(rhs: P4Boolean()) {
      return (
        ControlFlow.Error,
        execution.setError(error: Error(withMessage: "Condition expression is not a Boolean"))
      )
    }

    if evaluated_condition.dataValue().eq(rhs: P4BooleanValue.init(withValue: true)) {
      let execution = execution.enter_scope()
      switch self.thenn.evaluate(execution: execution) {
      case (ControlFlow.Next, let result): return (ControlFlow.Next, result.exit_scope())
      case (ControlFlow.Error, let result): return (ControlFlow.Error, result.exit_scope())
      case (let cf, let result):
        return (
          ControlFlow.Next,
          result.setError(
            error: Error(withMessage: "Invalid control flow \(cf) in conditional statement"))
        )
      }
    } else if let elss = self.elss {
      let execution = execution.enter_scope()
      switch elss.evaluate(execution: execution) {
      case (ControlFlow.Next, let result): return (ControlFlow.Next, result.exit_scope())
      case (ControlFlow.Error, let result): return (ControlFlow.Error, result.exit_scope())
      case (let cf, let result):
        return (
          ControlFlow.Next,
          result.setError(
            error: Error(withMessage: "Invalid control flow \(cf) in conditional statement"))
        )
      }
    }
    return (ControlFlow.Next, execution)
  }
}

extension ExpressionStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {

    // Evaluate, there might be side effects!
    //return switch self.expression.evaluate(execution: execution) {
    return switch execution.evaluator.EvaluateExpression(self.expression, inExecution: execution) {
    case (.Ok(_), let updated_context): (ControlFlow.Next, updated_context)
    case (.Error(let e), let updated_context):
      (ControlFlow.Next, updated_context.setError(error: e))
    }
  }
}

extension ReturnStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    //return switch self.value.evaluate(execution: execution) {
    return switch execution.evaluator.EvaluateExpression(self.value, inExecution: execution) {
    case (.Ok(let v), let execution): (ControlFlow.Return(v), execution)
    case (.Error(let e), let execution): (ControlFlow.Error, execution.setError(error: e))
    }
  }
}

extension ApplyStatement: EvaluatableStatement {
  public func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution) {
    return (ControlFlow.Next, execution)
  }
}
