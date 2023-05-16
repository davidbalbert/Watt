//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension LayoutManager {
    struct TextElement {
        weak var textContent: Content?
        let textRange: Range<Location>

        var attributedString: NSAttributedString {
            guard let textContent else {
                return NSAttributedString("")
            }

            return textContent.attributedString(for: self)
        }
    }
}
