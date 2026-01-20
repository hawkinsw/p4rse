public struct Error {
    public private(set) var msg: String

    public init(withMessage msg: String) {
        self.msg = msg
    }
}

public enum Result: Equatable {
    case Ok
    case Error(Error)

    public static func == (lhs: Result, rhs: Result) -> Bool {
        switch (lhs, rhs) {
        case (Ok, Ok):
            return true
        case (Error(let le), Error(let re)):
            return le.msg == re.msg
        default:
            return false
        }
    }
}

public struct ParserRuntime {
    public init() {}

    public func run(program: P4.Parser, input: P4.Packet) -> Result {

        // First, find the start state.
        guard var start_state = program.findStartState() else {
            return Result.Error(Error(withMessage: "Could not find the start state"))
        }
        var execution = P4.ParserExecution(start_state)
        while execution.state != P4.accept && execution.state != P4.reject {
            execution = execution.state.evaluate(execution: execution)
        }
        return Result.Ok
    }
}
