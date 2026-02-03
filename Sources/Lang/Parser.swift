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

public struct LocalElements {

}

public struct LocalElement {

}

public struct ParserTransitionStatement {
  public init() {}
}

public struct VariableDeclarationStatement {
  public var variable: Variable
  public init(withVariable variable: Variable) {
    self.variable = variable
  }
}

public struct ExpressionStatement {
  public init() {}
}

public struct ParserState: Equatable, CustomStringConvertible {

  public private(set) var state_name: String
  public private(set) var local_elements: [EvaluatableParserStatement]
  public private(set) var statements: [EvaluatableParserStatement]
  public private(set) var transition: ParserTransitionStatement?

  public var description: String {
    return "Name: \(state_name)"
  }

  public static func == (lhs: ParserState, rhs: ParserState) -> Bool {
    return lhs.state_name == rhs.state_name
  }

  /// Construct a ParserState
  public init(
    name: String, withLocalElements localElements: [EvaluatableParserStatement]?,
    withStatements statements: [EvaluatableParserStatement]?,
    withTransition transitionStatement: ParserTransitionStatement
  ) {
    state_name = name
    transition = transitionStatement
    local_elements = localElements ?? Array()
    self.statements = statements ?? Array()
  }

  /// (private) constructor (no transition)
  ///
  /// accept and reject are the only final states and they are constructed internally.
  init(name: String) {
    state_name = name
    transition = .none
    local_elements = Array()
    statements = Array()
  }
}

public struct ParserStates {
  public var states: [ParserState] = Array()
}

nonisolated(unsafe) public let accept: ParserState = ParserState(name: "accept")
nonisolated(unsafe) public let reject: ParserState = ParserState(name: "reject")

public struct Parser {
  public var states: [ParserState] = Array()
  public var count: Int {
    states.count
  }

  public init() {}

  public func findStartState() -> ParserState? {
    for state in states {
      if state.state_name == "start" {
        return state
      }
    }
    return .none
  }
}

public class ParserExecution: ProgramExecution {

    private init(state: ParserState) {
      self.state = state
      super.init()
    }

    public static func create(_ parser: Parser) -> Result<ParserExecution> {
        guard let start_state = parser.findStartState() else {
            return Result.Error(Error(withMessage: "Could not find the start state"))
        }
        let new = ParserExecution(state: start_state)

        return Result.Ok(new)
    }

    public var state: ParserState

    public func transition(toNextState state: ParserState) -> ParserExecution {
        let next = self
        next.state = state
        return next
    }

    public override var description: String {
        return "Execution: \(super.description)\nCurrent State: \(state)"
    }
}