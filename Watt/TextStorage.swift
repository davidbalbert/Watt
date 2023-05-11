//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

class TextStorage: ExpressibleByStringLiteral {
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

    var documentRange: Range<AttributedString.Index> {
        s.startIndex..<s.endIndex
    }

    func textElements(for range: Range<AttributedString.Index>) -> [TextElement] {
        var res: [TextElement] = []

        enumerateTextElements(from: range.lowerBound) { element in
            if element.textRange.lowerBound >= range.upperBound {
                return false
            }

            res.append(element)
            return true
        }

        return res
    }

    func enumerateTextElements(from textLocation: AttributedString.Index, using block: (TextElement) -> Bool) {
        var i: AttributedString.Index
        if textLocation != s.startIndex, let lineEnd = s.characters[...textLocation].lastIndex(of: "\n") {
            i = s.index(afterCharacter: lineEnd)
        } else {
            i = s.startIndex
        }

        while i < s.endIndex {
            let next: AttributedString.Index
            if let newline = s[i...].characters.firstIndex(of: "\n") {
                next = s.index(afterCharacter: newline)
            } else {
                next = s.endIndex
            }

            let el = TextElement(textStorage: self, textRange: i..<next)

            if !block(el) {
                break
            }

            i = next
        }
    }

    func attributedString(for textElement: TextElement) -> NSAttributedString {
        let substr = s[textElement.textRange]

        // TODO: is there a way to do this with a single copy instead of two?
        return NSAttributedString(AttributedString(substr))
    }
}
