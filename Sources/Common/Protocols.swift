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

public protocol EvaluatableExpression {
  /// Evaluate an expression for a given execution
  /// - Parameters
  ///  - execution: The execution context in which to evaluate the expression
  /// - Returns: The value of expression
  func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution)
  func type() -> P4QualifiedType
}

public protocol EvaluatableStatement {
  /// Evaluate a statement for a given execution
  /// - Parameters
  ///  - execution: The execution context in which to evaluate the parser statement
  /// - Returns: A tuple of
  /// 1. Whether this statement affects control flow.
  /// 2. An updated execution after evaluating the parser statement
  func evaluate(execution: ProgramExecution) -> (ControlFlow, ProgramExecution)
}

public protocol P4DataType: CustomStringConvertible {
  func eq(rhs: any P4DataType) -> Bool
  func def() -> P4DataValue
}

public protocol P4DataValue: CustomStringConvertible {
  func type() -> any P4DataType
  func eq(rhs: P4DataValue) -> Bool
  func lt(rhs: P4DataValue) -> Bool
  func lte(rhs: P4DataValue) -> Bool
  func gt(rhs: P4DataValue) -> Bool
  func gte(rhs: P4DataValue) -> Bool
}

public protocol EvaluatableLValueExpression: EvaluatableExpression {
  func set(
    to: P4Value, inScopes scopes: VarValueScopes, duringExecution execution: ProgramExecution
  ) -> Result<(VarValueScopes, P4Value)>
  func check(to: EvaluatableExpression, inScopes scopes: VarTypeScopes) -> Result<()>
}

public protocol ProgramExecutionEvaluator {
  func ExecuteStatements(
    _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution,
    _ handler: ExecuteStatementResultHandlerT?
  ) -> (ControlFlow, ProgramExecution)

  func ExecuteStatements(
    _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution
  ) -> (ControlFlow, ProgramExecution)

  func EvaluateExpression(
    _ expression: EvaluatableExpression, inExecution execution: ProgramExecution,
  ) -> (Result<P4Value>, ProgramExecution)
}

extension ProgramExecutionEvaluator {
  public func ExecuteStatements(
    _ statements: [EvaluatableStatement], inExecution execution: ProgramExecution
  ) -> (ControlFlow, ProgramExecution) {
    return ExecuteStatements(statements, inExecution: execution, .none)
  }
}
