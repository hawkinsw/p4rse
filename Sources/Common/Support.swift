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

public struct SourceLocation: Equatable, CustomStringConvertible {
  public let start: Int
  public let extent: Int

  public init(_ start: Int, _ extent: Int) {
    self.start = start
    self.extent = extent
  }

  public var description: String {
    return "{\(self.start), \(self.extent)}"
  }
}

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

public struct Nothing: CustomStringConvertible {
  public var description: String {
    return "Nothing"
  }

  public init() {}
}

public func Map<T, U>(input: T, block: (T) -> U) -> U {
  return block(input)
}

@freestanding(expression) public macro RequireOkResult<T>(_: Result<T>) -> Bool =
  #externalMacro(module: "Macros", type: "RequireResult")
@freestanding(expression) public macro RequireErrorResult<T>(
  _: any Errorable, _: Result<T>
) -> Bool =
  #externalMacro(module: "Macros", type: "RequireErrorResult")
@freestanding(expression) public macro UseOkResult<T>(_: Result<T>) -> T =
  #externalMacro(module: "Macros", type: "UseOkResult")
@freestanding(expression) public macro UseErrorResult<T>(_: Result<T>) -> any Errorable =
  #externalMacro(module: "Macros", type: "UseErrorResult")
@freestanding(codeItem) public macro RequireNodeType<N, T>(
  node: N, type: String, nice_type_name: String
) =
  #externalMacro(module: "Macros", type: "RequireNodeType")
@freestanding(codeItem) public macro RequireNodesType<N, T>(
  nodes: N, type: [String], nice_type_names: [String]
) =
  #externalMacro(module: "Macros", type: "RequireNodesType")
@freestanding(codeItem) public macro SkipUnlessNodeType<N>(node: N, type: String) =
  #externalMacro(module: "Macros", type: "SkipUnlessNodeType")

@freestanding(codeItem) public macro MustOr<E, N>(result: E, thing: E?, or: N) =
  #externalMacro(module: "Macros", type: "MustOr")
