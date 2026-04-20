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
import P4Runtime
import P4Lang
import SwiftTreeSitter
import Testing
import TreeSitter
import TreeSitterP4

@testable import P4Compiler

@Test func test_statement_interloper() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state starts {
          bool where_to = false;
          int va = 5;
          transition accept;
        }
        state start {
          bool where_to = true;
          where_to = true;
          transition select (where_to) {
            false: reject;
            true: starts;
          };
        }
      };
    """
  
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))

  var statements_executed: [String] = Array()

  let ev = InterloperEvaluator().setStatementInterloper() { (statement, cf, execution) in
    statements_executed.append("\(statement)")
  }

  let (state_result, _) = try! #UseOkResult(runtime.run(withArguments: ArgumentList(), inExecution: ProgramExecution(ev)))

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)

  #expect(statements_executed[0].hasPrefix("VariableDeclarationStatement"))
  #expect(statements_executed[1].hasPrefix("ParserAssignmentStatement"))
  // Moved into starts
  #expect(statements_executed[2].hasPrefix("VariableDeclarationStatement"))
  #expect(statements_executed[3].hasPrefix("VariableDeclarationStatement"))
}

@Test func test_expression_interloper() async throws {
  let simple_parser_declaration = """
      parser main_parser() {
        state starts {
          bool where_to = false;
          int va = 5;
          transition accept;
        }
        state start {
          bool where_to = true;
          where_to = true;
          transition select (where_to) {
            false: reject;
            true: starts;
          };
        }
      };
    """
  
  let program = try #UseOkResult(Program.Compile(simple_parser_declaration))
  let runtime = try #UseOkResult(P4Runtime.ParserRuntime.create(program: program))

  var expressions_evaluated: [String] = Array()

  let ev = InterloperEvaluator().setExpressionInterloper() { expression, result, execution in 
    expressions_evaluated.append("\(expression)")
  }

  let (state_result, _) = try! #UseOkResult(runtime.run(withArguments: ArgumentList(), inExecution: ProgramExecution(ev)))

  #expect(AsInstantiatedParserState(state_result) == P4Lang.accept)

  #expect(expressions_evaluated[0].hasPrefix("Value: true of Boolean"))
  #expect(expressions_evaluated[1].hasPrefix("Value: true of Boolean"))
  #expect(expressions_evaluated[2].hasPrefix("where_to"))
  #expect(expressions_evaluated[3].hasPrefix("Value: false of Boolean"))
  #expect(expressions_evaluated[4].hasPrefix("KeysetExpression"))
  #expect(expressions_evaluated[5].hasPrefix("Value: true of Boolean"))
  #expect(expressions_evaluated[6].hasPrefix("KeysetExpression"))
  #expect(expressions_evaluated[7].hasPrefix("SelectCaseExpression"))
  #expect(expressions_evaluated[8].hasPrefix("SelectExpression"))
  // Moved into starts
  #expect(expressions_evaluated[9].hasPrefix("Value: false of Boolean"))
  #expect(expressions_evaluated[10].hasPrefix("Value: 5 of Int"))
}
