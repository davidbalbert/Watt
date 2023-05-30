 //
//  TextStorageContentManager.swift
//  Watt
//
//  Created by David Albert on 5/16/23.
//

import Cocoa

final class ContentManager {
    let storage: NSTextStorage
    var layoutManagers: [LayoutManager] = []

    // One of the more expensive parts of using NSTextStorage is generating attributed
    // substrings for each TextElement. Text elements lazily create their substrings
    // and cache them for the future, which means if we can cache the TextElements
    // themselves, we can increase performance by quite a bit.
    //
    // I arrived at a capacity of 300 empirically:
    //
    // We want to make sure to cache enough TextElements to fit in our scroll view's
    // preparedContentRect. Otherwise we'll end up doing layout and rendering for some
    // of the TextElements we need on every frame of scrolling.
    //
    // NSScrollView varies the size of its prepared content rect based on the size of
    // its frame – the larger the scroll view, the more content it wants to prefetch.
    //
    // The number of layout fragments we can fit in the preparedContentRect depends
    // on how many lines the fragments take up and what font size we're using.
    //
    // To test, I filled a text view with the numbers 1 to 1,000,000, each on their own
    // line, set in Helvetica size 12, which seemed like a reasonable lower bound on the
    // frame size of layout fragments. I resized the window so it took up the height of
    // my 5K Studio Display, and then scrolled to see the maximum number of text layers
    // that ended up in the text view. That ended up being 243.
    //
    // To add some extra padding, I rounded up to 300.
    //
    // Eventually it would be nice to also use an LRUCache for LayoutFragments but
    // I'm going to punt on that for now.
    var elementCache: LRUCache<String.Index, TextElement> = LRUCache(capacity: 300)

    var transactionCount = 0

    init(_ s: String) {
        storage = NSTextStorage(string: s)
    }

    var documentRange: Range<String.Index> {
        storage.string.startIndex..<storage.string.endIndex
    }

    var documentNSRange: NSRange {
        NSRange(location: 0, length: storage.length)
    }

    func enumerateLineRanges(from location: String.Index, using block: (Range<String.Index>) -> Bool) {
        var i: String.Index
        // TODO: at some point I changed storage.string[...location] to storage.string[..<location], but
        // the latter seems more correct. Figure out why. Write some tests. Etc.
        if location != storage.string.startIndex, let lineEnd = storage.string[..<location].lastIndex(of: "\n") {
            i = storage.string.index(after: lineEnd)
        } else {
            i = storage.string.startIndex
        }

        let includeExtraLine = storage.string.isEmpty || storage.string.last == "\n"

        while (i < storage.string.endIndex) || (i == storage.string.endIndex && includeExtraLine) {
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

            if i == storage.string.endIndex && includeExtraLine {
                break
            }

            i = range.upperBound
        }
    }

    func enumerateTextElements(from location: String.Index, using block: (TextElement) -> Bool) {
        var i: String.Index
        // TODO: at some point I changed storage.string[...location] to storage.string[..<location], but
        // the latter seems more correct. Figure out why. Write some tests. Etc.
        if location != storage.string.startIndex, let lineEnd = storage.string[..<location].lastIndex(of: "\n") {
            i = storage.string.index(after: lineEnd)
        } else {
            i = storage.string.startIndex
        }

        let includeExtraLine = storage.string.isEmpty || storage.string.last == "\n"

        while (i < storage.string.endIndex) || (i == storage.string.endIndex && includeExtraLine) {
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

                let range = i..<next
                let substring = storage.string[range]

                el = TextElement(contentManager: self, substring: substring, textRange: range)
            }

            elementCache[i] = el

            if !block(el) {
                break
            }

            if i == storage.string.endIndex && includeExtraLine {
                break
            }

            i = el.textRange.upperBound
        }
    }


    func addLayoutManager(_ layoutManager: LayoutManager) {
        layoutManagers.append(layoutManager)
        layoutManager.contentManager = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager) {
        layoutManagers.removeAll { m in
            if m === layoutManager {
                m.contentManager = nil
                return true
            } else {
                return false
            }
        }
    }

    func attributedSubstring(for textElement: TextElement) -> NSAttributedString {
        let r = NSRange(textElement.textRange, in: storage.string)
        return storage.attributedSubstring(from: r)
    }

    func attributedSubstring(for range: NSRange) -> NSAttributedString {
        storage.attributedSubstring(from: range)
    }

    private func beginEditingTransaction() {
        if transactionCount == 0 {
            storage.beginEditing()
        }

        transactionCount += 1
    }

    private func endEditingTransaction() {
        transactionCount -= 1

        if transactionCount == 0 {
            storage.endEditing()
        }
    }

    func performEditingTransaction(_ transaction: () -> Void) {
        beginEditingTransaction()
        transaction()
        endEditingTransaction()
    }

    func replaceCharacters(in nsRange: NSRange, with string: NSAttributedString) {
        guard let range = Range(nsRange, in: storage.string) else {
            return
        }

        let closedRange = range.lowerBound...storage.string.index(before: range.upperBound)
        let oldSubstring = storage.string[range]

        storage.replaceCharacters(in: nsRange, with: string)

        // TODO: is there a way to make this more efficient?
        // Right now, the strings of many of all the elements following the one
        // we're editing are still valid, but their ranges are not.
        //
        // The top one doesn't work, because we would like to update all
        // the ranges in the cache.
        //
        //        var adjustedLowerBound: String.Index?
        //        enumerateLineRanges(from: range.lowerBound) { lineRange in
        //            adjustedLowerBound = lineRange.lowerBound
        //            return false
        //        }
        //
        //        guard let adjustedLowerBound else {
        //            return
        //        }
        //
        //        let adjustedRange = adjustedLowerBound..<range.upperBound
        //        elementCache.removeAll { key in
        //            adjustedRange.contains(key)
        //        }

        elementCache.removeAll()

        for layoutManager in layoutManagers {
            layoutManager.contentManagerDidReplaceCharacters(self, in: closedRange, with: string, oldSubstring: oldSubstring)
        }
    }

    func data(using encoding: String.Encoding) -> Data? {
        storage.string.data(using: encoding)
    }

    func location(_ location: String.Index, offsetBy offset: Int) -> String.Index {
        storage.string.index(location, offsetBy: offset)
    }

    func location(_ location: String.Index, offsetByUTF16 offset: Int) -> String.Index {
        storage.string.utf16.index(location, offsetBy: offset)
    }

    func offset(from: String.Index, to: String.Index) -> Int {
        storage.string.distance(from: from, to: to)
    }

    func nsRange(from range: Range<String.Index>) -> NSRange {
        NSRange(range, in: storage.string)
    }

    func range(from nsRange: NSRange) -> Range<String.Index>? {
        Range(nsRange, in: storage.string)
    }

    func character(at location: String.Index) -> Character {
        storage.string[location]
    }

    func didSetFont(to font: NSFont) {
        storage.addAttribute(.font, value: font, range: documentNSRange)
        elementCache.removeAll()
    }
}
