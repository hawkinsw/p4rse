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

extension SelectCaseExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    return (execution.scopes.lookup(identifier: next_state_identifier), execution)
  }

  public func type() -> P4Type {
    return P4Type(ParserState())
  }
}

extension SelectExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    switch execution.evaluator.EvaluateExpression(self.selector, inExecution: execution) {
    case (.Ok(let selector_value), let updated_execution):
      for sce in self.case_expressions {
        if case (.Ok(let kse), let updated_execution) = updated_execution.evaluator.EvaluateExpression(
          sce.key, inExecution: updated_execution),
          kse.eq(selector_value)
        {
          //let result = sce.evaluate(execution: updated_execution)
          let result = updated_execution.evaluator.EvaluateExpression(sce, inExecution: updated_execution)
          return result
        }
      }
      return (.Error(Error(withMessage: "No key matched the selector")), updated_execution)
    case (.Error(let e), let updated_execution): return (.Error(e), updated_execution)
    }
  }

  public func type() -> P4Type {
    return P4Type(ParserState())
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension TypedIdentifier: EvaluatableExpression {
  public func type() -> P4Type {
    return self.type
  }

  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    return (execution.scopes.lookup(identifier: self), execution)
  }
}

// Variables are evaluatable because they can be looked up by identifiers.
extension TypedIdentifier: EvaluatableLValueExpression {
  public func set(
    to: P4Value, inScopes scopes: Common.VarValueScopes,
    duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {
    if case .Error(let e) = scopes.lookup(identifier: self) {
      return .Error(e)
    }

    return .Ok((scopes.set(identifier: self, withValue: to), to))
  }

  public func check(
    to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes
  ) -> Result<()> {
    guard case .Ok(let type) = scopes.lookup(identifier: self) else {
      return .Error(Error(withMessage: "Cannot assign to identifier not in scope"))
    }

    return switch type.assignableFromType(to.type()) {
    case TypeCheckResults.IncompatibleTypes:
      .Error(
        Error(
          withMessage:
            "Cannot assign value with type \(to.type()) to identifier \(self) with type \(type)"))
    case TypeCheckResults.ReadOnly:
      .Error(
        Error(
          withMessage:
            "Cannot assign value with type \(to.type()) to identifier \(self) that is read only"))
    case TypeCheckResults.WrongDirection:
      .Error(
        Error(
          withMessage:
            "Cannot assign value with type \(to.type()) to identifier \(self) that is in parameter")
      )
    case TypeCheckResults.Ok: .Ok(())
    }
  }
}

public func binary_equal_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  return Map(input: left.dataValue().eq(rhs: right.dataValue())) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_lt_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  return Map(input: left.dataValue().lt(rhs: right.dataValue())) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_lte_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  return Map(input: left.dataValue().lte(rhs: right.dataValue())) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_gt_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  return Map(input: left.dataValue().gt(rhs: right.dataValue())) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_gte_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  return Map(input: left.dataValue().gte(rhs: right.dataValue())) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_and_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let bleft = left.dataValue() as! P4BooleanValue
  let bright = right.dataValue() as! P4BooleanValue
  return Map(input: bleft.access() && bright.access()) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_or_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let bleft = left.dataValue() as! P4BooleanValue
  let bright = right.dataValue() as! P4BooleanValue
  return Map(input: bleft.access() || bright.access()) { input in
    P4BooleanValue(withValue: input)
  }
}

public func binary_add_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let ileft = left.dataValue() as! P4IntValue
  let iright = right.dataValue() as! P4IntValue
  return Map(input: ileft.access() + iright.access()) { input in
    P4IntValue(withValue: input)
  }
}

public func binary_subtract_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let ileft = left.dataValue() as! P4IntValue
  let iright = right.dataValue() as! P4IntValue
  return Map(input: ileft.access() - iright.access()) { input in
    P4IntValue(withValue: input)
  }
}

public func binary_multiply_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let ileft = left.dataValue() as! P4IntValue
  let iright = right.dataValue() as! P4IntValue
  return Map(input: ileft.access() * iright.access()) { input in
    P4IntValue(withValue: input)
  }
}

