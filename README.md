## P4RSE: P4 Runtime In Swift Environment

_P4RSE_ (yes, the acronym is a bit forced) is a P4 parser and runtime written in Swift. The project was started as a means to better learn Swift.

### Status

Very, very alpha:

1. Limited parts of the language can be parsed.
2. Limited programs can be evaluated.

As an example of what can be parsed and evaluated, here is a fairly complex P4 program cobbled together from our unit tests:

```P4
control simple(bool x, bool y) {
  action a(int z) {
    z = false;
  }
  table t {
    key = {
      x: exact;
      y: exact;
    }
  }
};
struct Testing {
  bool yesno;
  int count;
};
parser main_parser() {
  state start {
    Testing ts;
    ts.count = 1;
    transition select (ts.count) {
      0: accept;
      _: reject;
    };
  }
};
```

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

### Contributing

We would _love_ your help! Contributions are very welcome!

#### Coding Style

Here are the style guidelines that we are _trying_ to maintain:
- variables are in `snake_case`.
- types are in `CamelCase`.

Of course, we want to follow the formatter, too: see [below](#checking-format).

#### Commit Messages

We will try to maintain the following headline format for commit messages:

```
<component>: <subcomponent>: <change>
```

where `<component>` is one of:

1. `grammar`: For the tree-sitter-based grammar.
2. `compiler`: For the Swift-based P4 compiler of tree-sitter-based-parser parsed programs into AST.
3. `runtime`: For the Swift-based P4 interpreter.
4. `common`: For any Swift-based components common to the entire project (and macros).
5. `documentation`: For any documentation updates.
6. `testing`: For Swift-based tests.

where `<subcomponent>` can be more free-form and `<change>` is a pithy description of the changes in the commit.

#### Notes To Self

While coding, it may be useful to leave ourselves notes. Every note is formatted like:


```Swift
/// NOTE<: optional note text>
```

where `NOTE` can be:

1. `TODO`: Remind us `TODO` something.
2. `ASSUME`: Remind us that we are making an assumption.
3. `NB`: Remind us that we need to remember something when reading this code.

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