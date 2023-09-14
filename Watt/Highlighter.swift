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
        // TODO: pass in oldTree to make editing work
        tree = parser.parse(rope, oldTree: nil)
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

    mutating func contentsDidChange(to rope: Rope, delta: BTreeDelta<Rope>? = nil) {
        client.contentsDidChange(to: rope, delta: delta)
        highlight()
    }
}
