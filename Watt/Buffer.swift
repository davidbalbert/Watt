//
//  Buffer.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation

protocol BufferDelegate: AnyObject {
    func buffer(_ buffer: Buffer, contentsDidChangeFrom old: Rope, to new: Rope, withDelta delta: BTreeDelta<Rope>)
    func buffer(_ buffer: Buffer, attributesDidChangeIn ranges: [Range<Buffer.Index>])
}

class Buffer {
    typealias Index = AttributedRope.Index

    var contents: AttributedRope

    var language: Language {
        didSet {
            highlighter = language.highlighter
        }
    }

    var highlighter: Highlighter? {
        didSet {
            highlighter?.delegate = self
        }
    }

    var delegates: WeakSet<BufferDelegate>

    convenience init() {
        self.init("", language: .plainText)
    }

    init(_ string: String, language: Language) {
        self.contents = AttributedRope(string)
        self.language = language
        self.delegates = WeakSet<BufferDelegate>()

        self.highlighter = language.highlighter
        highlighter?.delegate = self
    }

    var data: Data {
        Data(contents.text)
    }

    var utf8: Rope.UTF8View {
        contents.text.utf8
    }

    var utf16: Rope.UTF16View {
        contents.text.utf16
    }

    var characters: AttributedRope.CharacterView {
        contents.characters
    }

    var lines: Rope.LinesView {
        contents.text.lines
    }

    var runs: AttributedRope.Runs {
        contents.runs
    }

    var documentRange: Range<Index> {
        contents.startIndex..<contents.endIndex
    }

    var text: Rope {
        contents.text
    }

    var count: Int {
        contents.count
    }

    var isEmpty: Bool {
        count == 0
    }

    var startIndex: Index {
        contents.startIndex
    }

    var endIndex: Index {
        contents.endIndex
    }

    subscript(position: Index) -> Character {
        contents.text[position]
    }

    subscript(bounds: Range<Index>) -> AttributedSubrope {
        contents[bounds]
    }

    func index(before i: Index) -> Index {
        contents.index(beforeCharacter: i)
    }

    func index(after i: Index) -> Index {
        contents.index(afterCharacter: i)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        contents.index(i, offsetByCharacters: distance)
    }

    func index(at offset: Int) -> Index {
        contents.index(startIndex, offsetByCharacters: offset)
    }

    func index(fromOldIndex oldIndex: Index) -> Index {
        utf8.index(at: oldIndex.position)
    }

    func addDelegate(_ delegate: BufferDelegate) {
        delegates.insert(delegate)
        highlighter?.highlightIfNecessary()
    }

    func removeDelegate(_ delegate: BufferDelegate) {
        delegates.remove(delegate)
   }

    // TODO: at some point, we're going to add editing transactions. You will be
    // able to open a transaction, make a bunch of edits, and then end the transaction
    // and only at that point will the layoutManagers get notified of the edits.
    //
    // But each individual edit has to be visible in the contents of the buffer!
    //
    // We need to have a full delta of all the edits to pass to the layout managers.
    // There are two ways we can get this:
    //
    // 1. Update the rope directly and then diff the start and end states to generate
    //    a delta. This is expensive.
    // 2. Build a small delta for each edit, and then accumulate it in a larger delta.
    //
    // The second option is more desirable, but it comes with a few issues:
    //
    // The baseCounts of each delta must be compatible. This means if you have
    // deltas A and B, B's baseCount must be equal to the count of a hypothetical
    // rope after applying A. I.e. A.baseCount is the length of a rope before applying
    // A, and A's elements encode a series of operations that will eventually result
    // in a new rope with a potentially new length. B's delta has to be that new length.
    //
    // It's trivial to build a new Delta with the correct baseCount. At every call to
    // replaceSubrange, we have the rope as it currently is, and it's count is the new
    // base count. The harder bit is verifying that B is able to be concatinated on to A.
    //
    // The start and end of each copyin B, as well as the inclusion or exclusion of each
    // element in B have to be adjusted by whatever effect A had on the underlying rope.
    // Here's an example:
    //
    // We insert 3 characters, one after the other, in three calls to replaceSubrange.
    // The calls look like this:
    //   replaceSubrange(10..<10, with: "a")
    //   replaceSubrange(11..<11, with: "b")
    //   replaceSubrange(12..<12, with: "c")
    //
    // Each individual delta will look like this:
    //   copy(0, 10), insert("a"), copy(10, 100)
    //   copy(0, 11), insert("b"), copy(11, 101)
    //   copy(0, 12), insert("b"), copy(12, 102)
    //
    // The combined delta has to look like this:
    //   copy(0, 10), insert("a"), insert("b"), insert("c"), copy(10, 100)
    //
    // Notice that the copies from the second and third deltas have been removed.
    //
    // Is it possible that this is Operational Transform? I'm not sure.
    //
    // Even worse, we might make a change near the end of a string, and then make another
    // change near the beginning of the string. A DeltaBuilder expects the elements to be
    // in ascending order. How would we do this? Maybe not use a DeltaBuilder to accumulate?
    // I'm really not sure, but that doesn't seem great.
    //
    // This will also be important for Undo/Redo.
    func replaceSubrange(_ subrange: Range<Index>, with attrRope: AttributedRope) {
        var b = AttributedRope.DeltaBuilder(contents)
        b.replaceSubrange(subrange, with: attrRope)
        applying(delta: b.build())
    }

