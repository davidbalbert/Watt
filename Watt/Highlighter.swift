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
    var highlightQuery: TreeSitterQuery
    var tree: TreeSitterTree?

    init?(language: TreeSitterLanguage, highlightQuery: TreeSitterQuery) {
        guard let parser = TreeSitterParser(language: language) else {
            return nil
        }

        self.parser = parser
        self.highlightQuery = highlightQuery
    }

    mutating func contentsDidChange(to rope: Rope, delta: BTreeDelta<Rope>? = nil) {
        tree = parser.parse(rope, oldTree: tree)
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
        guard let delegate else {
            return
        }
    }

    mutating func contentsDidChange(to rope: Rope, delta: BTreeDelta<Rope>? = nil) {
        client.contentsDidChange(to: rope, delta: delta)
        highlight()
    }
}
