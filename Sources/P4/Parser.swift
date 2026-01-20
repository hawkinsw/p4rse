public struct LocalElements {

}

public struct LocalElement {

}

public struct ParserExecution {
    public var state: ParserState

    public init(_ state: ParserState) {
        self.state = state
    }

    public func transition(toNextState state: ParserState) -> ParserExecution {
        return ParserExecution(state)
    }
}

public protocol Expression {
    /// Evaluate an expression for a given execution
    /// - Parameters
    ///  - execution: The execution context in which to evaluate the expression
    /// - Returns: The value of expression
    func evaluate(execution: ParserExecution) -> Value
}

public protocol ParserStatement: Sendable {
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

public struct ExpressionStatement: ParserStatement {
    public init() {}
    public func evaluate(execution: ParserExecution) -> ParserExecution {
        return execution
    }
}

public struct ParserState: Equatable, Sendable {
    public private(set) var state_name: String
    public private(set) var statements: [ParserStatement]
    public private(set) var transition: ParserTransitionStatement?

    public static func == (lhs: ParserState, rhs: ParserState) -> Bool {
        return lhs.state_name == rhs.state_name
    }

    /// Construct a ParserState
    public init(name: String, withStatements statements: [ParserStatement]?, withTransition transitionStatement: ParserTransitionStatement) {
        state_name = name
        transition = transitionStatement
        self.statements = statements ?? Array()
    }

    func evaluate(execution: ParserExecution) -> ParserExecution {
        var currentExecution = execution
        for statement in statements {
            currentExecution = statement.evaluate(execution: currentExecution)
        }

        return if let transition = transition {
            execution.transition(toNextState: accept)
        } else {
            execution.transition(toNextState: reject)
        }
    }

    /// (private) constructor (no transition)
    /// 
    /// accept and reject are the only final states and they are constructed internally.
    init(name: String) {
        state_name = name
        transition = .none
        statements = Array()
    }
}

public struct ParserStates: Sendable {
    public var states: [ParserState] = Array()
}

public let accept: ParserState = ParserState(name: "accept")
public let reject: ParserState = ParserState(name: "reject")

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
