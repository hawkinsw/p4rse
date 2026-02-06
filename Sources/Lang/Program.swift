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

public struct Program {
    public var types: [P4Type] = Array()

    /// Find the program's main parser
    /// 
    /// Note: For now, the main parser is expected to be named main_parser.
    public func starting_parser() -> Result<Parser> {
        return self.find_parser(withName: Identifier(name: "main_parser"))
    }

    public func find_parser(withName name: Identifier) -> Result<Parser> {
        for type in self.types {
            print("type: \(type)")
            guard let parser = type as? Parser else {
                continue
            }
            if parser.name == name {
                return .Ok(parser)
            }
        }
        return .Error(Error(withMessage: "Could not find parser named \(name)"))
    }

    public init() {}
}