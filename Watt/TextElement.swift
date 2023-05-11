//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

struct TextElement<Storage> where Storage: TextStorage {
    weak var textStorage: Storage?
    let textRange: Range<Storage.Location>

    var attributedString: NSAttributedString {
        guard let textStorage else {
            return NSAttributedString("")
        }

        return textStorage.attributedString(for: self)
    }
}
