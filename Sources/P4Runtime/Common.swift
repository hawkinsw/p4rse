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

public func Call<T>(
  body: (ProgramExecution) -> (Result<T>, ProgramExecution), withArguments args: ArgumentList,
  withParameters params: ParameterList, inExecution execution: ProgramExecution
) -> (Result<T>, ProgramExecution) {

  if case .Error(let e) = args.compatible(params) {
    return (.Error(e), execution)
  }

  var called_execution = execution.enter_scope()

  for (parameter, argument) in zip(params.parameters, args.arguments) {
    let arg_idx = argument.index
    let arg_value = argument.argument
    //let maybe_argument_value = arg_value.evaluate(execution: called_execution)
    let maybe_argument_value = EvaluateExpression(arg_value, inExecution: called_execution)
    guard case (.Ok(let argument_value), let updated_execution) = maybe_argument_value else {
      return (
        .Error(Error(withMessage: "Cannot evaluate argument \(arg_idx): \(argument)")),
        called_execution.exit_scope()
      )
    }
    called_execution = updated_execution.declare(
      identifier: parameter.name, withValue: argument_value)
  }

  let (maybe_call_result, updated_execution) = body(called_execution)
  guard case .Ok(let call_result) = maybe_call_result else {
    return (.Error(maybe_call_result.error()!), updated_execution.exit_scope())
  }

  // Before returning, update the (in)out parameters!
  var inout_scopes = updated_execution.exit_scope().scopes

  for (parameter, argument) in zip(params.parameters, args.arguments) {
    if let param_direction = parameter.type.direction(),
      param_direction == Direction.InOut || param_direction == Direction.Out
    {
      // Let's make sure that it is an evaluatable l value!
      guard let arg_lvalue = argument.argument as? EvaluatableLValueExpression else {
        return (
          .Error(Error(withMessage: "(in)out parameter argument is not lvalue")),
          updated_execution.exit_scope()
        )
      }

      guard
        case .Ok(let arg_new_value) = updated_execution.scopes.lookup(identifier: parameter.name)
      else {
        return (
          .Error(Error(withMessage: "Could not get (in)out parameter value from scope")),
          updated_execution.exit_scope()
        )
      }

      switch arg_lvalue.set(
        to: arg_new_value, inScopes: inout_scopes, duringExecution: updated_execution)
      {
      case .Ok((let updated_scopes, _)): inout_scopes = updated_scopes
      case .Error(let e): return (.Error(e), updated_execution.exit_scope())
      }
    }
  }
  return (.Ok(call_result), updated_execution.replaceScopes(inout_scopes))
}

public typealias ExecuteStatementResultHandler = (ControlFlow, ProgramExecution) -> (
  ControlFlow, ProgramExecution
)

public func ExecuteStatement(
  _ statements: [EvaluatableStatement], handleResult handler: ExecuteStatementResultHandler,
  inExecution execution: ProgramExecution,
) -> (ControlFlow, ProgramExecution) {

  var debugger: StatementInterloper? = .none
  var hasDebugInterloper = false
  if let found_deb = execution.getStatementInterloper() {
    debugger = found_deb
    hasDebugInterloper = true
  }

  var execution = execution
  for s in statements {
    let (control_flow, next_execution) = s.evaluate(execution: execution)

    if hasDebugInterloper {
      debugger!(s, control_flow, next_execution)
    }

    switch handler(control_flow, next_execution) {
    case (ControlFlow.Next, let handled_next_execution): execution = handled_next_execution
    case (ControlFlow.Return(let value), let handled_next_execution):
      return (ControlFlow.Return(value), handled_next_execution)
    case (let handled_control_flow, let handled_next_execution):
      return (handled_control_flow, handled_next_execution)
    }
  }
  return (ControlFlow.Next, execution)
}

public func ExecuteStatement(
  _ statement: EvaluatableStatement, handleResult handler: ExecuteStatementResultHandler,
  inExecution execution: ProgramExecution
) -> (ControlFlow, ProgramExecution) {
  return ExecuteStatement([statement], handleResult: handler, inExecution: execution)
}

public func EvaluateExpression(
  _ expression: EvaluatableExpression, inExecution execution: ProgramExecution,
) -> (Result<P4Value>, ProgramExecution) {

  var debugger: ExpressionInterloper? = .none
  var hasDebugInterloper = false
  if let found_deb = execution.getExpressionInterloper() {
    debugger = found_deb
    hasDebugInterloper = true
  }

  let (result, execution) = expression.evaluate(execution: execution)

  if hasDebugInterloper {
    debugger!(expression, result, execution)
  }

  return (result, execution)

}
