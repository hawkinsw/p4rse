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

public typealias ExecuteStatementResultHandlerT = (ControlFlow, ProgramExecution) -> (
  ControlFlow, ProgramExecution
)

public typealias ExecuteStatementT = (EvaluatableStatement, ProgramExecution) -> (
  ControlFlow, ProgramExecution
)

func CanonicalExecuteStatements(
  _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution,
  _ executor: ExecuteStatementT
) -> (ControlFlow, ProgramExecution) {
  var execution = execution
  for s in statements {
    // Execute the statement with the user-provided statement executor.
    switch executor(s, execution) {
    // And decide what to do next!
    case (ControlFlow.Next, let handled_next_execution): execution = handled_next_execution
    case (ControlFlow.Return(let value), let handled_next_execution):
      return (ControlFlow.Return(value), handled_next_execution)
    case (let handled_control_flow, let handled_next_execution):
      return (handled_control_flow, handled_next_execution)
    }
  }
  return (ControlFlow.Next, execution)
}

public struct ClassicEvaluator: ProgramExecutionEvaluator {
  public func ExecuteStatements(
    _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution,
    _ handler: ExecuteStatementResultHandlerT?
  ) -> (ControlFlow, ProgramExecution) {

    return CanonicalExecuteStatements(statements, inExecution: execution) { statement, execution in
      let (cf, value) = statement.evaluate(execution: execution)
      // Apply the user-specified handler before continuing.
      guard let handler = handler else {
        return (cf, value)
      }
      return handler(cf, value)
    }
  }

  public func EvaluateExpression(
    _ expression: EvaluatableExpression, inExecution execution: ProgramExecution,
  ) -> (Result<P4Value>, ProgramExecution) {
    return expression.evaluate(execution: execution)
  }
}

public struct InterloperEvaluator: ProgramExecutionEvaluator {
  var statement_interloper: StatementInterloper?
  var expression_interloper: ExpressionInterloper?

  public init() {}

  public func getStatementInterloper() -> StatementInterloper? {
    return self.statement_interloper
  }

  public func setStatementInterloper(
    _ interloper: @escaping StatementInterloper
  ) -> InterloperEvaluator {
    var pe = self
    pe.statement_interloper = interloper
    return pe
  }

  public func getExpressionInterloper() -> ExpressionInterloper? {
    return self.expression_interloper
  }

  public func setExpressionInterloper(
    _ interloper: @escaping ExpressionInterloper
  ) -> InterloperEvaluator {
    var pe = self
    pe.expression_interloper = interloper
    return pe
  }

  public func ExecuteStatements(
    _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution,
    _ handler: ExecuteStatementResultHandlerT?
  ) -> (ControlFlow, ProgramExecution) {

    var debugger: StatementInterloper? = .none
    var hasDebugInterloper = false
    if let found_deb = self.getStatementInterloper() {
      debugger = found_deb
      hasDebugInterloper = true
    }

    return CanonicalExecuteStatements(statements, inExecution: execution) { statement, execution in
      let (cf, value) = statement.evaluate(execution: execution)
      let (handled_cf, handled_value) =
        if let handler = handler {
          handler(cf, value)
        } else {
          (cf, value)
        }

      if hasDebugInterloper {
        debugger!(statement, handled_cf, handled_value)
      }
      return (handled_cf, handled_value)
    }
  }

  public func EvaluateExpression(
    _ expression: EvaluatableExpression, inExecution execution: ProgramExecution,
  ) -> (Result<P4Value>, ProgramExecution) {

    var debugger: ExpressionInterloper? = .none
    var hasDebugInterloper = false
    if let found_deb = self.getExpressionInterloper() {
      debugger = found_deb
      hasDebugInterloper = true
    }

    let (result, execution) = expression.evaluate(execution: execution)

    if hasDebugInterloper {
      debugger!(expression, result, execution)
    }

    return (result, execution)

  }
}

public typealias StatementInterloper = (EvaluatableStatement, ControlFlow, ProgramExecution) -> Void
public typealias ExpressionInterloper = (EvaluatableExpression, Result<P4Value>, ProgramExecution)
  -> Void

open class ProgramExecution: CustomStringConvertible {
  public var scopes: VarValueScopes = VarValueScopes()
  var globalValues: VarValueScopes?
  var error: (any Errorable)?
  var debug: DebugLevel = DebugLevel.Error
  public let evaluator: ProgramExecutionEvaluator

  init(copy: ProgramExecution) {
    self.scopes = copy.scopes
    self.globalValues = copy.globalValues
    self.error = copy.error
    self.debug = copy.debug
    self.evaluator = copy.evaluator
  }

  public init() {
    globalValues = .none
    evaluator = ClassicEvaluator()
  }

  public init(_ evaluator: ProgramExecutionEvaluator) {
    globalValues = .none
    self.evaluator = evaluator
  }

  open var description: String {
    return "Runtime:\nScopes: \(scopes)"
  }

  public func hasError() -> Bool {
    return self.error != nil
  }

  public func getError() -> (any Errorable)? {
    return self.error
  }

  public func setError(error: any Errorable) -> ProgramExecution {
    let npe = ProgramExecution(copy: self)
    npe.error = error
    return npe
  }

  public func getDebugLevel() -> DebugLevel {
    return self.debug
  }

  public func setDebugLevel(_ dl: DebugLevel) -> ProgramExecution {
    let pe = ProgramExecution(copy: self)
    pe.debug = dl
    return pe
  }

  open func isDone() -> Bool {
    return false
  }

  open func setDone() -> ProgramExecution {
    // For a bare ProgramExecution, setDone is a noop.
    return self
  }

  public func enter_scope() -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_pe.scopes.enter()

    return new_pe
  }

  public func exit_scope() -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_pe.scopes.exit()

    return new_pe
  }

  public func replaceScopes(_ new_scopes: VarValueScopes) -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.scopes = new_scopes
    return new_pe
  }

  public func declare(identifier: Identifier, withValue value: P4Value) -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    let new_scopes = new_pe.scopes.declare(identifier: identifier, withValue: value)

    new_pe.scopes = new_scopes
    return new_pe
  }

  public func getGlobalValues() -> VarValueScopes {
    return self.globalValues ?? VarValueScopes()
  }

  public func setGlobalValues(_ global_values: VarValueScopes) -> ProgramExecution {
    let new_pe = ProgramExecution(copy: self)
    new_pe.globalValues = global_values
    return new_pe
  }

}

/// A scope that resolves variable identifiers to their values.
public typealias VarValueScope = Scope<P4Value>

/// Scopes that resolves variable identifiers to their values.
public typealias VarValueScopes = Scopes<P4Value>

/// Indicate the control flow result of a particular statement.
public enum ControlFlow {
  case Next
  case Continue
  case Break
  case Return(P4Value?)
  case Error
}
