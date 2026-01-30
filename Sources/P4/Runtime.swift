// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

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

public class ProgramExecution: CustomStringConvertible {
    public var scopes: Scopes = Scopes()

    public init() {}

    public var description: String {
        return "Runtime:\nScopes: \(scopes)"
    }
}

//public struct ParserRuntime: ProgramRuntime {
public class ParserRuntime: CustomStringConvertible {
    var execution: ParserExecution

    init(execution: ParserExecution) {
        self.execution = execution
    }

    public static func create(program: P4.Parser) -> Result<ParserRuntime> {
        // First, find the start state.
        guard let start_state = program.findStartState() else {
            return Result.Error(Error(withMessage: "Could not find the start state"))
        }
        return Result.Ok(P4.ParserRuntime(execution: P4.ParserExecution(start_state)))
    }

    public func run(input: P4.Packet) -> Result<ParserExecution> {
        execution.scopes.enter()
        while execution.state != P4.accept && execution.state != P4.reject {
            execution = execution.state.evaluate(execution: execution)
        }
        return .Ok(execution)
    }

    public var description: String {
        //return "\(super.description)\nState: \(execution?.description ?? "N/A")\nError: \(error?.description ?? "None")"
        return "Runtime:\nExecution: \(execution)"
    }
}
