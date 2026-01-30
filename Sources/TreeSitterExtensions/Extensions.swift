// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

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

import SwiftTreeSitter

extension MutableTree {
  public func isError(lang: Language) -> Bool {
    guard
      let parser_error_query = try? SwiftTreeSitter.Query(
        language: lang,
        data: String(
          "(ERROR)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return false
    }

    let error_qr = parser_error_query.execute(in: self)
    for _ in error_qr {
      return true
    }
    return false
  }
}

