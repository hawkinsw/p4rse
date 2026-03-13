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

public struct KeysetExpression {
  public let key: EvaluatableExpression
  public let next_state_identifier: Identifier
  public let next_state: ParserState?

  public init(withKey key: EvaluatableExpression, withNextState next_state_id: Identifier) {
    self.key = key
    self.next_state_identifier = next_state_id
    self.next_state = .none
  }
  public init(
    withKey key: EvaluatableExpression, withNextState next_state_id: Identifier,
    withNextState next_state: ParserState
  ) {
    self.key = key
    self.next_state_identifier = next_state_id
    self.next_state = next_state
  }

}

public struct SelectExpression {
  public let selector: EvaluatableExpression
  public let keyset_expressions: [KeysetExpression]

  public init(
    withSelector selector: EvaluatableExpression, withKeysetExpressions kses: [KeysetExpression]
  ) {
    self.selector = selector
    self.keyset_expressions = kses
  }

  public func append_checked_kse(kse: KeysetExpression) -> SelectExpression {
    var new_kse = self.keyset_expressions
    new_kse.append(kse)
    return SelectExpression(
      withSelector: self.selector, withKeysetExpressions: new_kse)
  }
}

public typealias NamedBinaryOperatorEvaluator = (String, P4Type, (P4Value, P4Value) -> P4Value)
public struct BinaryOperatorExpression {
  public let evaluator: NamedBinaryOperatorEvaluator
  public let left: EvaluatableExpression
  public let right: EvaluatableExpression

  public init(
    withEvaluator evaluator: NamedBinaryOperatorEvaluator, withLhs lhs: EvaluatableExpression,
    withRhs rhs: EvaluatableExpression
  ) {
    self.evaluator = evaluator
    self.left = lhs
    self.right = rhs
  }
}