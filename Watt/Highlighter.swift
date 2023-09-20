//
//  Highlighter.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation
import UniformTypeIdentifiers

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
    func highlighter(_ highlighter: Highlighter, applyTokens tokens: [Token])
    func highlighter(_ highlighter: Highlighter, parser: TreeSitterParser, readSubstringStartingAt byteIndex: Int) -> Substring?
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

    func highlight() {
        guard let delegate else {
            return
        }

        guard let tree = tree ?? parser.parse() else {
            return
        }

        let cursor = TreeSitterQueryCursor(query: highlightsQuery, tree: tree)

        let tokens = cursor.compactMap { c in
            if let type = Token.TokenType(rawValue: c.name) {
                return Token(type: type, range: c.range)
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

extension TreeSitterInputEdit {
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
