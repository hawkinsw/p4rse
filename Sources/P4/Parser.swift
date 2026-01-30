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

public struct LocalElements {

}

public struct LocalElement {

}

public class ParserExecution: ProgramExecution {
    public var state: ParserState

    public init(_ state: ParserState) {
        self.state = state
    }

    public func transition(toNextState state: ParserState) -> ParserExecution {
        let next = self
        next.state = state
        return next
    }

    public override var description: String {
        return "Execution: \(super.description)\nCurrent State: \(state)"
    }
}

public protocol Expression {
    /// Evaluate an expression for a given execution
    /// - Parameters
    ///  - execution: The execution context in which to evaluate the expression
    /// - Returns: The value of expression
    func evaluate(execution: ParserExecution) -> Value
}

public protocol ParserStatement {
    /// Evaluate a statement for a given execution
    /// - Parameters
    ///  - execution: The execution context in which to evaluate the parser statement
    /// - Returns: An updated execution after evaluating the parser statement
    func evaluate(execution: ParserExecution) -> ParserExecution
}

public struct ParserTransitionStatement: ParserStatement {
    public init() {}
    public func evaluate(execution: ParserExecution) -> ParserExecution {
        return execution 
    }
}

public struct VariableDeclarationStatement: ParserStatement {
    public var variable: Variable
    public init(withVariable variable: Variable) {
        self.variable = variable
    }

    public func evaluate(execution: ParserExecution) -> ParserExecution {
        execution.scopes.scopes[0].variables.append(self.variable)
        return execution
    }
}

public struct ExpressionStatement: ParserStatement {
    public init() {}
    public func evaluate(execution: ParserExecution) -> ParserExecution {
        return execution
    }
}

public struct ParserState: Equatable, CustomStringConvertible {

    public private(set) var state_name: String
    public private(set) var local_elements: [ParserStatement]
    public private(set) var statements: [ParserStatement]
    public private(set) var transition: ParserTransitionStatement?

    public var description: String {
        return "Name: \(state_name)"
    }

    public static func == (lhs: ParserState, rhs: ParserState) -> Bool {
        return lhs.state_name == rhs.state_name
    }

    /// Construct a ParserState
    public init(name: String, withLocalElements localElements: [ParserStatement]?, withStatements statements: [ParserStatement]?, withTransition transitionStatement: ParserTransitionStatement) {
        state_name = name
        transition = transitionStatement
        local_elements = localElements ?? Array()
        self.statements = statements ?? Array()
    }

    func evaluate(execution: ParserExecution) -> ParserExecution {
        var currentExecution = execution

        // First, evaluate the local elements.
        for local_element in local_elements {
            currentExecution = local_element.evaluate(execution: currentExecution)
        }

        // Then, evaluate the statements.
        for statement in statements {
            currentExecution = statement.evaluate(execution: currentExecution)
        }

        return if let transition = transition {
            currentExecution.transition(toNextState: accept)
        } else {
            currentExecution.transition(toNextState: reject)
        }
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

    public func findStartState() -> Optional<ParserState> {
        for state in states {
            if state.state_name == "start" {
                return state
            }
        }
        return .none
    }
}
