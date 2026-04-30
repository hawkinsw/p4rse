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

/// The runtime for a parser
public struct Runtime<U, T: LibraryCallable<U>>: CustomStringConvertible {
  public var callable: T

  let initialValues: VarValueScopes?

  init(callable: T) {
    self.callable = callable
    self.initialValues = .none
  }

  init(callable: T, withGlobalValues initial: VarValueScopes?) {
    self.callable = callable
    self.initialValues = initial
  }

  /// Create a parser runtime from a P4 program
  public static func create(
    program: P4Lang.Program
  ) -> Result<Runtime<InstantiatedParserState, Parser>> {
    return Runtime.create(program: program, withGlobalValues: .none)
  }

  public static func create(
    program: P4Lang.Program, withGlobalValues initial: VarValueScopes?
  ) -> Result<Runtime<InstantiatedParserState, Parser>> {
    return switch program.starting_parser() {
    case .Ok(let parser):
      .Ok(
        P4Runtime.Runtime<InstantiatedParserState, Parser>(
          callable: parser, withGlobalValues: initial))
    case .Error(let error): .Error(error)
    }
  }

  public static func create(
    control: P4Lang.Control, withGlobalValues initial: VarValueScopes?
  ) -> Result<Runtime<P4TableHitMissValue, Control>> {
    return .Ok(
      P4Runtime.Runtime<P4TableHitMissValue, Control>(callable: control, withGlobalValues: initial))
  }

  /// Run a P4 parser with no arguments
  public func run() -> Result<(U, ProgramExecution)> {
    return self.run(withArguments: ArgumentList([]))

  }

  /// Run the P4 parser on a given packet
  public func run(
    withArguments arguments: ArgumentList, inExecution pe: ProgramExecution = ProgramExecution()
  ) -> Result<(U, ProgramExecution)> {

    let npe =
      if let globals = initialValues {
        pe.setGlobalValues(globals)
      } else {
        pe
      }

    let (end_state, execution) = callable.call(execution: npe, arguments: arguments)
    if let error = execution.getError() {
      return .Error(error)
    }
    return .Ok((end_state, execution))
  }

  public var description: String {
    return "Runtime:\nExecution: \(callable)"
  }
}
