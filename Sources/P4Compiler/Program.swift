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
  public static func Compile(_ source: String) -> Result<P4Lang.Program> {
    return Program.Compile(source, withGlobalInstances: .none, withGlobalTypes: .none, withFFIs: [])
  }

  public static func Compile(
    _ source: String, withGlobalInstances globalInstances: VarTypeScopes
  ) -> Result<P4Lang.Program> {
    return Program.Compile(
      source, withGlobalInstances: globalInstances, withGlobalTypes: .none, withFFIs: [])
  }

  public static func Compile(
    _ source: String, withGlobalInstances globalInstances: VarTypeScopes?,
    withGlobalTypes globalTypes: TypeTypeScopes?, withFFIs ffis: [P4FFI] = Array()
  ) -> Result<P4Lang.Program> {

    let maybe_parser = ConfigureP4Parser()
    guard case .Ok(let p) = maybe_parser else {
      return .Error(maybe_parser.error()!)
    }

    let result = p.parse(source)
    guard let tree = result,
      !tree.isError(lang: p4lang),
      !tree.containsMissing(lang: p4lang)
    else {
      return Result.Error(Error(withMessage: "Could not compile the P4 program"))
    }

    var program = P4Lang.Program()

    // Set up a context for parsing.
    var compilation_context = CompilerContext()

    // Add our FFIs
    compilation_context = compilation_context.update(newFFIs: ffis)

    var errors: [any Errorable] = Array()

    // If the caller gave any global instances, add them here.
    if let globalInstances = globalInstances {
      compilation_context = compilation_context.update(newInstances: globalInstances)
    }

    // If the caller gave any global types, add them here.
    if let globalTypes = globalTypes {
      compilation_context = compilation_context.update(newTypes: globalTypes)
    }

    // Try to parse all top-level declarations.
    result?.rootNode?.enumerateNamedChildren { (declaration_node: Node) in
      let specific_declaration_node = declaration_node.child(at: 0)!

      let declaration_parsers: [CompilableDeclaration.Type] = [
        Declaration.self, P4Lang.Parser.self,
      ]
      var found_parser = false

      for parser in declaration_parsers {
        switch parser.Compile(node: specific_declaration_node, withContext: compilation_context) {
        case .Ok(.none): {}()
        case .Ok(.some((_, let updated_context))):
          found_parser = true
          compilation_context = updated_context
          break
        case .Error(let e):
          found_parser = true
          errors.append(e)
          break
        }
      }

      // If none of the declaration parsers chose to parse, that's an error, too!
      if !found_parser {
        errors.append(
          ErrorWithLocation(
            sourceLocation: specific_declaration_node.toSourceLocation(), withError: "Could not find parser for declaration node"
          ))
      }
    }

    if !errors.isEmpty {
      return Result.Error(
        Error(
          withMessage: errors.map { error in
            return error.format()
          }.joined(separator: ";")))
    }

    // Any of the instances that are in the top-level scope should go into the program!
    program.instances = Array(
      compilation_context.instances.map { (_, v) in
        v
      })

    // Any of the types that are in the top-level scope should go into the program!
    program.types = Array(
      compilation_context.types.map { (_, v) in
        v
      })

    // Any of the extern types that are in the top-level scope should go into the program!
    program.externs = Array(
      compilation_context.externs.map { (_, v) in
        v
      })

    return Result.Ok(program)
  }
}
