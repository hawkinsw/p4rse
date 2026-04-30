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

extension Control: LibraryCallable {
  public typealias T = P4TableHitMissValue
  public func call(
    execution: Common.ProgramExecution, arguments: ArgumentList
  ) -> (P4TableHitMissValue, Common.ProgramExecution) {

    var control_execution = execution.enter_scope()

    // Add initial values to the global scope
    for (name, value) in execution.getGlobalValues() {
      control_execution = control_execution.declare(identifier: name, withValue: value)
    }

    let call_body: (ProgramExecution) -> (Result<P4TableHitMissValue>, ProgramExecution) = {
      execution in
      var control_execution = execution

      for action in self.actions.actions {
        control_execution = control_execution.declare(
          identifier: action.name, withValue: P4Value(action))
      }

      for key in self.table.properties.keys.keys {
        // Every evaluation of the key starts from an unchanged execution context.
        let (key_eval, updated_execution) = key.key.evaluate(execution: control_execution)

        guard case .Ok(let key_val) = key_eval else {
          return (.Error(key_eval.error()!), updated_execution)
        }

        /// ASSUME: The first matching entry is the one to do.
        /// TODO: Check whether this matches architecture.
        for (val, action) in self.table.entries {

          // Skip those with mismatching types.

          if !val.type().eq(key_val.type()) {
            continue;
          }

          /// ASSUME: All matches are exact.
          if val.eq(key_val) {
            // Lookup action!

            let maybe_action = updated_execution.scopes.lookup(identifier: action)
            guard case .Ok(let action) = maybe_action else {
              return (.Error(maybe_action.error()!), updated_execution)
            }

            let aaction = (action.dataValue() as! Action)

            return switch aaction.evaluate(execution: updated_execution) {
            case (ControlFlow.Error, let updated_execution):
              (.Error(updated_execution.getError()!), updated_execution)
            case (_, let updated_execution): (.Ok(P4TableHitMissValue.Hit), updated_execution)
            }
          }
        }
      }
      return (.Ok(P4TableHitMissValue.Miss), control_execution)
    }

    switch Call(body: call_body, withArguments: arguments, withParameters: self.parameters, inExecution: control_execution) {
      case (.Ok(let r), let updated_execution): return (r, updated_execution)
      case (.Error(let e), let updated_execution): return (P4TableHitMissValue.Miss, updated_execution.setError(error: e))
    }
  }
}

extension Action: EvaluatableStatement {
  public func evaluate(
    execution: Common.ProgramExecution
  ) -> (Common.ControlFlow, Common.ProgramExecution) {
    if let body = self.body {
      return body.evaluate(execution: execution)
    }

    return (ControlFlow.Next, execution)
  }
}
