//
//  TextElement.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension LayoutManager {
    struct TextElement: Identifiable {
        var id: UUID = UUID()

        weak var contentManager: ContentManager?
        let substring: Substring
        let textRange: Range<Location>

        var length: Int {
            substring.count
        }

        lazy var attributedString: NSAttributedString = {
            guard let contentManager else {
                return NSAttributedString("")
            }

            return contentManager.attributedString(for: self)
        }()
    }
}
