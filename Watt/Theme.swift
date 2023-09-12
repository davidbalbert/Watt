//
//  Theme.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

typealias Theme = [Token.TokenType: AttributedRope.Attributes]

extension Theme {
    // Hack until https://github.com/apple/swift/issues/60574 is fixed
    typealias A = AttributedRope.Attributes

    static let defaultTheme: Theme = [
        .keyword: A.foregroundColor(.systemBlue),
        .string: A.foregroundColor(.systemGreen),
        .type: A.foregroundColor(.systemOrange),
        .function: A.foregroundColor(.systemPurple),
        .constant: A.foregroundColor(.systemRed),
        .variable: A.foregroundColor(.systemPink),
        .delimiter: A.foregroundColor(.systemGray),
        .number: A.foregroundColor(.systemBrown),
    ]
}
