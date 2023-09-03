//
//  Buffer.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation

class Buffer {
    typealias Index = AttributedRope.Index

    var contents: AttributedRope
    var layoutManagers: [LayoutManager]

    convenience init() {
        self.init("")
    }

    init(_ string: String) {
        self.contents = AttributedRope(string)
        self.layoutManagers = []
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

    func attributedSubstring(for range: Range<Index>) -> NSAttributedString {
        NSAttributedString(contents[range])
    }

    func addLayoutManager(_ layoutManager: LayoutManager) {
        if layoutManagers.contains(where: { $0 === layoutManager }) {
            return
        }

        layoutManagers.append(layoutManager)
        layoutManager.buffer = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager) {
        layoutManagers.removeAll { $0 === layoutManager }
        layoutManager.buffer = nil
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
        let delta = b.build()

        let old = contents
        contents = contents.applying(delta: delta)

        for layoutManager in layoutManagers {
            layoutManager.bufferContentsDidChange(from: old.text, to: contents.text, delta: delta.ropeDelta)
        }
    }

    func replaceSubrange(_ subrange: Range<Index>, with s: String) {
        var b = AttributedRope.DeltaBuilder(contents)
        b.replaceSubrange(subrange, with: s)
        let delta = b.build()

        let old = contents
        contents = contents.applying(delta: delta)

        for layoutManager in layoutManagers {
            layoutManager.bufferContentsDidChange(from: old.text, to: contents.text, delta: delta.ropeDelta)
        }
    }

    func setAttributes(_ attributes: AttributedRope.Attributes) {
        contents.setAttributes(attributes)

        for layoutManager in layoutManagers {
            layoutManager.attributesDidChange()
        }
    }

    func getAttributes(at i: Index) -> AttributedRope.Attributes {
        contents.getAttributes(at: i)
    }
}

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
