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

public struct Action: CustomStringConvertible, P4DataType, P4DataValue {
  public func type() -> any Common.P4DataType {
    return self
  }

  public func eq(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case let arhs as Action: self.name == arhs.name
    default: false
    }
  }

  public func eq(rhs: any Common.P4DataType) -> Bool {
    return switch rhs {
    case is Action: true
    default: false
    }
  }
  public func lt(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let arhs as Action: return self.name < arhs.name
    default: return false
    }
  }

  public func lte(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let arhs as Action: return self.name <= arhs.name
    default: return false
    }

  }

  public func gt(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let arhs as Action: return self.name > arhs.name
    default: return false
    }
  }

  public func gte(rhs: any Common.P4DataValue) -> Bool {
    switch rhs {
    case let arhs as Action: return self.name >= arhs.name
    default: return false
    }
  }

  public func def() -> any Common.P4DataValue {
    return Action()
  }

  public var description: String {
    return "Action: "
      + "\(self.name) with parameters \(self.params) and body \(String(describing: self.body))"
  }

  public var body: BlockStatement?
  public var params: ParameterList
  public var name: Identifier

  public init(
    named name: Identifier = Identifier(name: ""), withParameters parameters: ParameterList = ParameterList([]),
    withBody body: BlockStatement? = .none
  ) {
    self.name = name
    self.params = parameters
    self.body = body
  }

}

public struct Actions: CustomStringConvertible {
  public let actions: [Action]
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
  public let key: KeysetExpression
  public let match_type: TableKeyMatchType

  public init(_ key: KeysetExpression, _ match: TableKeyMatchType) {
    self.key = key
    self.match_type = match
  }

  public var description: String {
    return "Table Key Entry: " + "\(self.key): \(self.match_type)"
  }
}

public struct TableKeys: CustomStringConvertible {
  public let keys: [TableKeyEntry]

  public init(withEntries entries: [TableKeyEntry]) {
    self.keys = entries
  }
  public init() {
    self.keys = []
  }

  public var description: String {
    return "Table Keys: "
      + self.keys.map { key in
        return "\(key)"
      }.joined(separator: ";")
  }
}

public struct TableActionsProperty: CustomStringConvertible {
  public let actions: [TypedIdentifier]
  public init(_ actions: [TypedIdentifier] = []) {
    self.actions = actions
  }

  public var description: String {
    return "Table Actions: "
      + self.actions.map { action in
        return action.description
      }.joined(separator: ";")
  }
}

public struct TablePropertyList: CustomStringConvertible {
  public let actions: TableActionsProperty
  public let keys: TableKeys
  public init(withActions actions: TableActionsProperty, withKeys keys: TableKeys) {
    self.actions = actions
    self.keys = keys
  }

  public var description: String {
    return "Table Property List: \(self.actions) \(self.keys)"
  }
}

public struct Table: CustomStringConvertible {
  public let properties: TablePropertyList
  let name: Identifier
  public let entries: [(P4Value, TypedIdentifier)]

  public init(
    withName name: Identifier, withPropertyList property_list: TablePropertyList,
    withEntries entries: [(P4Value, TypedIdentifier)] = []
  ) {
    self.name = name
    self.properties = property_list
    self.entries = entries
  }

  public var description: String {
    return "Table named: \(self.name) \(self.properties)"
  }

  /// When the control is evaluated, the value of the x in the table is
  /// compared to the entries and the match is assocated with an action
  /// that is invoked when the match occurs!

  public func update(addEntry entry: (P4Value, TypedIdentifier)) -> Table{
    return Table(withName: self.name, withPropertyList: self.properties, withEntries: self.entries + [entry])
  }
}

public struct Control: P4DataType, P4DataValue, Equatable, CustomStringConvertible {
  public static func == (lhs: Control, rhs: Control) -> Bool {
    // Two "bare" controls are always equal.
    return true
  }

  public func eq(rhs: any Common.P4DataType) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func type() -> any Common.P4DataType {
    return self
  }

  // Any operation between two "bare" parser states is always true.
  public func eq(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func lt(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func lte(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func gt(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public func gte(rhs: any Common.P4DataValue) -> Bool {
    return switch rhs {
    case is Control: true
    default: false
    }
  }

  public var description: String {
    return "Control named \(self._name) \(self.parameters) \(self.actions) \(self.table)"
  }

  public let actions: Actions
  public let table: Table
  let _parameters: ParameterList
  let _name: Identifier
  let apply: ApplyStatement

  public var parameters: ParameterList {
    _parameters
  }

  public var name: Identifier {
    _name
  }

  public init(
    named: Identifier, withParameters parameters: ParameterList, withTable table: Table,
    withActions actions: Actions, withApply apply: ApplyStatement
  ) {
    self._name = named
    self._parameters = parameters
    self.actions = actions
    self.table = table
    self.apply = apply
  }

  public func updateTable(addEntry entry: (P4Value, TypedIdentifier)) -> Control {
    let table = self.table.update(addEntry: entry)

    return Control(named: self.name, withParameters: self.parameters, withTable: table, withActions: self.actions, withApply: self.apply)
  }

  public func def() -> any P4DataValue {
    return Control(
      named: Identifier(name: ""),
      withParameters: ParameterList(),
      withTable: Table(
        withName: Identifier(name: "empty"),
        withPropertyList: TablePropertyList(
          withActions: TableActionsProperty(), withKeys: TableKeys())),
      withActions: Actions(withActions: []), withApply: ApplyStatement())
  }

}
