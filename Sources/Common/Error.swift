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

public struct Error: Errorable, Equatable, CustomStringConvertible {
  public func format() -> String {
    return self.description
  }

  public func msg() -> String {
    return self._msg
  }

  public func append(error: any Errorable) -> any Errorable {
    return Errors(self, error)
  }

  let _msg: String

  public init(withMessage msg: String) {
    self._msg = msg
  }

  public var description: String {
    return self._msg
  }
}

public struct ErrorWithLocation: Errorable, Equatable, CustomStringConvertible {
  let startFormat: String = "\u{1B}[31;1;4m"
  let endFormat: String = "\u{1B}[0m"

  public func format() -> String {
    return startFormat + "\(self.location)" + endFormat + ": \(self._msg)"
  }

  public func msg() -> String {
    return self.description
  }

  public func append(error: any Errorable) -> any Errorable {
    return Errors(self, error)
  }

  let _msg: String

  let location: SourceLocation

  public init(sourceLocation location: SourceLocation, withError msg: String) {
    self._msg = msg
    self.location = location
  }

  public var description: String {
    return "\(self.location): \(self._msg)"
  }
}

public struct Errors: Errorable, CustomStringConvertible {
  public func format() -> String {
    return self.description
  }

  public func msg() -> String {
    return self.description
  }

  public func append(error: any Errorable) -> any Errorable {
    return Errors(self.errors + [error])
  }

  public var description: String {
    return self.errors.map { error in
      return error.msg()
    }.joined(separator: ";")
  }

  public let errors: [any Errorable]

  init(_ errors: [any Errorable]) {
    self.errors = errors
  }

  public init(_ e1: any Errorable, _ e2: any Errorable) {
    self.errors = [e1, e2]
  }
}

public struct ErrorWithLabel: Errorable {
  let label: String
  let error: any Errorable

  public init(_ label: String, _ error: any Errorable) {
    self.label = label
    self.error = error
  }

  public func format() -> String {
    return self.description
  }

  public func msg() -> String {
    return self.description
  }

  public func append(error: any Errorable) -> any Errorable {
    return Errors(self, error)
  }

  public var description: String {
    return "\(self.label): \(self.error.msg())"
  }
}
