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
public class ParserRuntime: CustomStringConvertible {
  public var parser: ParserInstance

  init(execution: ParserInstance) {
    self.parser = execution
  }

  /// Create a parser runtime from a P4 program
  public static func create(program: P4Lang.Program) -> Result<ParserRuntime> {

    return switch program.starting_parser() {
    case .Ok(let parser):
      switch ParserInstance.compile(parser) {
      case .Ok(let execution): .Ok(P4Runtime.ParserRuntime(execution: execution))
      case .Error(let error): .Error(error)
      }
    case .Error(let error): .Error(error)
    }
  }

  /// Run the P4 parser on a given packet
  public func run() -> Result<(ParserState, ProgramExecution)> {
    let (end_state, execution) = parser.execute()
    if let error = execution.getError() {
      return .Error(error)
    }
    return .Ok((end_state, execution))
  }

  public var description: String {
    return "Runtime:\nExecution: \(parser)"
  }
}

/// Instances of parsers are executable
extension ParserInstance: ParserExecution {
  public func execute() -> (ParserState, ProgramExecution) {
    var execution = self as ProgramExecution

    execution = execution.enter_scope()
    // First, add every state to the scope!
    for state in self.states {
      execution = execution.declare(identifier: state.state().state, withValue: state)
    }

    var c = self.start_state

    // Evaluate until the state is either accept or reject.
    while !c.done() && !execution.hasError() {
      (c, execution) = c.execute(program: execution)
    }
    return (c.state(), execution)
  }
}
