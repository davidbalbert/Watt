//
//  AttributedStringContentManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

final class AttributedStringContentManager: TextContentManager {
    typealias Location = AttributedString.Index
    typealias TextElement = LayoutManager<AttributedStringContentManager>.TextElement

    var storage: AttributedString
    var layoutManagers: [LayoutManager<AttributedStringContentManager>] = []

    // Maps element start index to text element. See LayoutManager.fragmentCache
    // for how capacity was calculated.
    var elementCache: LRUCache<Int, TextElement> = LRUCache(capacity: 300)

    init() {
        self.storage = ""
    }

    init(_ s: String) {
        self.storage = AttributedString(s)
    }

    init(_ s: AttributedString) {
        self.storage = s
    }

    var string: String {
        String(storage.characters[...])
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
        storage.startIndex..<storage.endIndex
    }

    func enumerateLineRanges(from location: AttributedString.Index, using block: (Range<AttributedString.Index>) -> Bool) {

        var i: AttributedString.Index
        if location != storage.startIndex, let lineEnd = storage.characters[...location].lastIndex(of: "\n") {
            i = storage.index(afterCharacter: lineEnd)
        } else {
            i = storage.startIndex
        }

        while i < storage.endIndex {
            let next: AttributedString.Index
            if let newline = storage[i...].characters.firstIndex(of: "\n") {
                next = storage.index(afterCharacter: newline)
            } else {
                next = storage.endIndex
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
        if textLocation != storage.startIndex, let lineEnd = storage.characters[...textLocation].lastIndex(of: "\n") {
            i = storage.index(afterCharacter: lineEnd)
        } else {
            i = storage.startIndex
        }

        var nchars = storage.characters.distance(from: storage.startIndex, to: i)
        while i < storage.endIndex {
            let el: TextElement
            if let e = elementCache[nchars] {
                el = e
            } else {
                let next: AttributedString.Index
                if let newline = storage[i...].characters.firstIndex(of: "\n") {
                    next = storage.index(afterCharacter: newline)
                } else {
                    next = storage.endIndex
                }

                el = TextElement(contentManager: self, textRange: i..<next)
            }

            elementCache[nchars] = el

            if !block(el) {
                break
            }

            nchars += storage.characters.distance(from: i, to: el.textRange.upperBound)
            i = el.textRange.upperBound
        }
    }

    func attributedString(for textElement: TextElement) -> NSAttributedString {
         let substr = storage[textElement.textRange]

        // TODO: is there a way to do this with a single copy instead of two?
        return NSAttributedString(AttributedString(substr))
    }

    func data(using encoding: String.Encoding) -> Data? {
        string.data(using: encoding)
    }

    func didSetFont(to font: NSFont) {
        storage.font = font
        elementCache.removeAll()
    }
}
