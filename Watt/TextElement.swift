//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension LayoutManager {
    struct TextElement {
        weak var contentManager: ContentManager?
        let textRange: Range<Location>

        var attributedString: NSAttributedString {
            guard let contentManager else {
                return NSAttributedString("")
            }

            return contentManager.attributedString(for: self)
        }
    }
}
