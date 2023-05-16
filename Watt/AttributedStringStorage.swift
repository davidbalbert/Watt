//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

final class AttributedStringContent: TextContent {
    typealias Location = AttributedString.Index
    typealias TextElement = LayoutManager<AttributedStringContent>.TextElement

    var s: AttributedString
    var layoutManagers: [LayoutManager<AttributedStringContent>] = []

    init() {
        self.s = ""
    }

    init<S>(_ s: S) where S : StringProtocol {
        self.s = AttributedString(s)
    }

    init(_ s: AttributedString) {
        self.s = s
    }

    var string: String {
        String(s.characters[...])
    }

    func addLayoutManager(_ layoutManager: LayoutManager<AttributedStringContent>) {
        layoutManagers.append(layoutManager)
        layoutManager.textContent = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager<AttributedStringContent>) {
        var indices: [Int] = []
        for (i, m) in layoutManagers.enumerated() {
            if m === layoutManager {
                indices.append(i)
            }
        }

        for i in indices.reversed() {
            let m = layoutManagers.remove(at: i)
            m.textContent = nil
        }
    }

    var documentRange: Range<AttributedString.Index> {
        s.startIndex..<s.endIndex
    }

    func enumerateLineRanges(from location: AttributedString.Index, using block: (Range<AttributedString.Index>) -> Bool) {

        var i: AttributedString.Index
        if location != s.startIndex, let lineEnd = s.characters[...location].lastIndex(of: "\n") {
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

            let range = i..<next

            if !block(range) {
                break
            }

            i = range.upperBound
        }

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

    func didSetFont(to font: NSFont) {
        s.font = font
    }
}
