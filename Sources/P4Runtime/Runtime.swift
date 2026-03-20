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
public struct ParserRuntime: CustomStringConvertible {
  public var parser: Parser

  let initialValues: VarValueScopes?

  init(parser: Parser) {
    self.parser = parser
    self.initialValues = .none
  }

  init(parser: Parser, withInitialValues initial: VarValueScopes?) {
    self.parser = parser
    self.initialValues = initial
  }

  /// Create a parser runtime from a P4 program
  public static func create(program: P4Lang.Program) -> Result<ParserRuntime> {
    return ParserRuntime.create(program: program, withInitialValues: .none)
  }

  public static func create(
    program: P4Lang.Program, withInitialValues initial: VarValueScopes?
  ) -> Result<ParserRuntime> {
    return switch program.starting_parser() {
    case .Ok(let parser):
      .Ok(P4Runtime.ParserRuntime(parser: parser, withInitialValues: initial))
    case .Error(let error): .Error(error)
    }
  }

  /// Run the P4 parser on a given packet
  public func run() -> Result<(ParserState, ProgramExecution)> {

    let pe =
      if let initial = initialValues {
        ProgramExecution(withGlobalValues: initial)
      } else {
        ProgramExecution()
      }

    let (end_state, execution) = parser.execute(execution: pe)
    if let error = execution.getError() {
      return .Error(error)
    }
    return .Ok((end_state, execution))
  }

  public var description: String {
    return "Runtime:\nExecution: \(parser)"
  }
}
