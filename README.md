## P4RSE: P4 Runtime In Swift Environment

_P4RSE_ (yes, the acronym is a bit forced) is a P4 parser and runtime written in Swift. The project was started as a means to better learn Swift.

### Status

Very, very alpha:

1. Limited parts of the language can be parsed.
2. Limited programs can be evaluated.

As an example of what can be parsed and evaluated, here is a fairly complex P4 program from our unit tests:

```P4
parser main_parser() {
    state start {
        bool where_to = ts.yesno;
        string where_from = "here";
        string where_where = "here";
        if (where_to) {
            bool where_from = true;
            if (where_from) {
                where_to = false;
            }
        }
        where_from = "there";
        transition select (where_to) {
            false: reject;
            true: accept;
        };
    }
};
```

(assuming hat `ts` is an instance of a `struct` with the boolean-typed field `yesno`)

Please check back often!

### Building

#### Requirements And Basic Build

This project uses [code item macros (`CodeItemMacros`)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0397-freestanding-declaration-macros.md#future-directions) which
are an experimental feature in Swift and not [_available in production_](https://github.com/swiftlang/swift/blob/1ba5ae105876b15914688cdf8431fd390651296e/include/swift/Basic/Features.def).

Therefore, to compile this project, you must be using a non-production version of the compiler.

With that caveat noted, building can be done with `swift build`:

```console
$ swift build
```

#### Testing

To run the P4RSE tests:

```console
$ swift test
```

To run the parser tests, from the `tree-sitter-p4` directory:
```console
$ npx tree-sitter test
```

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

#### Checking Format

To check the format:

```console
$ swift-format --recursive -i Sources/
```