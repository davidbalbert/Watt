# Watt

<div float="left">
    <img width="410" src="/Assets/screenshot1.png?raw=true">
    <img width="410" src="/Assets/screenshot2.png?raw=true">
</div>

A high performance text editor for macOS. Not ready for production use.

See [this YouTube playlist](https://www.youtube.com/playlist?list=PLlwwvfE7L-7mSr2D5aONsutyHO4-xYC5Z) for info on how Watt works.

## Features

- Fast text storage: a copy-on-write B-tree based rope with O(log n) access and mutation.
- A fast, Core Animation based text view. Only draws lines in the viewport, and doesn't redraw on scroll.
- Full Unicode support (extended grapheme clusters, emoji sequences, skin tone modifiers, etc.).
- Monospaced and proportional typefaces.
- A files sidebar supporting live updates, drag and drop, and file renaming.
- System key bindings and [IMEs](https://en.wikipedia.org/wiki/Input_method) (emoji picker, Romaji, marked text, etc.).
- macOS integration: autosave, file history, reload on change, proxy icons, concurrent file loading, etc.
- Syntax highlighting using Tree-sitter (only C for now).
- System appearance support (dark mode, etc.).
- Themes.

## What's missing

- Non-wrapped text.
- Multiple cursors.
- Auto indent.
- [LSP](https://microsoft.github.io/language-server-protocol/) support: autocomplete, jump to definition, show callers, etc.
- Split views and tabs.
- Encodings besides UTF-8.
- Find in File and Find in Project.
- GitHub Copilot.
- Performance improvements:
    - Fast layout for documents with no line breaks – don't draw visual lines that are outside the viewport. 
    - Virtualized document height estimation – don't store heights of lines outside the viewport.
    - Don't block the UI when opening large files – load them piecemeal instead.
    - Don't block the UI when saving large files – use AppKit's asynchronous file writing support.
    - Efficient [diff-based file reloading](https://github.com/xi-editor/xi-editor/blob/master/rust/rope/src/diff.rs).

## Points of interest

- [Text storage](/Watt/Rope/Rope.swift).
- [Rich text storage](/Watt/Rope/AttributedRope.swift). Formatting only. No blocks (lists, tables, etc.).
- [Text layout engine](/Watt/LayoutManager/LayoutManager.swift).
- [A declarative data source](/Watt/Utilities/OutlineViewDiffableDataSource.swift) for NSOutlineView.
- [Declarative drag and drop](/Watt/Utilities/DragAndDrop.swift) – currently NSOutlineView specific.
- 60 FPS [scrolling](/Watt/Utilities/ScrollManager.swift) and [autoscroll while dragging](/Watt/Utilities/Autoscroller.swift).
- [StandardKeyBindingResponder](/StandardKeyBindingResponder), reusable components for selection management and system key bindings.

## Getting started

- Clone this repository.
- Run `git submodule update --init`.
- Copy Developer.xcconfig.example to Developer.xcconfig and set CODE_SIGN_IDENTITY and DEVELOPMENT_TEAM appropriately.
- Open Watt.xcodeproj in Xcode.

## License

Watt is copyright David Albert and released under the terms of the MIT License. See LICENSE.txt for details.

## Acknowledgements

Portions of Watt are adapted from the following projects. See ACKNOWLEDGEMENTS.md for license information.

- [FSEventsWrapper](https://github.com/Frizlab/FSEventsWrapper)
- [Swift Collections](https://github.com/apple/swift-collections)
- [xi-editor](https://github.com/xi-editor/xi-editor)
