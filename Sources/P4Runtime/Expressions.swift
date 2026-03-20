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

extension KeysetExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    return execution.scopes.lookup(identifier: next_state_identifier)
  }

  public func type() -> any Common.P4Type {
    // TODO
    return reject
  }
}

extension SelectExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    switch self.selector.evaluate(execution: execution) {
    case .Ok(let selector_value):
      for kse in self.keyset_expressions {
        if case .Ok(let kse_key) = kse.key.evaluate(execution: execution),
          kse_key.eq(rhs: selector_value)
        {
          let result = kse.evaluate(execution: execution)
          return result
        }
      }
      return .Error(Error(withMessage: "No key matched the selector"))
    case .Error(let e): return .Error(e)
    }
  }

  // TODO
  public func type() -> any Common.P4Type {
    return reject
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension TypedIdentifier: EvaluatableExpression {
  public func type() -> any Common.P4Type {
    return self.type
  }

  public func evaluate(execution: Common.ProgramExecution) -> Result<P4Value> {
    return execution.scopes.lookup(identifier: self)
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension TypedIdentifier: EvaluatableLValueExpression {
  public func set(
    to: any Common.P4Value, inScopes scopes: Common.VarValueScopes, duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {
    if case .Error(let e) = scopes.lookup(identifier: self) {
      return .Error(e)
    }

    return .Ok((scopes.set(identifier: self, withValue: to), to))
  }

  public func check(to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes) -> Result<()> {
    guard case .Ok(let type) = scopes.lookup(identifier: self) else {
      return .Error(Error(withMessage: "Cannot assign to identifier not in scope"))
    }

    if !type.eq(rhs: to.type()) {
      return .Error(Error(withMessage: "Cannot assign value with type \(to.type()) to identifier \(self) with type \(type)"))
    }
    return .Ok(())
  }
}

public func binary_equal_operator_evaluator(left: P4Value, right: P4Value) -> P4Value {
  if left.eq(rhs: right) {
    return P4BooleanValue(withValue: true)
  }
  return P4BooleanValue(withValue: false)
}

extension BinaryOperatorExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    let maybe_evaluated_left = self.left.evaluate(execution: execution)
    guard case Result.Ok(let evaluated_left) = maybe_evaluated_left else {
      return maybe_evaluated_left
    }

    let maybe_evaluated_right = self.right.evaluate(execution: execution)
    guard case Result.Ok(let evaluated_right) = maybe_evaluated_right else {
      return maybe_evaluated_right
    }

    return Result.Ok(self.evaluator.2(evaluated_left, evaluated_right))
  }

  public func type() -> any Common.P4Type {
    return self.evaluator.1
  }
}

extension ArrayAccessExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    let maybe_name = self.name.evaluate(execution: execution)
    guard case Result.Ok(let name) = maybe_name else {
      return maybe_name
    }

    let maybe_indexor = self.indexor.evaluate(execution: execution)
    guard case Result.Ok(let indexor) = maybe_indexor else {
      return maybe_indexor
    }

    guard let indexor_int = indexor as? P4IntValue else {
      return Result.Error(Error(withMessage: "\(indexor) cannot index an array"))
    }

    guard let array = name as? P4ArrayValue else {
      return Result.Error(Error(withMessage: "\(name) does not name an array"))
    }
    let accessed = array.access(indexor_int.access())

    return .Ok(accessed)
  }

  public func type() -> any Common.P4Type {
    return self.type.value_type()
  }
}

