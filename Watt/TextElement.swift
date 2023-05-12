//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension LayoutManager {
    struct TextElement {
        weak var textStorage: Storage?
        let textRange: Range<Location>

        var attributedString: NSAttributedString {
            guard let textStorage else {
                return NSAttributedString("")
            }

            return textStorage.attributedString(for: self)
        }
    }
}
