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

public enum DebugLevel {
    case Trace
    case Verbose
    case Debug
    case Error

    func value() -> UInt8 {
        return switch self {
            case DebugLevel.Trace: 3
            case DebugLevel.Verbose: 2
            case DebugLevel.Debug: 1
            case DebugLevel.Error: 0
        }
        }
    public func isTrace() -> Bool {
        if self.value() >= DebugLevel.Trace.value() {
            return true
        }
        return false
    }
    public func isVerbose() -> Bool {
        if self.value() >= DebugLevel.Verbose.value() {
            return true
        }
        return false
    }
    public func isDebug() -> Bool {
        if self.value() >= DebugLevel.Debug.value() {
            return true
        }
        return false
    }
    public func isError() -> Bool {
        return true
    }

    public var description: String {
        return switch self {
            case DebugLevel.Trace: "Trace"
            case DebugLevel.Verbose: "Verbose"
            case DebugLevel.Debug: "Debug"
            case DebugLevel.Error: "Error"
        }
    }
}

public struct Error: Equatable {
    public private(set) var msg: String

    public init(withMessage msg: String) {
        self.msg = msg
    }
}

public struct Nothing: CustomStringConvertible {
    public var description: String {
        return "Nothing"
    }

    public init() {}
}


public enum Result<OKT>: Equatable {
    case Ok(OKT)
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

    public func error() -> Error? {
        if case Result.Error(let e) = self {
            return e
        }
        return nil
    }

    public func map<T>(block: (OKT) -> Result<T>) -> Result<T> {
        switch self {
            case .Ok(let ok): return block(ok)
            case .Error(let e): return .Error(e)
        } 
    }
}

extension Result where OKT: CustomStringConvertible {
    public var description: String {
        switch self {
            case Result.Error(let e):
                return e.msg
            case Result.Ok(let o):
                return "\(o)"
        }
    }
}

extension Result {
    public var description: String {
        switch self {
            case Result.Error(let e):
                return e.msg
            case Result.Ok(_):
                return "Ok"
        }
    }
}

@freestanding(expression) public macro RequireOkResult<T>(_: Result<T>) -> Bool =
    #externalMacro(module: "Macros", type: "RequireResult")
@freestanding(expression) public macro RequireErrorResult<T>(_: Error, _: Result<T>) -> Bool =
    #externalMacro(module: "Macros", type: "RequireErrorResult")
@freestanding(expression) public macro UseOkResult<T>(_: Result<T>) -> T =
    #externalMacro(module: "Macros", type: "UseOkResult")
