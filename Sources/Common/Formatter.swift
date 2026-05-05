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

public enum StyleColor {
  case Red
  case Blue
  case Green
}

public enum StyleFormat {
  case Underline
  case Bold
}

public struct Style: Equatable {
  let color: StyleColor?
  let format: [StyleFormat]

  public init(_ color: StyleColor?, _ format: [StyleFormat] = []) {
    self.color = color
    self.format = format
  }

  public func update(setColor color: StyleColor) -> Style {
    return Style(color, self.format)
  }

  public func removeColor() -> Style {
    return Style(nil, self.format)
  }

  public func update(addFormat format: StyleFormat) -> Style {
    return if self.format.contains(format) {
      Style(self.color, self.format)
    } else {
      Style(self.color, self.format + [format])
    }
  }

  public func update(removeFormat format: StyleFormat) -> Style {
    let new_format = self.format.filter { existing_format in
      existing_format != format
    }
    return Style(self.color, new_format)
  }

  public func getColor() -> StyleColor? {
    return self.color
  }

  public func getFormat() -> [StyleFormat] {
    return self.format
  }
}

public struct FormatterPlain: Formattable {
  public init() {}
  public func formatWithStyle(_ value: String, _ style: Style) -> String {
    return value
  }

}

public struct FormatterAnsi: Formattable {

  public init() {}

  let startFormat: String = "\u{1B}["
  let resetFormat: String = "\u{1B}[0m"

  let colorMap = [
    StyleColor.Red: "31",
    StyleColor.Green: "32",
    StyleColor.Blue: "34",
  ]

  let styleMap = [
    StyleFormat.Underline: "4",
    StyleFormat.Bold: "1",
  ]

  public func formatWithStyle(_ value: String, _ style: Style) -> String {
    let color =
      if let color = style.getColor() {
        self.colorMap[color]!
      } else {
        ""
      }

    let style = style.getFormat().map { format in
      String(self.styleMap[format]!)
    }.joined(separator: ";")

    if color.isEmpty && style.isEmpty {
      return value
    }

    let code = startFormat + color + ((!color.isEmpty && !style.isEmpty) ? ";" : "") + style + "m"

    return code + value + resetFormat
  }
}