extension ArrayAccessExpression: EvaluatableLValueExpression {
  public func set(
    to: any Common.P4Value, inScopes scopes: Common.VarValueScopes, duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {
    // For purposes of documentation, assume the field access expression we are evaluating is
    // (strct_id)[indexor] = new_value
    // where strct_id expands to
    // (identifier.field_id1.field_id2...).field_id = new_field_value

    // First, evaluate strct_id and make sure that it names a struct.
    let maybe_value = self.name.evaluate(execution: execution)
    guard case .Ok(let value) = maybe_value else {
        return Result.Error(Error(withMessage: "\(self.name) cannot be evaluated: \(maybe_value.error()!)"))
    }
    guard let array_value = value as? P4ArrayValue else {
        return Result.Error(Error(withMessage: "\(self.name) does not identify a struct"))
    }

    // Now, get the indexor!
    let maybe_indexor_value = self.indexor.evaluate(execution: execution)
    guard case .Ok(let indexor_value) = maybe_indexor_value else {
        return Result.Error(Error(withMessage: "\(self.indexor) cannot be evaluated: \(maybe_indexor_value.error()!)"))
    }
    guard let indexor_int = indexor_value as? P4IntValue else {
        return Result.Error(Error(withMessage: "\(self.indexor) cannot be used to index an array"))
    }

    // Now we have an array and an index!

    // Update field_id of that structure and get the new structure value.
    let set_result = array_value.set(index: indexor_int.access(), to: to)
    guard case .Ok(let new_array_value) = set_result else {
      return .Error(set_result.error()!)
    }

    let array_lvalue = self.name as! EvaluatableLValueExpression
    return array_lvalue.set(to: new_array_value, inScopes: scopes, duringExecution: execution)
  }

  public func check(
    to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes
  ) -> Common.Result<()> {

    if !self.type.value_type().eq(rhs: to.type()) {
      return .Error(Error(withMessage: "Cannot assign value of type \(to.type()) to array with values of type \(self.name.type())"))
    }
    return .Ok(())
  }
}

extension FieldAccessExpression: EvaluatableExpression {
  public func evaluate(execution: Common.ProgramExecution) -> Common.Result<any Common.P4Value> {
    let maybe_struct = self.strct.evaluate(execution: execution)
    guard case Result.Ok(let strct) = maybe_struct else {
      return maybe_struct
    }

    guard let struct_strct = strct as? P4StructValue else {
      return Result.Error(Error(withMessage: "\(strct) does not identify a struct"))
    }

    // TODO: Create a default value?
    guard let value = struct_strct.get(field: self.field) else {
      return .Error(Error(withMessage: "Missing value"))
    }

    return .Ok(value)
  }

  public func type() -> any Common.P4Type {
    return self.field.type
  }
}

extension FieldAccessExpression: EvaluatableLValueExpression {
  public func set(
    to: any Common.P4Value, inScopes scopes: Common.VarValueScopes, duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {
    // For purposes of documentation, assume the field access expression we are evaluating is
    // (strct_id).field_id = new_field_value
    // where strct_id expands to
    // (identifier.field_id1.field_id2...).field_id = new_field_value

    // First, evaluate strct_id and make sure that it names a struct.
    let maybe_value = self.strct.evaluate(execution: execution)
    guard case .Ok(let value) = maybe_value else {
        return Result.Error(Error(withMessage: "\(self.strct) cannot be evaluated: \(maybe_value.error()!)"))
    }

    guard let struct_value = value as? P4StructValue else {
        return Result.Error(Error(withMessage: "\(self.strct) does not identify a struct"))
    }

    // Now we know that struct_id identifies a structure value.

    // Update field_id of that structure and get the new structure value.
    let set_result = struct_value.set(field: self.field, to: to)
    guard case .Ok(let new_struct_value) = set_result else {
      return .Error(set_result.error()!)
    }

    // That new structure value should be assignable to the lvalue that is strct_id.
    // We use recursion here -- ultimately finding our way to a TypedIdentifier that
    // will update the scope. Pretty cool!
    let struct_lvalue = self.strct as! EvaluatableLValueExpression
    return struct_lvalue.set(to: new_struct_value, inScopes: scopes, duringExecution: execution)
  }

  public func check(
    to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes
  ) -> Common.Result<()> {

    if !self.field.type.eq(rhs:to.type()) {
      return .Error(Error(withMessage: "Cannot assign value of type \(to.type()) to field with type \(self.field.type)"))
    }
    return .Ok(())
  }
}