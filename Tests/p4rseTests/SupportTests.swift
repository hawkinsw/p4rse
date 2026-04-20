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

import Foundation
import Common
import Macros
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

struct NotStringConvertible {}

struct StringConvertible: CustomStringConvertible {
    public var description: String {
        return "CONVERTED"
    }
}

@Test func test_result_type_description_not_convertible() async throws {
    let result: Result<NotStringConvertible> = Result.Ok(NotStringConvertible());
    #expect("\(result)" == "Ok(Tests.NotStringConvertible())")
}

@Test func test_result_type_description_convertible() async throws {
    let result: Result<StringConvertible> = Result.Ok(StringConvertible());
    #expect("\(result)" == "Ok: CONVERTED")
}

@Test func test_result_type_p4value_convertible() async throws {
    let result = Result.Ok(P4Value(P4IntValue(withValue: 5)))
    #expect("\(result)" == "Ok: Value: 5 of Int type of type Int")
}