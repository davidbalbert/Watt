//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

class AttributedStringStorage: ExpressibleByStringLiteral {

    typealias StringLiteralType = String

    var s: AttributedString

    init(_ s: AttributedString) {
        self.s = s
    }

    init(_ s: String) {
        self.s = AttributedString(s)
    }

    required init(stringLiteral stringValue: String) {
        self.s = AttributedString(stringValue)
    }

    var string: String {
        String(s.characters[...])
    }
}
