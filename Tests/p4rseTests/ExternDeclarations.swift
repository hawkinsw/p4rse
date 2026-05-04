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

public struct Return5: P4FFI {
  public func execute(execution: Common.ProgramExecution) -> (
    Common.ControlFlow, Common.ProgramExecution
  ) {
    return (ControlFlow.Return(P4Value(P4IntValue(withValue: 5))), execution)
  }

  public func parameters() -> ParameterList {
    return ParameterList()
  }

  public func type() -> Common.P4QualifiedType {
    return P4QualifiedType(
      FunctionDeclaration(
        named: Identifier(name: "externally"), ofType: P4QualifiedType(P4Int()),
        withParameters: ParameterList(), withBody: .none?))
  }

  public init() {}
}

public struct Return6: P4FFI {
  public func execute(execution: Common.ProgramExecution) -> (
    Common.ControlFlow, Common.ProgramExecution
  ) {
    return (ControlFlow.Return(P4Value(P4IntValue(withValue: 6))), execution)
  }

  public func parameters() -> ParameterList {
    return ParameterList()
  }

  public func type() -> Common.P4QualifiedType {
    return P4QualifiedType(
      FunctionDeclaration(
        named: Identifier(name: "externally"), ofType: P4QualifiedType(P4Int()),
        withParameters: ParameterList(), withBody: .none?))
  }

  public init() {}
}
@Test func test_extern_function_declaration() async throws {
  let simple_parser_declaration = """
      extern int externally();
      parser main_parser() {
        state start {
          int t = externally();
          transition select (t == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """

  let externally = Return5()

  let program = try! #UseOkResult(
    Program.Compile(
      simple_parser_declaration, withGlobalInstances: .none, withGlobalTypes: .none,
      withFFIs: [externally]))

  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)

}

@Test func test_extern_function_declaration2() async throws {
  let simple_parser_declaration = """
      extern int externally();
      parser main_parser() {
        state start {
          int t = externally();
          transition select (t == 5) {
            true: accept;
            false: reject;
          };
        }
      };
    """

  let externally = Return6()

  let program = try! #UseOkResult(
    Program.Compile(
      simple_parser_declaration, withGlobalInstances: .none, withGlobalTypes: .none,
      withFFIs: [externally]))

  let runtime = try #UseOkResult(P4Runtime.Runtime<InstantiatedParserState, P4Lang.Parser>.create(program: program))
  let (state_result, _) = try! #UseOkResult(runtime.run())

  #expect(AsInstantiatedParserState(state_result) == P4Lang.reject)
}
