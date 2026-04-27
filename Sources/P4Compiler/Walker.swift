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
import SwiftTreeSitter
import TreeSitterP4

public struct Walker {
  var currentChildIdx: Int
  let childCount: Int
  let node: Node

  public init(node: Node) {
    self.currentChildIdx = 0
    self.childCount = node.childCount
    self.node = node
  }

  public mutating func next() {
    self.currentChildIdx += 1
  }

  public func getNext() -> Node? {
    // If it is safe, then return the node!
    if self.currentChildIdx < self.childCount {
      return self.node.child(at: self.currentChildIdx)!
    }
    return .none
  }

  public func overUntil(n: Int, todo: (Node) -> Result<()>) -> Result<()> {
    for currentChildIdx in currentChildIdx..<n {
      let currentChild = node.child(at: currentChildIdx)!
      if case Result.Error(let e) = todo(currentChild) {
        return Result<()>.Error(e)
      }
    }
    return Result.Ok(())
  }
}
