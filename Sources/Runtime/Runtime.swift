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

public class ParserRuntime: CustomStringConvertible {
  var execution: ParserExecution

  init(execution: ParserExecution) {
    self.execution = execution
  }

  public static func create(program: Lang.Parser) -> Result<ParserRuntime> {
    switch ParserExecution.create(program) {
    case .Ok(let execution): return .Ok(Runtime.ParserRuntime(execution: execution))
    case .Error(let error): return .Error(error)

    }
  }

  public func run(input: Packet) -> Result<(ParserState, ProgramExecution)> {
    execution.scopes.enter()
    return .Ok(execution.execute())
  }

  public var description: String {
    //return "\(super.description)\nState: \(execution?.description ?? "N/A")\nError: \(error?.description ?? "None")"
    return "Runtime:\nExecution: \(execution)"
  }
}

extension ParserExecution: Execution {
  public func execute() -> (ParserState, ProgramExecution) {
    var execution = self as ProgramExecution
    var state = self.state

    // Evaluate until the state is either accept or reject.
    while state != accept && state != reject {
      (state, execution) = self.state.evaluate(execution: execution)
    }
    return (state, execution)
  }
}
