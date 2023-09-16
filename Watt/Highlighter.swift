//
//  Highlighter.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation
import UniformTypeIdentifiers

struct TreeSitterClient {
    var parser: TreeSitterParser
    var highlightsQuery: TreeSitterQuery
    var tree: TreeSitterTree?

    init?(language: TreeSitterLanguage, highlightsQuery: TreeSitterQuery) {
        guard let parser = TreeSitterParser(language: language) else {
            return nil
        }

        self.parser = parser
        self.highlightsQuery = highlightsQuery
    }

    mutating func contentsInitialized(to rope: Rope) {
        tree = parser.parse(rope, oldTree: nil)
    }

    mutating func contentsDidChange(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        let tree = tree!

        let inputEdit = inputEdit(from: old, to: new, delta: delta)
        tree.edit(inputEdit)

        self.tree = parser.parse(new, oldTree: tree)
    }

    func inputEdit(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) -> TreeSitterInputEdit {
        // TODO: with multiple cursors, we should find a way to do a more efficient summary.
        let (replacementRange, newCount) = delta.summary()

        let startByte = replacementRange.lowerBound
        let oldEndByte = replacementRange.upperBound
        let newEndByte = startByte + newCount

        let startPoint = pointFor(index: old.utf8.index(at: startByte), in: old)
        let oldEndPoint = pointFor(index: old.utf8.index(at: oldEndByte), in: old)
        let newEndPoint = pointFor(index: new.utf8.index(at: newEndByte), in: new)

        return TreeSitterInputEdit(
            startByte: startByte,
            oldEndByte: oldEndByte,
            newEndByte: newEndByte,
            startPoint: startPoint,
            oldEndPoint: oldEndPoint,
            newEndPoint: newEndPoint
        )
    }

    func pointFor(index: Rope.Index, in rope: Rope) -> TreeSitterPoint {
        let lineIdx = rope.lines.index(roundingDown: index)
        let row = rope.lines.distance(from: rope.startIndex, to: lineIdx)
        let col = rope.distance(from: lineIdx, to: index)
        return TreeSitterPoint(row: row, column: col)
    }

    func executeHighlightsQuery() -> TreeSitterQueryCursor? {
        guard let tree else {
            return nil
        }

        let cursor = TreeSitterQueryCursor(tree: tree)
        cursor.execute(query: highlightsQuery)
        return cursor
    }
}

struct Token: Equatable {
    enum TokenType: String {
        case keyword
        case string
        case type
        case function
        case constant
        case variable
        case delimiter
        case number
    }

    let type: TokenType
    let range: Range<Int>
}

protocol HighlighterDelegate: AnyObject {
    func applyTokens(_ tokens: [Token])
}

struct Highlighter {
    var language: Language
    weak var delegate: HighlighterDelegate?

    var client: TreeSitterClient

    init?(language: Language, delegate: HighlighterDelegate) {
        self.language = language
        self.delegate = delegate

        guard let client = language.treeSitterClient else {
            return nil
        }

        self.client = client
    }

    func highlight() {
        guard let delegate else {
            return
        }

        guard let cursor = client.executeHighlightsQuery() else {
            return
        }

        let captures = cursor.flatMap(\.captures)
        let tokens = captures.compactMap { c in
            if let type = Token.TokenType(rawValue: c.name) {
                return Token(type: type, range: c.range)
            } else {
                return nil
            }
        }
        delegate.applyTokens(tokens)
    }

    mutating func contentsInitialized(to rope: Rope) {
        client.contentsInitialized(to: rope)
        highlight()
    }

    mutating func contentsDidChange(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        client.contentsDidChange(from: old, to: new, delta: delta)
        highlight()
    }
}