    func replaceSubrange(_ subrange: Range<Index>, with s: String) {
        var b = AttributedRope.DeltaBuilder(contents)
        b.replaceSubrange(subrange, with: s)
        applying(delta: b.build())
    }

    func applying(delta: AttributedRope.Delta) {
        let old = contents
        contents = contents.applying(delta: delta)

        for delegate in delegates {
            delegate.buffer(self, contentsDidChangeFrom: old.text, to: contents.text, withDelta: delta.ropeDelta)
        }

        // For now, this must be done after the layout managers are notified of the
        // changed content, because highlighting triggers highlighter(_:applyTokens:),
        // which calls LayoutManager.attributesDidChange(in:), potentially referring
        // to locations in the text that the layout manager doesn't yet know about.
        // When I understand these interactions better, it might be possible for the
        // content and attribute changes to be updated in one go.
        highlighter?.contentsDidChange(from: old.text, to: contents.text, delta: delta.ropeDelta)
        highlighter?.highlight()
    }

    func setAttributes(_ attributes: AttributedRope.Attributes, in range: Range<Index>? = nil) {
        let range = range ?? documentRange

        contents[range].setAttributes(attributes)

        for delegate in delegates {
            delegate.buffer(self, attributesDidChangeIn: [range])
        }
    }

    func mergeAttributes(_ attributes: AttributedRope.Attributes, in range: Range<Index>? = nil) {
        let range = range ?? documentRange

        contents[range].mergeAttributes(attributes)

        for delegate in delegates {
            delegate.buffer(self, attributesDidChangeIn: [range])
        }
    }

    func getAttributes(at i: Index) -> AttributedRope.Attributes {
        contents.getAttributes(at: i)
    }

    func applyTokens(_ tokens: [Token]) {
        var ranges: [Range<Index>] = []

        for t in tokens {
            let r = Range(t.range, in: contents)
            ranges.append(r)
            contents[r].token = t
        }

        for delegate in delegates {
            delegate.buffer(self, attributesDidChangeIn: ranges)
        }
    }
}

extension Buffer: HighlighterDelegate {
    func highlighter(_ highlighter: Highlighter, applyTokens tokens: [Token]) {
        applyTokens(tokens)
    }

    func highlighter(_ highlighter: Highlighter, parser: TreeSitterParser, readSubstringStartingAt byteIndex: Int) -> Substring? {
        let i = text.utf8.index(at: byteIndex)
        guard let (chunk, offset) = i.read() else {
            return nil
        }

        return chunk.string[chunk.string.utf8Index(at: offset)...]
    }

    func highlighter(_ highlighter: Highlighter, stringForByteRange range: Range<Int>) -> String {
        let range = Range(range, in: text)
        return String(text[range])
    }
}

// MARK: - Word view

extension Buffer {
    var words: WordsView {
        WordsView(buffer: self)
    }

    struct WordsView: BidirectionalCollection {
        let buffer: Buffer
        
        var startIndex: Index {
            buffer.startIndex
        }
        
        var endIndex: Index {
            buffer.startIndex
        }
        
        func index(before i: Index) -> Index {
            var i = i
            while i > startIndex && !isWordCharacter(buffer[i]) {
                i = buffer.index(before: i)
            }
            while i > startIndex && isWordCharacter(buffer[i]) {
                i = buffer.index(before: i)
            }
            
            return i
        }
        
        func index(after i: Index) -> Index {
            var i = i
            while i < endIndex && !isWordCharacter(buffer[i]) {
                i = buffer.index(after: i)
            }
            while i < endIndex && isWordCharacter(buffer[i]) {
                i = buffer.index(after: i)
            }
            
            return i
        }
        
        func index(roundingDown i: Index) -> Index {
            if wordStartsAt(i) {
                return i
            }
            
            return index(before: i)
        }
        
        subscript(position: Index) -> String? {
            if buffer.isEmpty {
                return nil
            }
            
            var i = index(roundingDown: position)
            
            if i == startIndex && !isWordCharacter(buffer[i]) {
                i = index(after: i)
            }
            
            if i == endIndex {
                return nil
            }
            
            let start = i
            let end = index(after: i)
            
            return String(buffer[start..<end])
        }
        
        private func wordStartsAt(_ i: Index) -> Bool {
            if buffer.isEmpty || i == buffer.endIndex {
                return false
            }
            
            if i == buffer.startIndex {
                return isWordCharacter(buffer[i])
            }
            
            let prev = buffer.index(before: i)
            return !isWordCharacter(buffer[prev]) && isWordCharacter(buffer[i])
        }
        
        private func isWordCharacter(_ c: Character) -> Bool {
            buffer.language.isWordCharacter(c)
        }
    }
}

// MARK: - Ranges

extension Range where Bound == Buffer.Index {
    init?(_ range: NSRange, in buffer: Buffer) {
        self.init(range, in: buffer.text)
    }
}

extension NSRange {
    init<R>(_ region: R, in buffer: Buffer) where R : RangeExpression, R.Bound == Buffer.Index {
        self.init(region, in: buffer.text)
    }
}
