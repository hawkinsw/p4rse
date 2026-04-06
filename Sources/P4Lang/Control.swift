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

public struct Action: CustomStringConvertible {
  public var description: String {
    return "Action: "
      + "\(self.name) with parameters \(self.params) and body \(String(describing: self.body))"
  }

  public var body: EvaluatableStatement?
  public var params: ParameterList
  public var name: Identifier

  public init(
    named name: Identifier, withParameters parameters: ParameterList,
    withBody body: EvaluatableStatement?
  ) {
    self.name = name
    self.params = parameters
    self.body = body
  }

}

public struct Actions: CustomStringConvertible {
  let actions: [Action]
  public init(withActions actions: [Action]) {
    self.actions = actions
  }

  public var description: String {
    return "Actions: "
      + actions.map { action in
        return "\(action)"
      }.joined(separator: ";")
  }
}

public enum TableKeyMatchType {
  case Exact
}

public struct TableKeyEntry: CustomStringConvertible {
  let key: KeysetExpression
  let match_type: TableKeyMatchType

  public init(_ key: KeysetExpression, _ match: TableKeyMatchType) {
    self.key = key
    self.match_type = match
  }

  public var description: String {
    return "Table Key Entry: " + "\(self.key): \(self.match_type)"
  }
}

public struct TableKeys: CustomStringConvertible {
  let entries: [TableKeyEntry]

  public init(withEntries entries: [TableKeyEntry]) {
    self.entries = entries
  }
  public init() {
    self.entries = []
  }

  public var description: String {
    return "Table Keys: "
      + self.entries.map { entry in
        return "\(entry)"
      }.joined(separator: ";")
  }
}

/// TODO
public struct TableActions {
  public init() {}
}

public struct TablePropertyList: CustomStringConvertible {
  let actions: TableActions
  let keys: TableKeys
  public init(withActions actions: TableActions, withKeys keys: TableKeys) {
    self.actions = actions
    self.keys = keys
  }

  public var description: String {
    return "Table Property List: \(self.actions) \(self.keys)"
  }
}

public struct Table: CustomStringConvertible {
  let properties: TablePropertyList
  let name: Identifier

  public init(withName name: Identifier, withPropertyList property_list: TablePropertyList) {
    self.name = name
    self.properties = property_list
  }

  public var description: String {
    return "Table named: \(self.name) \(self.properties)"
  }
}

public struct Control: P4Type, P4Value, Equatable, CustomStringConvertible {
  public static func == (lhs: Control, rhs: Control) -> Bool {
    // Two "bare" controls are always equal.
    return true
  }

  public func eq(rhs: any Common.P4Type) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func type() -> any Common.P4Type {
    return self
  }

  // Any operation between two "bare" parser states is always true.
  public func eq(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func lt(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func lte(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func gt(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func gte(rhs: any Common.P4Value) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public var description: String {
    return "Control named \(self._name) \(self.parameters) \(self.actions) \(self.table)"
  }

  let actions: Actions
  let table: Table
  let _parameters: ParameterList
  let _name: Identifier

  public var parameters: ParameterList {
    _parameters
  }

  public var name: Identifier {
    _name
  }

  public init(
    named: Identifier, withParameters parameters: ParameterList, withTable table: Table,
    withActions actions: Actions
  ) {
    self._name = named
    self._parameters = parameters
    self.actions = actions
    self.table = table
  }

  public func def() -> any P4Value {
    return Control(
      named: Identifier(name: ""),
      withParameters: ParameterList(),
      withTable: Table(
        withName: Identifier(name: "empty"),
        withPropertyList: TablePropertyList(withActions: TableActions(), withKeys: TableKeys())),
      withActions: Actions(withActions: []))
  }

}
