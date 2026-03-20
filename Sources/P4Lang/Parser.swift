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

public struct ParserAssignmentStatement {
  public let lvalue: EvaluatableLValueExpression
  public let value: EvaluatableExpression

  public init(withLValue lvalue: EvaluatableLValueExpression, withValue value: EvaluatableExpression) {
    self.lvalue = lvalue
    self.value = value
  }
}

/// A P4 Parser State
///
/// Note: A P4 Parser State is both a type and a value.
public class ParserState: P4Type, P4Value, Equatable, CustomStringConvertible {
  public static func == (lhs: ParserState, rhs: ParserState) -> Bool {
    return lhs.state == rhs.state
  }

  public func eq(rhs: any Common.P4Type) -> Bool {
    return switch rhs {
    case is ParserState: true
    default: false
    }
  }

  public func type() -> any Common.P4Type {
    return self
  }

  public func eq(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case let other as ParserState: self.state == other.state
    default: false
    }
  }

  public private(set) var state: Identifier
  public private(set) var statements: [EvaluatableStatement]

  public var description: String {
    return "Name: \(state)"
  }

  /// Construct a ParserState
  public init(
    name: Identifier, withStatements stmts: [EvaluatableStatement],
  ) {
    state = name
    statements = stmts
  }

  /// (private) constructor (no transition)
  ///
  /// accept and reject are the only final states and they are constructed internally.
  private init(name: Identifier) {
    state = name
    statements = Array()
  }
}

public class ParserStateDirectTransition: ParserState {

  private let next_state: Identifier

  public init(
    name: Identifier, withStatements stmts: [EvaluatableStatement],
    withNextState next_state: Identifier
  ) {
    self.next_state = next_state
    super.init(name: name, withStatements: stmts)
  }

  public override var description: String {
    return "State (Name: \(super.state) (direct transition))"
  }

  public func get_next_state() -> Identifier {
    return self.next_state
  }
}

public class ParserStateNoTransition: ParserState {
  public override init(name: Identifier, withStatements stmts: [any EvaluatableStatement]) {
    super.init(name: name, withStatements: stmts)
  }
  public override var description: String {
    return "State (Name: \(super.state) (no transition))"
  }
}

public class ParserStateSelectTransition: ParserState {

  public let selectExpression: SelectExpression

  public override var description: String {
    return "State (Name: \(super.state) (select transition))"
  }

  public init(
    name: Identifier, withStatements stmts: [any EvaluatableStatement],
    withTransitioniExpression te: SelectExpression
  ) {
    self.selectExpression = te
    super.init(name: name, withStatements: stmts)
  }
}

nonisolated(unsafe) public let accept = ParserStateNoTransition(
  name: Identifier(name: "accept"), withStatements: [])
nonisolated(unsafe) public let reject = ParserStateNoTransition(
  name: Identifier(name: "reject"), withStatements: [])

public struct ParserStates {
  public var states: [ParserState] = Array()

  public func count() -> Int {
    return states.count
  }

  public func find(withIdentifier id: Identifier) -> ParserState? {
    for state in states {
      if state.state == id {
        return .some(state)
      }
    }
    return .none
  }

  public init() {
    self.states = Array()
  }

  private init(withStates states: [ParserState]) {
    self.states = states
  }

  public func append(state: ParserState) -> ParserStates {
    var new_states = self.states
    new_states.append(state)
    return ParserStates(withStates: new_states)
  }
}

/// A P4 Parser
///
/// Note: A Parser is both a type _and_ a value.
public struct Parser: P4Type, P4Value {
  public func type() -> any Common.P4Type {
    return self
  }

  public func eq(rhs: any Common.P4Type) -> Bool {
    return switch rhs {
    case is Parser: true
    default: false
    }
  }

  public var states: ParserStates

  public var name: Identifier

  public init(withName name: Identifier) {
    self.states = ParserStates()
    self.name = name
  }

  public func findStartState() -> ParserState? {
    for state in states.states {
      if state.state == Identifier(name: "start") {
        return state
      }
    }
    return .none
  }

  public func eq(rhs: any P4Value) -> Bool {
    return switch rhs {
    case let other as Parser: self.name == other.name
    default: false
    }
  }

  public var description: String {
    return "Parser"
  }
}
