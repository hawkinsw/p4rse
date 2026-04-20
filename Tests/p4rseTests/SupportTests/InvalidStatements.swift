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
import Macros
import P4Lang
import P4Runtime
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_invalid_statements() async throws {

  let ret = ReturnStatement(P4Value(P4IntValue(withValue: 5)))
  let block = BlockStatement([ret])

  #expect(ContainsInvalidStatements(block: block, invalids: [ReturnStatement.self]))
}

@Test func test_no_invalid_statements() async throws {

  let exprs = ExpressionStatement(P4Value(P4IntValue(withValue: 5)))
  let block = BlockStatement([exprs])

  #expect(!ContainsInvalidStatements(block: block, invalids: [ReturnStatement.self]))
}

@Test func test_is_invalid_statement() async throws {

  let ret = ReturnStatement(P4Value(P4IntValue(withValue: 5)))

  #expect(ContainsInvalidStatements(statement: ret, invalids: [ReturnStatement.self]))
}

@Test func test_no_is_invalid_statement() async throws {

  let exprs = ExpressionStatement(P4Value(P4IntValue(withValue: 5)))

  #expect(!ContainsInvalidStatements(statement: exprs, invalids: [ReturnStatement.self]))
}
