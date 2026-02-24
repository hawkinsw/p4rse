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

public struct VariableDeclarationStatement {
  public var initializer: EvaluatableExpression
  public var identifier: Identifier
  public init(identifier: Identifier, withInitializer initializer: EvaluatableExpression) {
    self.identifier = identifier
    self.initializer = initializer
  }
}

public struct ConditionalStatement {
  public var condition: EvaluatableExpression
  public var thenn: EvaluatableStatement
  public var elss: EvaluatableStatement?

  public init(condition: EvaluatableExpression, withThen thenn: EvaluatableStatement) {
    self.condition = condition
    self.thenn = thenn
    self.elss = .none
  }

  public init(condition: EvaluatableExpression, withThen thenn: EvaluatableStatement, andElse elss: EvaluatableStatement) {
    self.condition = condition
    self.thenn = thenn
    self.elss = elss
  }
}

public struct BlockStatement {
  public var statements: [EvaluatableStatement]

  public init(_ statements: [EvaluatableStatement]) {
    self.statements = statements
  }

}