public func binary_divide_operator_evaluator(left: P4Value, right: P4Value) -> P4DataValue {
  let ileft = left.dataValue() as! P4IntValue
  let iright = right.dataValue() as! P4IntValue
  return Map(input: ileft.access() / iright.access()) { input in
    P4IntValue(withValue: input)
  }
}

// swift-format-ignore
public typealias BinaryOperatorChecker = (EvaluatableExpression, EvaluatableExpression) -> Result<()>

public func binary_and_or_operator_checker(
  left: EvaluatableExpression, right: EvaluatableExpression
) -> Result<()> {
  // Check that both are Boolean-typed things!
  if !(left.type().dataType().eq(rhs: P4Boolean()) && right.type().dataType().eq(rhs: P4Boolean()))
  {
    return .Error(Error(withMessage: "And/Or on operands with non-bool type is not allowed"))
  }
  return .Ok(())
}

public func binary_int_math_operator_checker(
  left: EvaluatableExpression, right: EvaluatableExpression
) -> Result<()> {
  // Check that both are int-typed things!
  if !(left.type().dataType().eq(rhs: P4Int()) && right.type().dataType().eq(rhs: P4Int())) {
    return .Error(
      Error(withMessage: "Mathematical operation on operands with non-int type is not allowed"))
  }
  return .Ok(())
}

extension BinaryOperatorExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    let updated_execution = execution
    //let maybe_evaluated_left = self.left.evaluate(execution: updated_execution)
    let maybe_evaluated_left = updated_execution.evaluator.EvaluateExpression(self.left, inExecution: updated_execution)
    guard case (.Ok(let evaluated_left), let updated_execution) = maybe_evaluated_left else {
      return maybe_evaluated_left
    }

    //let maybe_evaluated_right = self.right.evaluate(execution: updated_execution)
    let maybe_evaluated_right = updated_execution.evaluator.EvaluateExpression(self.right, inExecution: updated_execution)
    guard case (.Ok(let evaluated_right), let updated_execution) = maybe_evaluated_right else {
      return maybe_evaluated_right
    }

    return (.Ok(P4Value(self.evaluator.2(evaluated_left, evaluated_right))), updated_execution)
  }

  public func type() -> P4Type {
    return self.evaluator.1
  }
}

extension ArrayAccessExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    let updated_execution = execution
    //let maybe_name = self.name.evaluate(execution: updated_execution)
    let maybe_name = updated_execution.evaluator.EvaluateExpression(self.name, inExecution: updated_execution)
    guard case (.Ok(let name), let updated_execution) = maybe_name else {
      return maybe_name
    }

    //let maybe_indexor = self.indexor.evaluate(execution: updated_execution)
    let maybe_indexor = updated_execution.evaluator.EvaluateExpression(self.indexor, inExecution: updated_execution)
    guard case (.Ok(let indexor), let updated_execution) = maybe_indexor else {
      return maybe_indexor
    }

    guard let indexor_int = indexor.dataValue() as? P4IntValue else {
      return (.Error(Error(withMessage: "\(indexor) cannot index an array")), updated_execution)
    }

    guard let array = name.dataValue() as? P4ArrayValue else {
      return (.Error(Error(withMessage: "\(name) does not name an array")), updated_execution)
    }
    let accessed = array.access(indexor_int.access())

    return (.Ok(accessed), updated_execution)
  }

  public func type() -> P4Type {
    return self.type.value_type()
  }
}

