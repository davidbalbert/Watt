//
//  Theme.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

struct Theme {
    let attributes: [Token.TokenType: AttributedRope.Attributes]

    // Hack until https://github.com/apple/swift/issues/60574 is fixed
    typealias A = AttributedRope.Attributes

    static let defaultTheme: Theme = [
        .keyword: A.foregroundColor(.systemBlue).symbolicTraits(.italic),
        .string: A.foregroundColor(.systemGreen),
        .type: A.foregroundColor(.systemOrange).symbolicTraits(.bold),
        .function: A.foregroundColor(.systemPurple),
        .constant: A.foregroundColor(.systemTeal),
        .variable: A.foregroundColor(.systemPink),
        .delimiter: A.foregroundColor(.systemGray),
        .number: A.foregroundColor(.systemBrown),
        .operator: A.symbolicTraits(.italic).underlineColor(.black).underlineStyle(.thick),
    ]

    subscript(key: Token.TokenType) -> AttributedRope.Attributes? {
        var type: Token.TokenType? = key

        while let t = type {
            if let attrs = attributes[t] {
                return attrs
            }

            if let i = t.rawValue.lastIndex(of: ".") {
                let parent = t.rawValue[..<i]
                type = Token.TokenType(rawValue: String(parent))
            } else {
                type = nil
            }
        }

        return nil
    }
}

extension Theme: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Token.TokenType, AttributedRope.Attributes)...) {
        self.attributes = Dictionary(uniqueKeysWithValues: elements)
    }
}
