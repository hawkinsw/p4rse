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

public struct ExpressionStatement {
  public init() {}
}

public struct Program {
  public var types: [P4DataType] = Array()
  public var instances: [P4Type] = Array()

  /// Type of closure for filtering results from ``Program/InstancesWithTypes(_:)``
  public typealias AttributedTypeFilter = (P4Type) -> Bool
  /// Type of closure for filtering results from ``Program/TypesWithTypes(_:)``
  public typealias TypeFilter = (P4DataType) -> Bool

  /// Retrieve global instances in the compiled P4 program.
  public func InstancesWithTypes() -> [P4Type] {
    return self.instances
  }

  /// Retrieve global instances in the compiled P4 program.
  ///
  /// Use the given filter to select which of the global instances
  /// from the compiled P4 program to retrieve.
  ///
  /// If the compiled P4 program (from the source in the
  /// string `p4_program_with_control_decl`) has two Control
  /// instances and  you only want to select the one named simple,
  /// you could use a filter like
  ///
  /// @Snippet(path: "use-program-instanceswithtypes", slice: "include")
  ///
  public func InstancesWithTypes(_ filter: AttributedTypeFilter) -> [P4Type] {
    return self.instances.filter { instance in
      filter(instance)
    }
  }

  /// Retrieve global types in the compiled P4 program.
  public func TypesWithTypes() -> [P4DataType] {
    return self.types
  }

  /// Retrieve global types declared in the compiled P4 program.
  ///
  /// Use the given filter to select which of the global types
  /// declared in the compiled P4 program to retrieve.
  ///
  /// If the compiled P4 program (from the source in the
  /// string `p4_program_with_struct_decl`) has two structs declared and
  /// you only want to select the one named `agg`, you could
  /// use a filter like
  ///
  /// @Snippet(path: "use-program-typeswithtypes", slice: "include")
  ///
  public func TypesWithTypes(_ filter: TypeFilter) -> [P4DataType] {
    return self.types.filter { instance in
      filter(instance)
    }
  }

  /// Find the program's main parser
  ///
  /// Note: For now, the main parser is expected to be named main_parser.
  public func starting_parser() -> Result<Parser> {
    return self.find_parser(withName: Identifier(name: "main_parser"))
  }

  public func find_parser(withName name: Identifier) -> Result<Parser> {
    for instance in self.instances {
      guard let parser = instance.dataType() as? Parser else {
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
