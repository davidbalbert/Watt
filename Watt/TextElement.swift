//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

struct TextElement {
    weak var textStorage: TextStorage?
    let textRange: TextRange

    var attributedString: NSAttributedString {
        guard let textStorage else {
            return NSAttributedString("")
        }

        return textStorage.attributedString(for: self)
    }
}
