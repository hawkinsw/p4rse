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
  public let lvalue: TypedIdentifier
  public let value: EvaluatableExpression

  public init(withLValue lvalue: TypedIdentifier, withValue value: EvaluatableExpression) {
    self.lvalue = lvalue
    self.value = value
  }
}

public struct KeysetExpression {
  public let key: EvaluatableExpression
  public let next_state_name: String
  public let next_state: ParserState?

  public init(withKey key: EvaluatableExpression, withNextStateName next_state_name: String) {
    self.key = key
    self.next_state_name = next_state_name
    self.next_state = .none
  }
  public init(
    withKey key: EvaluatableExpression, withNextStateName next_state_name: String,
    withNextState next_state: ParserState
  ) {
    self.key = key
    self.next_state_name = next_state_name
    self.next_state = next_state
  }

}

public struct ParserTransitionSelectExpression {
  public let selector: EvaluatableExpression
  public let keyset_expressions: [KeysetExpression]

  public init(
    withSelector selector: EvaluatableExpression, withKeysetExpressions kses: [KeysetExpression]
  ) {
    self.selector = selector
    self.keyset_expressions = kses
  }

  public func append_checked_kse(kse: KeysetExpression) -> ParserTransitionSelectExpression {
    var new_kse = self.keyset_expressions
    new_kse.append(kse)
    return ParserTransitionSelectExpression(
      withSelector: self.selector, withKeysetExpressions: new_kse)
  }
}

public struct ParserTransitionStatement {
  public let next_state_name: String?
  public let transition_expression: ParserTransitionSelectExpression?

  public init() {
    self.next_state_name = .none
    self.transition_expression = .none
  }

  public init(withTransitionExpression transition_expression: ParserTransitionSelectExpression) {
    self.next_state_name = .none
    self.transition_expression = transition_expression
  }

  public init(withNextState next_state_name: String) {
    self.next_state_name = next_state_name
    self.transition_expression = .none
  }
}

public struct VariableDeclarationStatement {
  public var initializer: EvaluatableExpression
  public var identifier: Identifier
  public init(identifier: Identifier, withInitializer initializer: EvaluatableExpression) {
    self.identifier = identifier
    self.initializer = initializer
  }
}

public class ParserState: Equatable, CustomStringConvertible, Comparable {

  public private(set) var state_name: String
  public private(set) var local_elements: [EvaluatableStatement]
  public private(set) var statements: [EvaluatableStatement]
  public private(set) var transition: ParserTransitionStatement?
  public private(set) var next_state: ParserState?

  public static func < (lhs: ParserState, rhs: ParserState) -> Bool {
    // If lhs transitions to rhs, then return true. Otherwise, return false.

    // TODO!!
    return false
  }

  public var description: String {
    return "Name: \(state_name)"
  }

  public static func == (lhs: ParserState, rhs: ParserState) -> Bool {
    return lhs.state_name == rhs.state_name
  }

  /// Construct a ParserState
  public init(
    name: String, withLocalElements localElements: [EvaluatableStatement]?,
    withStatements stmts: [EvaluatableStatement]?,
    withTransition transitionStatement: ParserTransitionStatement
  ) {
    state_name = name
    transition = transitionStatement
    local_elements = localElements ?? Array()
    statements = stmts ?? Array()
  }

  public func semantic_check(states: ParserStates) -> Bool {
    guard let transition = transition else {
      return self == accept || self == reject
    }

    if let next_state_name = transition.next_state_name,
      let next_state = states.find(withName: next_state_name)
    {
      self.next_state = next_state
      return true
    }

    return false
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

  public func direct_transition() -> Bool {
    return
      if let transition = self.transition,
      transition.next_state_name != nil
    {
      true
    } else {
      false
    }
  }
}

nonisolated(unsafe) public let accept: ParserState = ParserState(name: "accept")
nonisolated(unsafe) public let reject: ParserState = ParserState(name: "reject")

public struct ParserStates {
  public var states: [ParserState] = Array()

  public func count() -> Int {
    return states.count
  }

  public func find(withName name: String) -> ParserState? {
    for state in states {
      if state.state_name == name {
        return .some(state)
      }
    }
    return .none
  }

  public func semantic_check() -> Result<()> {
    // Check whether all the states referred to in the transition statements are
    // valid.
    let errors = states.filter { state in
      return !state.semantic_check(states: self)
    }.map { state in
      return Result<()>.Error(Error(withMessage: "State \(state) has invalid transition"))
    }

    if !errors.isEmpty {
      return errors[0]
    }

    return .Ok(())
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

public struct Parser: P4Type {
  public var states: ParserStates

  public var name: Identifier

  public init(withName name: Identifier) {
    self.states = ParserStates()
    self.name = name
  }

  public static func create() -> any P4Type {
    return Parser(withName: Identifier(name: ""))
  }

  public func findStartState() -> ParserState? {
    for state in states.states {
      if state.state_name == "start" {
        return state
      }
    }
    return .none
  }

  public func semantic_check() -> Result<()> {
    return self.states.semantic_check()
  }

  public var description: String {
    return "Parser"
  }

  public func eq(rhs: P4Type) -> Bool {
    return if let parser_rhs = rhs as? Parser {
      self.name == parser_rhs.name
    } else {
      false
    }
  }
}
