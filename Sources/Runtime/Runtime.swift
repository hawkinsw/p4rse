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
import Lang

/// The runtime for a parser
public class ParserRuntime: CustomStringConvertible {
  var parser: ParserInstance

  init(execution: ParserInstance) {
    self.parser = execution
  }

  /// Create a parser runtime from a P4 program
  public static func create(program: Lang.Program) -> Result<ParserRuntime> {

    return switch program.starting_parser() {
    case .Ok(let parser):
      switch ParserInstance.create(parser) {
      case .Ok(let execution): .Ok(Runtime.ParserRuntime(execution: execution))
      case .Error(let error): .Error(error)
      }
    case .Error(let error): .Error(error)
    }
  }

  /// Run the P4 parser on a given packet
  public func run(input: Packet) -> Result<(ParserState, ProgramExecution)> {
    parser.scopes.enter()
    return .Ok(parser.execute())
  }

  public var description: String {
    return "Runtime:\nExecution: \(parser)"
  }
}

/// Instances of parsers are executable
extension ParserInstance: Execution {
  public func execute() -> (ParserState, ProgramExecution) {
    var execution = self as ProgramExecution
    var state = self.state

    // Evaluate until the state is either accept or reject.
    while state != accept && state != reject {
      (state, execution) = state.evaluate(execution: execution)
    }
    return (state, execution)
  }
}
