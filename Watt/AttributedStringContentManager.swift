//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

final class AttributedStringContentManager: ContentManager {
    typealias Location = AttributedString.Index
    typealias TextElement = LayoutManager<AttributedStringContentManager>.TextElement

    var s: AttributedString
    var layoutManagers: [LayoutManager<AttributedStringContentManager>] = []

    // Maps element start index to text element. See LayoutManager.fragmentCache
    // for how capacity was calculated.
    var elementCache: LRUCache<Int, TextElement> = LRUCache(capacity: 300)

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

    func addLayoutManager(_ layoutManager: LayoutManager<AttributedStringContentManager>) {
        layoutManagers.append(layoutManager)
        layoutManager.contentManager = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager<AttributedStringContentManager>) {
        var indices: [Int] = []
        for (i, m) in layoutManagers.enumerated() {
            if m === layoutManager {
                indices.append(i)
            }
        }

        for i in indices.reversed() {
            let m = layoutManagers.remove(at: i)
            m.contentManager = nil
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

        var nchars = s.characters.distance(from: s.startIndex, to: i)
        while i < s.endIndex {
            let el: TextElement
            if let e = elementCache[nchars] {
                el = e
            } else {
                let next: AttributedString.Index
                if let newline = s[i...].characters.firstIndex(of: "\n") {
                    next = s.index(afterCharacter: newline)
                } else {
                    next = s.endIndex
                }

                el = TextElement(contentManager: self, textRange: i..<next)
            }

            elementCache[nchars] = el

            if !block(el) {
                break
            }

            nchars += s.characters.distance(from: i, to: el.textRange.upperBound)
            i = el.textRange.upperBound
        }
    }

    func attributedString(for textElement: TextElement) -> NSAttributedString {
         let substr = s[textElement.textRange]

        // TODO: is there a way to do this with a single copy instead of two?
        return NSAttributedString(AttributedString(substr))
    }

    func didSetFont(to font: NSFont) {
        s.font = font
        elementCache.removeAll()
    }
}