extension ArrayAccessExpression: EvaluatableLValueExpression {
  public func set(
    to: P4Value, inScopes scopes: Common.VarValueScopes,
    duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {

    let updated_execution = execution
    //let maybe_value = self.name.evaluate(execution: updated_execution)
    let maybe_value = updated_execution.evaluator.EvaluateExpression(self.name, inExecution: updated_execution)
    guard case (.Ok(let value), let updated_execution) = maybe_value else {
      return .Error(
        Error(withMessage: "\(self.name) cannot be evaluated: \(maybe_value.0.error()!)"))
    }
    guard let array_value = value.dataValue() as? P4ArrayValue else {
      return Result.Error(Error(withMessage: "\(self.name) does not identify an array"))
    }

    // Now, get the indexor!
    //let maybe_indexor_value = self.indexor.evaluate(execution: updated_execution)
    let maybe_indexor_value = updated_execution.evaluator.EvaluateExpression(self.indexor, inExecution: updated_execution)
    guard case (.Ok(let indexor_value), let updated_execution) = maybe_indexor_value else {
      return Result.Error(
        Error(withMessage: "\(self.indexor) cannot be evaluated: \(maybe_indexor_value.0.error()!)")
      )
    }
    guard let indexor_int = indexor_value.dataValue() as? P4IntValue else {
      return Result.Error(Error(withMessage: "\(self.indexor) cannot be used to index an array"))
    }

    // Now we have an array and an index!

    let maybe_updated_array_data_value = array_value.set(index: indexor_int.access(), to: to)
    guard case .Ok(let new_array_value) = maybe_updated_array_data_value else {
      return .Error(maybe_updated_array_data_value.error()!)
    }

    let maybe_updated_array_value = value.update(withNewValue: new_array_value)
    guard case .Ok(let updated_array_value) = maybe_updated_array_value else {
      return .Error(maybe_updated_array_value.error()!)
    }

    let array_lvalue = self.name as! EvaluatableLValueExpression
    return array_lvalue.set(
      to: updated_array_value, inScopes: scopes, duringExecution: updated_execution)
  }

  public func check(
    to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes
  ) -> Common.Result<()> {

    return switch self.type.value_type().assignableFromType(to.type()) {
    case TypeCheckResults.IncompatibleTypes:
      .Error(
        Error(
          withMessage:
            "Cannot assign value of type \(to.type()) to array with values of type \(self.name.type())"
        ))
    case TypeCheckResults.ReadOnly:
      .Error(
        Error(
          withMessage: "Cannot assign value of type \(to.type()) to array \(self) that is read only"
        ))
    case TypeCheckResults.WrongDirection:
      .Error(
        Error(
          withMessage:
            "Cannot assign value of type \(to.type()) to array \(self) that is in parameter"))
    case TypeCheckResults.Ok:
      // Now, check the type of the array itself.
      switch self.name.type().assignable() {
      case TypeCheckResults.ReadOnly:
        .Error(Error(withMessage: "Cannot assign to array \(self) that is read only"))
      case TypeCheckResults.WrongDirection:
        .Error(Error(withMessage: "Cannot assign to array \(self) that is in parameter"))
      case TypeCheckResults.Ok: .Ok(())
      default: .Error(Error(withMessage: "Cannot assign to array \(self)"))
      }
    }
  }
}

extension FieldAccessExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {

    let updated_execution = execution
    //let maybe_struct = self.strct.evaluate(execution: updated_execution)
    let maybe_struct = updated_execution.evaluator.EvaluateExpression(self.strct, inExecution: updated_execution)
    guard case (.Ok(let strct), let updated_execution) = maybe_struct else {
      return maybe_struct
    }

    guard let struct_strct = strct.dataValue() as? P4StructValue else {
      return (.Error(Error(withMessage: "\(strct) does not identify a struct")), updated_execution)
    }

    // TODO: Create a default value?
    guard let value = struct_strct.get(field: self.field) else {
      return (.Error(Error(withMessage: "Missing value")), updated_execution)
    }

    return (.Ok(value), updated_execution)
  }

  public func type() -> P4Type {
    return self.field.type
  }
}

