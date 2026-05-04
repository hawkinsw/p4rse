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
import Foundation
import Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4
import P4Lang
import P4Compiler

let p4_program_with_struct_decl = """
  struct agg {
    int x;
  };
  """

// snippet.include
let flter = { (tipe: P4Type) -> Bool in
  switch tipe {
  case let c as P4Struct: c.name == "agg"
  default: false
  }
}
if case .Ok(let program) = Program.Compile(p4_program_with_struct_decl) {
  print(program.TypesWithTypes(flter))
}

