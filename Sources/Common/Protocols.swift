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
    func evaluate(execution: ProgramExecution) -> ValueType
}

public protocol EvaluatableParserStatement {
    /// Evaluate a statement for a given execution
    /// - Parameters
    ///  - execution: The execution context in which to evaluate the parser statement
    /// - Returns: An updated execution after evaluating the parser statement
    func evaluate(execution: ProgramExecution) -> ProgramExecution
}

