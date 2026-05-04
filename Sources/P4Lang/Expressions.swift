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

  public init(_ key: EvaluatableExpression) {
    self.key = key
  }

  public func compatible(type: P4QualifiedType) -> Result<()> {
    if let key_type = self.key.type().baseType() as? P4Set {
      if !key_type.set_type().eq(type) {
        return .Error(
          Error(
            withMessage:
              "Key expression of type set of type \(key_type.set_type()) is not compatible with selector type \(type)"
          ))
      }
    } else if !self.key.type().eq(type) {
      return .Error(
        Error(
          withMessage:
            "Key expression of type \(self.key.type()) is not compatible with selector type \(type)"
        ))
    }
    return .Ok(())
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
}

public struct SelectExpression {
  public let selector: EvaluatableExpression
  public let case_expressions: [SelectCaseExpression]

  public init(
    withSelector selector: EvaluatableExpression,
    withSelectCaseExpressions sces: [SelectCaseExpression]
  ) {
    self.selector = selector
    self.case_expressions = sces
  }

  public func append_checked_sce(sce: SelectCaseExpression) -> SelectExpression {
    var new_cses = self.case_expressions
    new_cses.append(sce)
    return SelectExpression(
      withSelector: self.selector, withSelectCaseExpressions: new_cses)
  }
}

public typealias NamedBinaryOperatorEvaluator = (String, P4QualifiedType, (P4Value, P4Value) -> P4DataValue)
public typealias BinaryOperatorEvaluator = (P4Value, P4Value) -> P4DataValue

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

public struct FunctionCall {
  public let callee: (FunctionDeclaration?, P4FFI?)
  public let arguments: ArgumentList
  public let return_type: P4DataType

  public init(_ callee: FunctionDeclaration, withArguments arguments: ArgumentList) {
    self.callee = (callee, .none)
    self.arguments = arguments
    self.return_type = callee.tipe.baseType()
  }

  public init(_ callee: P4FFI, withArguments arguments: ArgumentList) {
    self.callee = (.none, callee)
    self.arguments = arguments
    /// ASSUME: That the FFI has been checked and the type is always a function declaration.
    self.return_type = (callee.type().baseType() as! FunctionDeclaration).tipe.baseType()
  }
}
