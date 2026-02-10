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

import Lang
import Common

extension VariableDeclarationStatement: EvaluatableParserStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    let new_scopes = execution.scopes.declare(variable: self.variable)
    execution.scopes = new_scopes
    return execution
  }
}

extension ExpressionStatement: EvaluatableParserStatement {
  public func evaluate(execution: ProgramExecution) -> ProgramExecution {
    return execution
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension Identifier: EvaluatableExpression {
    public func evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
      return execution.scopes.evaluate(identifier: self)
    }
}