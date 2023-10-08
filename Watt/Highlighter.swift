//
//  Highlighter.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation
import UniformTypeIdentifiers

struct Token: Equatable {
    enum TokenType: String, CaseIterable {
        case keyword
        case string
        case type
        case function
        case functionSpecial = "function.special"
        case constant
        case variable
        case property
        case delimiter
        case number
        case `operator`
        case label
        case comment
    }

    let type: TokenType
    let range: Range<Int>
}

protocol HighlighterDelegate: AnyObject {
    func highlighter(_ highlighter: Highlighter, applyTokens tokens: [Token])
    func highlighter(_ highlighter: Highlighter, parser: TreeSitterParser, readSubstringStartingAt byteIndex: Int) -> Substring?
    func highlighter(_ highlighter: Highlighter, stringForByteRange range: Range<Int>) -> String
}

final class Highlighter {
    weak var delegate: HighlighterDelegate?

    var parser: TreeSitterParser
    var highlightsQuery: TreeSitterQuery
    var tree: TreeSitterTree?

    init(parser: TreeSitterParser, highlightsQuery: TreeSitterQuery) {
        self.parser = parser
        self.highlightsQuery = highlightsQuery

        parser.delegate = self
    }

    func highlightIfNecessary() {
        if tree == nil {
            highlight()
        }
    }

    func highlight() {
        guard let delegate else {
            return
        }

        guard let tree = tree ?? parser.parse() else {
            return
        }

        let cursor = TreeSitterQueryCursor(query: highlightsQuery, tree: tree) { range in
            delegate.highlighter(self, stringForByteRange: range)
        }

        let tokens = cursor.validCaptures().compactMap { capture in
            if let type = Token.TokenType(rawValue: capture.name) {
                return Token(type: type, range: capture.range)
            } else {
                return nil
            }
        }
        
        delegate.highlighter(self, applyTokens: tokens)
    }

    func contentsDidChange(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        guard let tree else {
            tree = parser.parse()
            return
        }

        let edit = TreeSitterInputEdit(from: old, to: new, delta: delta)
        tree.apply(edit)
        self.tree = parser.parse(oldTree: tree)
    }
}

extension Highlighter: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, readSubstringStartingAt byteIndex: Int) -> Substring? {
        delegate?.highlighter(self, parser: parser, readSubstringStartingAt: byteIndex)
    }
}

fileprivate extension TreeSitterTextPoint {
    init(byteOffset: Int, in rope: Rope) {
        let index = rope.utf8.index(at: byteOffset)

        let lineIdx = rope.lines.index(roundingDown: index)
        let row = rope.lines.distance(from: rope.startIndex, to: lineIdx)
        let col = rope.distance(from: lineIdx, to: index)

        self.init(row: row, column: col)
    }
}

fileprivate extension TreeSitterInputEdit {
    init(from old: Rope, to new: Rope, delta: BTreeDelta<Rope>) {
        // TODO: with multiple cursors, we should find a way to do a more efficient summary.
        let (replacementRange, newCount) = delta.summary()

        let startByte = replacementRange.lowerBound
        let oldEndByte = replacementRange.upperBound
        let newEndByte = startByte + newCount

        self.init(
            startByte: startByte,
            oldEndByte: oldEndByte,
            newEndByte: newEndByte,
            startPoint: TreeSitterTextPoint(byteOffset: startByte, in: old),
            oldEndPoint: TreeSitterTextPoint(byteOffset: oldEndByte, in: old),
            newEndPoint: TreeSitterTextPoint(byteOffset: newEndByte, in: new)
        )
    }
}
