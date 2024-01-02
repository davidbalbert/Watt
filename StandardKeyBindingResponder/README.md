# StandardKeyBindingResponder

Reusable components for implementing NSStandardKeyBindingResponding in custom text views.

## Components

- SelectionNavigator - Create, modify and extend selections from keyboard and mouse events. Analogous to `NSTextSelectionNavigation`, but more Swifty.
- Transposer - Logic for `transpose:` and `transposeWords:`

## Getting started

1. Implement `TextLayoutDataSource`. If you're only using `Transposer`, implement `TextContentDataSource`, which is the parent of `TextLayoutDataSource`. If you have a better than O(n) way to find paragraph boundaries, implement `index(ofParagraphBoundaryBefore:)` and `index(ofParagraphBoundaryAfter:)`.
2. Implement `InitializableFromAffinity`, `InitializableFromGranularity` and `NavigableSelection` for your affinity, granularity, and selection types.
3. Use the methods on `SelectionNavigation` to derive new selections from your existing selections.

## Future direction

The goal is to have a single struct `KeyBindingResponder` that manages all state related to NSStandardKeyBindingResponding. For a simple text view your key binding overrides and mouse events (`mouseDown(_:)`, `mouseDragged(_:)`, `mouseUp(_:)`) should be a single line of code.

## Missing features

- Multiple selections
- Kill buffer (mark/yank)
- Writing directions (i.e. RTL support)
- CR and CRLF line endings
- `KeyBindingResponder`
    - Scroll handling – scroll to the appropriate location after modifying a selection and scroll key bindings (`scrollPageUp:` etc.).
    - Insertion and indentation key bindings (`insertNewline(_:)` etc.)
    - Case changes (`changeCaseOfLetter(_:)`, etc.)
- Documentation

## Contributing

Contributions are welcome! Feel free to open an issue or pull request. For large features, consider opening an issue to discuss before you get started. Issues are [tagged with StandardKeyBindingResponder](https://github.com/davidbalbert/Watt/labels/StandardKeyBindingResponder).

## License

StandardKeyBindingResponder is copyright David Albert and released under the terms of the MIT License. See LICENSE.txt for details.
