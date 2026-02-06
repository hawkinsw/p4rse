## P4RSE: P4 Runtime In Swift Environment

_P4RSE_ (yes, the acronym is a bit forced) is a P4 parser and runtime written in Swift. The project was started as a means to better learn Swift.

### Status

Very, very alpha:

1. Limited parts of the language can be parsed.
2. Limited programs can be evaluated.

Please check back often!

### Building

#### Generating Documentation

To build the documentation:

```console
$ swift package generate-documentation
```

To preview the generated documentation:
```console
$ swift package swift package --disable-sandbox preview-documentation  --target <some target>
```

For more information, see the [documentation for the Swift-DocC plugin](https://swiftlang.github.io/swift-docc-plugin/documentation/swiftdoccplugin/).
