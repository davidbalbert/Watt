//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

class AttributedStringTextStorage: TextStorage, ExpressibleByStringLiteral {
    var s: AttributedString
    var layoutManagers: [LayoutManager] = []

    init() {
        self.s = ""
    }

    init(_ s: String) {
        self.s = AttributedString(s)
    }

    init(_ s: AttributedString) {
        self.s = s
    }

    required init(stringLiteral stringValue: String) {
        self.s = AttributedString(stringValue)
    }

    var string: String {
        String(s.characters[...])
    }

    func addLayoutManager(_ layoutManager: LayoutManager) {
        layoutManagers.append(layoutManager)
        layoutManager.storage = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager) {
        var indices: [Int] = []
        for (i, m) in layoutManagers.enumerated() {
            if m === layoutManager {
                indices.append(i)
            }
        }

        for i in indices.reversed() {
            let m = layoutManagers.remove(at: i)
            m.storage = nil
        }
    }

    var documentRange: TextRange {
        s.startIndex..<s.endIndex
    }

    func enumerateTextElements(from textLocation: TextLocation, using block: (TextElement) -> Bool) {
        guard let textLocation = textLocation as? AttributedString.Index else {
            return
        }

        var i: AttributedString.Index
        if textLocation != s.startIndex, let lineEnd = s.characters[...textLocation].lastIndex(of: "\n") {
            i = s.index(afterCharacter: lineEnd)
        } else {
            i = s.startIndex
        }

        let last = s.index(s.startIndex, offsetByCharacters: s.characters.count-1)

        while i < s.endIndex {
            let next = s.index(afterCharacter: i)
            let end = s.index(afterCharacter: s.characters[next...].firstIndex(of: "\n") ?? last)

            let el = TextElement(textStorage: self, textRange: i..<end)

            if !block(el) {
                break
            }

            i = end
        }
    }

    func attributedString(for textElement: TextElement) -> NSAttributedString {
        let start = textElement.textRange.start as! AttributedString.Index
        let end = textElement.textRange.end as! AttributedString.Index

        let substr = s[start..<end]

        // TODO: is there a way to do this with a single copy instead of two?
        return NSAttributedString(AttributedString(substr))
    }
}
