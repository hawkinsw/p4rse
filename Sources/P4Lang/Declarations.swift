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

public struct Declaration {}

public struct Parameter: CustomStringConvertible {
  public var name: Identifier
  public var type: P4Type

  public init(
    identifier: Identifier, withType type: P4Type
  ) {
    self.name = identifier
    self.type = type
  }

  public var description: String {
    return "Parameter: \(self.name) with type \(self.type)"
  }
}

public struct ParameterList: CustomStringConvertible {
  public var parameters: [Parameter]

  public init() {
    self.parameters = Array()
  }

  public init(_ parameters: [Parameter]) {
    self.parameters = parameters
  }

  public func addParameter(_ parameter: Parameter) -> ParameterList {
    return ParameterList(self.parameters + [parameter])
  }

  public var description: String {
    let parameters = self.parameters.map { parameter in
      parameter.description
    }.joined(separator: ";")
    return "Parameter list: \(parameters)"
  }
}
