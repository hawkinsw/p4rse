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

public enum Result<OKT>: Equatable {
  case Ok(OKT)
  case Error(any Errorable)

  public static func == (lhs: Result, rhs: Result) -> Bool {
    switch (lhs, rhs) {
    case (Ok, Ok):
      return true
    case (Error(let le), Error(let re)):
      return le.eq(re)
    default:
      return false
    }
  }

  public func ok() -> Bool {
    switch self {
    case .Ok(_): true
    case .Error(_): false
    }
  }
  public func error() -> (any Errorable)? {
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

  public func map_err(block: (any Errorable) -> Result) -> Result {
    switch self {
    case .Ok(let ok): return .Ok(ok)
    case .Error(let e): return block(e)
    }
  }
}

extension Result: CustomStringConvertible where OKT: CustomStringConvertible {
  public var description: String {
    switch self {
    case Result.Error(let e):
      return e.msg()
    case Result.Ok(let o):
      return "Ok: \(o)"
    }
  }
}
