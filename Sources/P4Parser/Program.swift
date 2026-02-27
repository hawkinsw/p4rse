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
import P4Lang
import P4Runtime
import SwiftTreeSitter
import TreeSitterExtensions
import TreeSitterP4

public struct Program {
  public static func Parse(_ source: String) -> Result<P4Lang.Program> {
    let p = SwiftTreeSitter.Parser.init()

    do {
      try p.setLanguage(p4lang)
    } catch {
      return Result.Error(Error(withMessage: "Could not configure the P4 parser"))
    }

    let result = p.parse(source)
    guard let tree = result,
      !tree.isError(lang: p4lang),
      !tree.containsMissing(lang: p4lang)
    else {
      return Result.Error(Error(withMessage: "Could not compile the P4 program"))
    }

    guard
      let parser_declaration_query = try? SwiftTreeSitter.Query(
        language: p4lang,
        data: String(
          "(parserDeclaration (parserType parser_name: (identifier) @parser-name) (parserStates) @parser-states)"
        ).data(using: String.Encoding.utf8)!)
    else {
      return Result.Error(
        Error(withMessage: "Could not compile the parser declaration tree sitter query"))
    }

    var program = P4Lang.Program()

    // Set up a lexical scope for parsing.
    var program_scope = LexicalScopes().enter()

    let parser_qc = parser_declaration_query.execute(in: tree)

    for parser_declaration in parser_qc {
      switch Parser.Parse(
        withName: Common.Identifier(name: parser_declaration.nodes[0].text!),
        node: parser_declaration.nodes[1], inTree: tree, withLexicalScopes: program_scope)
      {
      case Result.Ok((let parser, let new_program_scope)):
        program.types.append(parser)
        program_scope = new_program_scope
      case Result.Error(let error): return Result.Error(error)
      }
    }

    return Result.Ok(program)
  }
}
