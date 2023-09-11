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

    mutating func contentsDidChange(to rope: Rope, delta: BTreeDelta<Rope>? = nil) {
        tree = parser.parse(rope, oldTree: tree)
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

struct Token {
}

protocol HighlighterDelegate: AnyObject {
    func highlighter(_ highlighter: Highlighter, applyStyleToToken token: Token)
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
//        guard let delegate else {
//            return
//        }

        guard let cursor = client.executeHighlightsQuery() else {
            return
        }

        for match in cursor {
            for capture in match.captures {
                print(capture.name)
            }
        }
    }

    mutating func contentsDidChange(to rope: Rope, delta: BTreeDelta<Rope>? = nil) {
        client.contentsDidChange(to: rope, delta: delta)
        highlight()
    }
}
