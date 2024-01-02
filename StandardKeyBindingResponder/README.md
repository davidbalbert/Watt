# StandardKeyBindingResponder

Resuable components for implementing NSStandardKeyBindingResponding.

## Components

- SelectionNavigator - Create, modify and extend selections from keyboard and mouse events. Analogous to `NSTextSelectionNavigation`, but more Swifty.
- Transposer - Implementations for `transpose:` and `transposeWords:`

## Getting started

1. Implement `TextLayoutDataSource`. If you're only using `Transposer`, implement `TextContentDataSource`, which is the parent of `TextLayoutDataSource`. If you have a better than O(n) way to find paragraph boundaries, implement `index(ofParagraphBoundaryBefore:)` and `index(ofParagraphBoundaryAfter:)`.
2. Implement `InitializableFromAffinity`, `InitializableFromGranularity` and `NavigableSelection` for your affinity, granularity, and selection types.
3. Use the methods on `SelectionNavigation` to dervie new selections from your existing selections.

## Future direction

The goal is to have a single struct that manages all state related to NSStandardKeyBindingResponding. For a simple text view, your NSStandardKeyBindingResponding overrides and mouse events (`mouseDown:`, `mouseDragged:`, `mouseUp:`) should be doable in a single line of code.

## Missing features

- Multiple selections
- Kill buffer (mark/yank)
- Writing directions (RTL support)
- CR and CRLF line endings
- Documentation

## Contributing

Contributions are welcome! Feel free to open an issue or pull request. For large features, consider opening an issue to discuss before you get started. Issues are [tagged with StandardKeyBindingResponder](https://github.com/davidbalbert/Watt/labels/StandardKeyBindingResponder).

## License

StandardKeyBindingResponder is copyright David Albert and released under the terms of the MIT License. See LICENSE.txt for details.
