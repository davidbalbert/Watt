//
//  TextStorageContentManager.swift
//  Watt
//
//  Created by David Albert on 5/16/23.
//

import Cocoa

final class TextStorageContentManager: TextContentManager {
    typealias Location = String.Index
    typealias TextElement = LayoutManager<TextStorageContentManager>.TextElement

    let storage: NSTextStorage
    var layoutManagers: [LayoutManager<TextStorageContentManager>] = []

    // Maps element start index to text element. See LayoutManager.fragmentCache
    // for how capacity was calculated.
    var elementCache: LRUCache<String.Index, TextElement> = LRUCache(capacity: 300)

    init(_ s: String) {
        storage = NSTextStorage(string: s)
    }

    var documentRange: Range<String.Index> {
        storage.string.startIndex..<storage.string.endIndex
    }

    private var documentNSRange: NSRange {
        NSRange(location: 0, length: storage.length)
    }

    func enumerateLineRanges(from location: String.Index, using block: (Range<String.Index>) -> Bool) {
        var i: String.Index
        if location != storage.string.startIndex, let lineEnd = storage.string[...location].lastIndex(of: "\n") {
            i = storage.string.index(after: lineEnd)
        } else {
            i = storage.string.startIndex
        }

        while i < storage.string.endIndex {
            let next: String.Index
            if let newline = storage.string[i...].firstIndex(of: "\n") {
                next = storage.string.index(after: newline)
            } else {
                next = storage.string.endIndex
            }

            let range = i..<next

            if !block(range) {
                break
            }

            i = range.upperBound
        }
    }

    func enumerateTextElements(from location: String.Index, using block: (TextElement) -> Bool) {
        var i: String.Index
        if location != storage.string.startIndex, let lineEnd = storage.string[...location].lastIndex(of: "\n") {
            i = storage.string.index(after: lineEnd)
        } else {
            i = storage.string.startIndex
        }

        while i < storage.string.endIndex {
            let el: TextElement
            if let e = elementCache[i] {
                el = e
            } else {
                let next: String.Index
                if let newline = storage.string[i...].firstIndex(of: "\n") {
                    next = storage.string.index(after: newline)
                } else {
                    next = storage.string.endIndex
                }

                el = TextElement(contentManager: self, textRange: i..<next)
            }

            elementCache[i] = el

            if !block(el) {
                break
            }

            i = el.textRange.upperBound
        }
    }


    func addLayoutManager(_ layoutManager: LayoutManager<TextStorageContentManager>) {
        layoutManagers.append(layoutManager)
        layoutManager.contentManager = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager<TextStorageContentManager>) {
        layoutManagers.removeAll { m in
            if m === layoutManager {
                m.contentManager = nil
                return true
            } else {
                return false
            }
        }
    }

    func attributedString(for textElement: TextElement) -> NSAttributedString {
        let r = NSRange(textElement.textRange, in: storage.string)
        return storage.attributedSubstring(from: r)
    }

    func data(using encoding: String.Encoding) -> Data? {
        storage.string.data(using: encoding)
    }

    func didSetFont(to font: NSFont) {
        storage.addAttribute(.font, value: font, range: documentNSRange)
        elementCache.removeAll()
    }
}
