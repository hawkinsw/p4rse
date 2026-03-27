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

public class KeysetExpression {
  public func update_type(to: P4Type) -> Result<KeysetExpression> {
    return .Ok(self)
  }

  public func kse_evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return .Error(Error(withMessage: "Missing key in keyset expression"))
  }

  public func kse_type() -> P4Type {
    return P4Boolean()
  }
}

public class NonDefaultKeysetExpression: KeysetExpression {
  public let key: EvaluatableExpression

  public init(_ key: EvaluatableExpression) {
    self.key = key
  }

  // Some keyset expressions need additional
  // context about their types -- e.g., default.
  // Override to update and return true if the
  // update is safe.
  public override func update_type(to: P4Type) -> Result<KeysetExpression> {
    // In the default case, if the current key type
    // does not match the updated type, that's an
    // error.
    return Map(input: key.type().eq(rhs: to)) { input in
      input
        ? .Ok(self)
        : .Error(
          Error(withMessage: "Keyset expression type does not match selector expression type"))
    }
  }

  public override func kse_evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return self.key.evaluate(execution: execution)
  }

  public override func kse_type() -> P4Type {
    return self.key.type()
  }

}

public class DefaultKeysetExpression: KeysetExpression {
  let type: P4Type

  public init(withType type: P4Type) {
    self.type = type
  }

  public override func update_type(to: P4Type) -> Result<KeysetExpression> {
    return Map(input: type.eq(rhs: to)) { input in
      input
        ? .Ok(DefaultKeysetExpression(withType: to))
        : .Error(
          Error(withMessage: "Keyset expression type does not match selector expression type"))
    }
  }

  public override func kse_evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return .Ok(P4SetDefaultValue(withType: self.type))
  }

  public override func kse_type() -> P4Type {
    return P4Set(withSetType: self.type)
  }
}

public class PlaceholderDefaultKeysetExpression: KeysetExpression {
  public override init() {}

  public override func update_type(to: P4Type) -> Result<KeysetExpression> {
    .Ok(DefaultKeysetExpression(withType: to))
  }

  public override func kse_evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return .Error(Error(withMessage: "Cannot evaluate a placeholder default keyset expression"))
  }

  public override func kse_type() -> P4Type {
    return P4Set(withSetType: P4Boolean())
  }
}

public struct SelectCaseExpression {
  public let key: KeysetExpression
  public let next_state_identifier: Identifier
  public let next_state: ParserState?

  public init(withKey key: KeysetExpression, withNextState next_state_id: Identifier) {
    self.key = key
    self.next_state_identifier = next_state_id
    self.next_state = .none
  }
  public init(
    withKey key: KeysetExpression, withNextState next_state_id: Identifier,
    withNextState next_state: ParserState?
  ) {
    self.key = key
    self.next_state_identifier = next_state_id
    self.next_state = next_state
  }

  // Some keyset expressions need additional
  // context about their types -- e.g., default.
  // Override to update and return true if the
  public func update_type(to: P4Type) -> Result<SelectCaseExpression> {
    switch key.update_type(to: to) {
    case .Ok(let new_kse):
      .Ok(
        SelectCaseExpression(
          withKey: new_kse, withNextState: self.next_state_identifier,
          withNextState: self.next_state))
    case .Error(let e): .Error(e)
    }
  }
}

public struct SelectExpression {
  public let selector: EvaluatableExpression
  public let select_expressions: [SelectCaseExpression]

  public init(
    withSelector selector: EvaluatableExpression,
    withSelectCaseExpressions sces: [SelectCaseExpression]
  ) {
    self.selector = selector
    self.select_expressions = sces
  }

  public func append_checked_sce(sce: SelectCaseExpression) -> SelectExpression {
    var new_cses = self.select_expressions
    new_cses.append(sce)
    return SelectExpression(
      withSelector: self.selector, withSelectCaseExpressions: new_cses)
  }
}

public typealias NamedBinaryOperatorEvaluator = (String, P4Type, (P4Value, P4Value) -> P4Value)
public typealias BinaryOperatorEvaluator = (P4Value, P4Value) -> P4Value
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

public struct ArrayAccessExpression {
  public let indexor: EvaluatableExpression
  public let name: EvaluatableExpression
  public let type: P4Array

  public init(
    withName name: EvaluatableExpression, withType type: P4Array,
    withIndexor indexor: EvaluatableExpression
  ) {
    self.name = name
    self.type = type
    self.indexor = indexor
  }
}

public struct FieldAccessExpression {
  public let field: P4StructFieldIdentifier
  public let strct: EvaluatableExpression

  public init(withStruct strct: EvaluatableExpression, withField field: P4StructFieldIdentifier) {
    self.strct = strct
    self.field = field
  }
}
