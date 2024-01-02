# StandardKeyBindingResponder

Reusable components for implementing NSStandardKeyBindingResponding in custom text views.

## Components

- SelectionNavigator - Create, modify and extend selections from keyboard and mouse events. Analogous to `NSTextSelectionNavigation`, but more Swifty.
- Transposer - Logic for `transpose:` and `transposeWords:`

## Getting started

1. Conform your text storage to `TextContent`. Both `String` and `AttributedString.CharacterView` can conform trivially. E.g. `extension String: TextContent {}`. This is all you need to use `Transposer`.
2. If your text storage has a method of finding paragraph boundaries that's better than O(n), implement `index(ofParagraphBoundaryBefore:)` and `index(ofParagraphBoundaryAfter:)`.
3. Implement `TextLayoutDataSource`.
4. Implement `InitializableFromAffinity`, `InitializableFromGranularity` and `NavigableSelection` for your affinity, granularity, and selection types.
5. Use the methods on `SelectionNavigation` to derive new selections from your existing selections.

**Note**: StandardKeyBindingResponder is very young and its API is not final.

## Future direction

The goal is to have a single struct `KeyBindingResponder` that manages all state related to NSStandardKeyBindingResponding. For a simple text view your key binding overrides and mouse event handlers (`mouseDown(_:)`, `mouseDragged(_:)`, `mouseUp(_:)`) should each be a single line of code.

## Missing features

- Multiple selections
- Kill buffer (mark/yank)
- Writing directions (i.e. RTL support)
- CR and CRLF line endings
- An adapter to use `NSTextStorage` as `TextContent`
- Make `NSLayoutManager` and `NSTextLayoutManager` conform to `TextLayoutDataSource`
- `KeyBindingResponder`
    - Scroll handling – scroll to the appropriate location after modifying a selection and scroll key bindings (`scrollPageUp:` etc.).
    - Insertion and indentation key bindings (`insertNewline(_:)` etc.)
    - Case changes (`changeCaseOfLetter(_:)`, etc.)
    - Allow `KeyBindingResponder` to use either `NSTextSelectionNavigation` or `SelectionNavigator`
- Documentation

## Contributing

Contributions are welcome! If you want to help out, I can walk you through the code, answer questions, etc. Just email me.
You can also just open an issue or pull request. For large features, consider opening an issue to discuss before you get started. Issues are [tagged with StandardKeyBindingResponder](https://github.com/davidbalbert/Watt/labels/StandardKeyBindingResponder).

## License

StandardKeyBindingResponder is copyright David Albert and released under the terms of the MIT License. See LICENSE.txt for details.
