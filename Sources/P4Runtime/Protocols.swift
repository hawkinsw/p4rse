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

protocol EvaluatableParserTransition {
  func program(execution: ProgramExecution) -> (ParserState, ProgramExecution)
}

protocol EvaluatableParserTransitionStatement {
  func transition(execution: ProgramExecution) -> (ParserState, ProgramExecution)
}

public protocol Execution {
    func execute() -> (ParserState, ProgramExecution)
}

public protocol Compilable {
  associatedtype ToCompile
  associatedtype Compiled
  static func compile(_: ToCompile) -> Result<Compiled>
}

public protocol ParserStateInstance {
    func execute(program: ProgramExecution) -> (ParserStateInstance, ProgramExecution)
    func done() -> Bool
    func current() -> ParserState
}

public protocol ParserExecution {
    func execute() -> (ParserState, ProgramExecution)
}