extension FieldAccessExpression: EvaluatableLValueExpression {
  public func set(
    to: P4Value, inScopes scopes: Common.VarValueScopes,
    duringExecution execution: ProgramExecution
  ) -> Common.Result<(Common.VarValueScopes, P4Value)> {
    // For purposes of documentation, assume the field access expression we are evaluating is
    // (strct_id).field_id = new_field_value
    // where strct_id expands to
    // (identifier.field_id1.field_id2...).field_id = new_field_value

    let updated_execution = execution
    // First, evaluate strct_id and make sure that it names a struct.
    //let maybe_value = self.strct.evaluate(execution: updated_execution)
    let maybe_value = updated_execution.evaluator.EvaluateExpression(self.strct, inExecution: updated_execution)
    guard case (.Ok(let value), let updated_execution) = maybe_value else {
      return .Error(
        Error(withMessage: "\(self.strct) cannot be evaluated: \(maybe_value.0.error()!)"))
    }

    guard let struct_value = value.dataValue() as? P4StructValue else {
      return .Error(Error(withMessage: "\(self.strct) does not identify a struct"))
    }

    // Now we know that struct_id identifies a structure value.

    // Update field_id of that structure and get the new structure value.
    let maybe_new_struct_data_value = struct_value.set(field: self.field, to: to)
    guard case .Ok(let new_struct_data_value) = maybe_new_struct_data_value else {
      return .Error(maybe_new_struct_data_value.error()!)
    }

    let maybe_new_struct_value = value.update(withNewValue: new_struct_data_value)
    guard case .Ok(let new_struct_value) = maybe_new_struct_value else {
      return .Error(maybe_new_struct_value.error()!)
    }

    // That new structure value should be assignable to the lvalue that is strct_id.
    // We use recursion here -- ultimately finding our way to a TypedIdentifier that
    // will update the scope. Pretty cool!
    let struct_lvalue = self.strct as! EvaluatableLValueExpression
    return struct_lvalue.set(
      to: new_struct_value, inScopes: scopes, duringExecution: updated_execution)
  }

  public func check(
    to: any Common.EvaluatableExpression, inScopes scopes: Common.VarTypeScopes
  ) -> Common.Result<()> {
    return switch self.field.type().assignableFromType(to.type()) {
    case TypeCheckResults.IncompatibleTypes:
      .Error(
        Error(
          withMessage:
            "Cannot assign value of type \(to.type()) to field \(self.field) of type \(self.type())"
        ))
    case TypeCheckResults.ReadOnly:
      .Error(
        Error(
          withMessage:
            "Cannot assign value of type \(to.type()) to field \(self.field) that is read only"
        ))
    case TypeCheckResults.Ok:
      // Now, check the type of the struct itself.
      switch self.strct.type().assignable() {
      case TypeCheckResults.ReadOnly:
        .Error(
          Error(
            withMessage: "Cannot assign to field \(self.field) of \(self.strct) that is read only"))
      case TypeCheckResults.WrongDirection:
        .Error(
          Error(
            withMessage:
              "Cannot assign to field \(self.field) of \(self.strct) that is in parameter"))
      case TypeCheckResults.Ok: .Ok(())
      default: .Error(Error(withMessage: "Cannot assign to field \(self.field) of \(self.strct)"))
      }
    default: .Error(Error(withMessage: "Cannot assign to field \(self.field) of \(self.strct)"))
    }
  }
}

extension KeysetExpression: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    //return self.key.evaluate(execution: execution)
    return execution.evaluator.EvaluateExpression(self.key, inExecution: execution)
  }

  public func type() -> P4Type {
    return self.key.type()
  }
}

extension FunctionCall: EvaluatableExpression {
  public func evaluate(
    execution: Common.ProgramExecution
  ) -> (Common.Result<P4Value>, ProgramExecution) {

    guard let body = self.callee.body else {
      return (
        .Error(Error(withMessage: "No body for called function (\(self.callee.name))")), execution
      )
    }

    let call_body: (ProgramExecution) -> (Result<P4Value>, ProgramExecution) = {
      (execution: ProgramExecution) in
      let (control_flow, updated_execution) = body.evaluate(execution: execution)
      return switch control_flow {
      case ControlFlow.Return(.some(let value)): (.Ok(value), updated_execution)
      default:
        (
          .Error(
            Error(withMessage: "No value returned from called function (\(self.callee.name))")),
          execution
        )
      }
    }

    return Call(
      body: call_body, withArguments: self.arguments, withParameters: self.callee.params,
      inExecution: execution)
  }

  public func type() -> P4Type {
    return self.callee.tipe
  }
}

extension P4Value: EvaluatableExpression {
  public func evaluate(execution: ProgramExecution) -> (Result<P4Value>, ProgramExecution) {
    return (.Ok(self), execution)
  }
}
