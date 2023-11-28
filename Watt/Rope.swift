//
//  Rope.swift
//
//
//  Created by David Albert on 6/21/23.
//

import Foundation

// MARK: - Core data structures

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children (see BTree.swift)
// leaf nodes are order 1024: 511..<1024 elements (characters), unless it's root, then 0..<1024 (see Chunk.swift)

struct Rope: BTree {
    var root: BTreeNode<RopeSummary>

    init() {
        self.root = BTreeNode<RopeSummary>()
    }

    init(_ root: BTreeNode<RopeSummary>) {
        self.root = root
    }
}

struct RopeSummary: BTreeSummary {
    var utf16: Int
    var scalars: Int
    var chars: Int
    var newlines: Int

    static func += (left: inout RopeSummary, right: RopeSummary) {
        left.utf16 += right.utf16
        left.scalars += right.scalars
        left.chars += right.chars
        left.newlines += right.newlines
    }

    static var zero: RopeSummary {
        RopeSummary()
    }

    init() {
        self.utf16 = 0
        self.scalars = 0
        self.chars = 0
        self.newlines = 0
    }

    init(summarizing chunk: Chunk) {
        self.utf16 = chunk.string.utf16.count
        self.scalars = chunk.string.unicodeScalars.count
        self.chars = chunk.characters.count

        self.newlines = chunk.string.withExistingUTF8 { buf in
            countNewlines(in: buf[...])
        }
    }
}

extension RopeSummary: BTreeDefaultMetric {
    static var defaultMetric: Rope.UTF8Metric { Rope.UTF8Metric() }
}


struct Chunk: BTreeLeaf {
    // measured in base units
    static let minSize = 511
    static let maxSize = 1023

    static var zero: Chunk {
        Chunk()
    }

    var string: String
    var prefixCount: Int

    // a breaker ready to consume the first
    // scalar in the Chunk. Used for prefix
    // calculation in pushMaybeSplitting(other:)
    var startBreakState: Rope.GraphemeBreaker

    // a breaker that has consumed the entirety of string.
    var endBreakState: Rope.GraphemeBreaker

    var count: Int {
        string.utf8.count
    }

    var isUndersized: Bool {
        count < Chunk.minSize
    }

    var firstBreak: String.Index {
        string.utf8Index(at: prefixCount)
    }

    var lastBreak: String.Index {
        if string.isEmpty {
            return string.startIndex
        } else {
            return string.index(before: string.endIndex)
        }
    }

    var characters: Substring {
        string[firstBreak...]
    }

    init() {
        self.string = ""
        self.prefixCount = 0
        self.startBreakState = Rope.GraphemeBreaker()
        self.endBreakState = Rope.GraphemeBreaker()
    }

    init(_ substring: Substring, breaker b: inout Rope.GraphemeBreaker) {
        let s = String(substring)
        assert(s.isContiguousUTF8)
        assert(s.utf8.count <= Chunk.maxSize)

        // save the breaker at the start of the chunk
        self.startBreakState = b

        self.string = s
        self.prefixCount = consumeAndFindPrefixCount(in: s, using: &b)
        self.endBreakState = b
    }

    mutating func pushMaybeSplitting(other: Chunk) -> Chunk? {
        string += other.string
        var b = startBreakState

        if string.utf8.count <= Chunk.maxSize {
            prefixCount = consumeAndFindPrefixCount(in: string, using: &b)
            endBreakState = b
            return nil
        } else {
            let i = boundaryForMerge(string[...])

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])

            prefixCount = consumeAndFindPrefixCount(in: string, using: &b)
            endBreakState = b
            return Chunk(rest[...], breaker: &b)
        }
    }

    static var needsFixupOnAppend: Bool {
        true
    }

    mutating func fixup(withPrevious prev: Chunk) -> Bool {
        var i = string.startIndex
        var first: String.Index?

        var old = startBreakState
        var new = prev.endBreakState

        startBreakState = new

        while i < string.unicodeScalars.endIndex {
            let scalar = string.unicodeScalars[i]
            let a = old.hasBreak(before: scalar)
            let b = new.hasBreak(before: scalar)

            if b {
                first = first ?? i
            }

            if a && b {
                // Found the same break. We're done
                break
            } else if !a && !b && old == new {
                // GraphemeBreakers are in the same state. We're done.
                break
            }

            i = string.unicodeScalars.index(after: i)
        }

        if let first {
            // We found a new first break
            prefixCount = string.utf8.distance(from: string.startIndex, to: first)
        } else if i >= lastBreak {
            // We made it up through lastBreak without finding any breaks
            // and now we're in sync. We know there are no more breaks
            // ahead of us, which means there are no breaks in the chunk.

            // N.b. there is a special case where lastBreak < firstBreak –
            // when there were no breaks in the chunk previously. In that
            // case lastBreak == startIndex and firstBreak == endIndex.

            // But this code works for that situation too. If there were no
            // breaks in the chunk previously, and we get in sync anywhere
            // in the chunk without finding a break, we know there are still
            // no breaks in the chunk, so this code is a no-op.

            prefixCount = string.utf8.count
        } else if i >= firstBreak {
            // We made it up through firstBreak without finding any breaks
            // but we got in sync before lastBreak. Find a new firstBreak:

            let j = string.unicodeScalars.index(after: i)
            var tmp = new
            let first = tmp.firstBreak(in: string[j...])!.lowerBound
            prefixCount = string.utf8.distance(from: string.startIndex, to: first)

            // If this is false, there's a bug in the code, or my assumptions are wrong.
            assert(firstBreak <= lastBreak)
        }

        // There's an implicit else clause to the above– we're in sync, and we
        // didn't even get to the old firstBreak. This means the breaks didn't
        // change at all.

        // We got to the end, either because we're not in sync yet, or because we got
        // in sync at right at the end of the chunk. Save the break state.
        if i == string.endIndex {
            endBreakState = new
        }

        // We're done if we synced up before the end of the chunk.
        return i < string.endIndex
    }

    // fixup(withPrevious:) decides whether we're done or not. fixup(withNext:) is
    // a no-op and should always continue.
    func fixup(withNext next: Chunk) -> Bool {
        false
    }

    subscript(bounds: Range<Int>) -> Chunk {
        let start = string.utf8Index(at: bounds.lowerBound).samePosition(in: string.unicodeScalars)
        let end = string.utf8Index(at: bounds.upperBound).samePosition(in: string.unicodeScalars)

        guard let start, let end else {
            fatalError("invalid unicode scalar offsets")
        }

        var b = startBreakState
        b.consume(string[string.startIndex..<start])
        return Chunk(string[start..<end], breaker: &b)
    }

    func isValidUnicodeScalarIndex(_ i: String.Index) -> Bool {
        i.samePosition(in: string.unicodeScalars) != nil
    }

    func isValidCharacterIndex(_ i: String.Index) -> Bool {
        i == characters._index(roundingDown: i)
    }
}

fileprivate func consumeAndFindPrefixCount(in string: String, using breaker: inout Rope.GraphemeBreaker) -> Int {
    guard let r = breaker.firstBreak(in: string[...]) else {
        // uncommon, no character boundaries
        return string.utf8.count
    }

    breaker.consume(string[r.upperBound...])

    return string.utf8.distance(from: string.startIndex, to: r.lowerBound)
}

// MARK: - Metrics

extension Rope {
    // The base metric, which measures UTF-8 code units.
    struct UTF8Metric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            count
        }

        func convertToBaseUnits(_ measuredUnits: Int, in leaf: Chunk) -> Int {
            measuredUnits
        }

        func convertFromBaseUnits(_ baseUnits: Int, in leaf: Chunk) -> Int {
            baseUnits
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            true
        }

        func prev(_ offset: Int, in chunk: Chunk, prevLeaf: Chunk?) -> Int? {
            assert(offset > 0)
            return offset - 1
        }

        func next(_ offset: Int, in chunk: Chunk, nextLeaf: Chunk?) -> Int? {
            assert(offset < chunk.count)
            return offset + 1
        }

        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF8Metric {
    static var utf8: Rope.UTF8Metric { Rope.UTF8Metric() }
}

// Rope doesn't have a true UTF-16 view like String does. Instead the
// UTF16Metric is mostly useful for counting UTF-16 code units. Its
// prev and next operate the same as UnicodeScalarMetric. Next() and prev()
// will "skip" trailing surrogates, jumping to the next Unicode scalar
// boundary. "Skip" is in quotes because there are not actually any leading
// or trailing surrogates in Rope's storage. It's just Unicode scalars that
// are encoded as UTF-8.
extension Rope {
    struct UTF16Metric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.utf16
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex

            let i = chunk.string.utf16Index(at: measuredUnits)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.string.utf16.distance(from: startIndex, to: i)
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, prevLeaf: Chunk?) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk, nextLeaf: Chunk?) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF16Metric {
    static var utf16: Rope.UTF16Metric { Rope.UTF16Metric() }
}

extension Rope {
    struct UnicodeScalarMetric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.scalars
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex

            let i = chunk.string.unicodeScalarIndex(at: measuredUnits)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.string.unicodeScalars.distance(from: startIndex, to: i)
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, prevLeaf: Chunk?) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk, nextLeaf: Chunk?) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        var canFragment: Bool {
            false
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UnicodeScalarMetric {
    static var unicodeScalars: Rope.UnicodeScalarMetric { Rope.UnicodeScalarMetric() }
}

extension Rope {
    struct CharacterMetric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.chars
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            assert(measuredUnits <= chunk.characters.count)

            let startIndex = chunk.characters.startIndex
            let i = chunk.characters.index(startIndex, offsetBy: measuredUnits)

            assert(chunk.isValidCharacterIndex(i))

            return chunk.prefixCount + chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.characters.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.characters.distance(from: startIndex, to: i)
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            assert(offset < chunk.count)

            if offset < chunk.prefixCount {
                return false
            }

            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidCharacterIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, prevLeaf: Chunk?) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            if current <= chunk.firstBreak {
                return nil
            }

            var target = chunk.string._index(roundingDown: current)
            if target == current {
                target = chunk.string.index(before: target)
            }

            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func needsLookahead(_ offset: Int, in chunk: Chunk) -> Bool {
            let current = chunk.string.utf8Index(at: offset)
            return current >= chunk.lastBreak
        }

        func next(_ offset: Int, in chunk: Chunk, nextLeaf: Chunk?) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            if current >= chunk.lastBreak && (nextLeaf == nil || nextLeaf!.prefixCount > 0) {
                return nil
            }

            let target = chunk.string.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        var canFragment: Bool {
            true
        }

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.CharacterMetric {
    static var characters: Rope.CharacterMetric { Rope.CharacterMetric() }
}

extension Rope {
    struct NewlinesMetric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.newlines
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            let nl = UInt8(ascii: "\n")

            var offset = 0
            var count = 0
            chunk.string.withExistingUTF8 { buf in
                while count < measuredUnits {
                    precondition(offset <= buf.count)
                    offset = buf[offset...].firstIndex(of: nl)! + 1
                    count += 1
                }
            }

            return offset
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            return chunk.string.withExistingUTF8 { buf in
                precondition(baseUnits <= buf.count)
                return countNewlines(in: buf[..<baseUnits])
            }
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            precondition(offset > 0 && offset <= chunk.count)

            return chunk.string.withExistingUTF8 { buf in
                buf[offset - 1] == UInt8(ascii: "\n")
            }
        }

        func prev(_ offset: Int, in chunk: Chunk, prevLeaf: Chunk?) -> Int? {
            precondition(offset > 0 && offset <= chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                buf[..<(offset - 1)].lastIndex(of: nl).map { $0 + 1 }
            }
        }

        func next(_ offset: Int, in chunk: Chunk, nextLeaf: Chunk?) -> Int? {
            precondition(offset >= 0 && offset <= chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                buf[offset...].firstIndex(of: nl).map { $0 + 1 }
            }
        }

        var canFragment: Bool {
            true
        }

        var type: BTreeMetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.NewlinesMetric {
    static var newlines: Rope.NewlinesMetric { Rope.NewlinesMetric() }
}

// MARK: - Builder

// An optimization to unnecessary calls to fixup while building. When we're
// building a Rope out of a long string, we're already running a GraphemeBreaker
// down the length of the string, so all the chunks we create are already in sync.
//
// If we push chunks onto a BTreeBuilder one at a time, fixup will be called on
// each pair, which will be a no-op but slows things down. Instead, we build up
// trees where height=1 in the RopeBuilder and then push those on to the BTreeBuilder,
// skipping the fixup between leaves.
struct RopeBuilder {
    var b: BTreeBuilder<Rope>
    var breaker: Rope.GraphemeBreaker

    init() {
        self.b = BTreeBuilder<Rope>()
        self.breaker = Rope.GraphemeBreaker()
    }

    mutating func push(string: some Sequence<Character>) {
        var string = String(string)
        string.makeContiguousUTF8()

        var i = string.startIndex
        var br = breaker

        let iter = AnyIterator<Chunk> {
            if i == string.endIndex {
                return nil
            }

            let n = string.utf8.distance(from: i, to: string.endIndex)

            let end: String.Index
            if n <= Chunk.maxSize {
                end = string.endIndex
            } else {
                end = boundaryForBulkInsert(string[i...])
            }

            let chunk = Chunk(string[i..<end], breaker: &br)
            i = end

            return chunk
        }

        b.push(leaves: iter)
        breaker = br
    }

    mutating func push(_ rope: inout Rope) {
        breaker = Rope.GraphemeBreaker(for: rope, upTo: rope.endIndex)
        b.push(&rope.root)
    }

    mutating func push(_ rope: inout Rope, slicedBy range: Range<Rope.Index>) {
        breaker = Rope.GraphemeBreaker(for: rope, upTo: range.upperBound)
        b.push(&rope.root, slicedBy: Range(range))
    }

    consuming func build() -> Rope {
        return b.build()
    }
}

fileprivate func boundaryForBulkInsert(_ s: Substring) -> String.Index {
    boundary(for: s, startingAt: Chunk.minSize)
}

fileprivate func boundaryForMerge(_ s: Substring) -> String.Index {
    // for the smallest chunk that needs splitting (n = maxSize + 1 = 1024):
    // minSplit = max(511, 1024 - 1023) = max(511, 1) = 511
    // maxSplit = min(1023, 1024 - 511) = min(1023, 513) = 513
    boundary(for: s, startingAt: max(Chunk.minSize, s.utf8.count - Chunk.maxSize))
}

fileprivate func boundary(for s: Substring, startingAt minSplit: Int) -> String.Index {
    let maxSplit = min(Chunk.maxSize, s.utf8.count - Chunk.minSize)

    precondition(minSplit >= 1 && maxSplit <= s.utf8.count)

    let nl = UInt8(ascii: "\n")
    let lineBoundary = s.withExistingUTF8 { buf in
        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
    }

    let offset = lineBoundary ?? maxSplit
    let i = s.utf8Index(at: offset)
    return s.unicodeScalars._index(roundingDown: i)
}


// MARK: - Index additions

extension Rope.Index {
    func readUTF8() -> UTF8.CodeUnit? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    func readScalar() -> Unicode.Scalar? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)
        assert(chunk.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars[i]
    }

    func readChar() -> Character? {
        guard var (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        let ci = chunk.string.utf8Index(at: offset)

        assert(chunk.isValidCharacterIndex(ci))

        if ci < chunk.lastBreak {
            // the common case, the full character is in this chunk
            return chunk.string[ci]
        }

        var end = self
        if end.next(using: .characters) == nil {
            end = BTreeNode(storage: rootStorage!).endIndex
        }

        var s = ""
        s.reserveCapacity(end.position - position)

        var i = self
        while true {
            let count = min(chunk.count - offset, end.position - i.position)

            let endOffset = offset + count
            assert(endOffset <= chunk.count)

            let cstart = chunk.string.utf8Index(at: offset)
            let cend = chunk.string.utf8Index(at: endOffset)

            s += chunk.string[cstart..<cend]

            if i.position + count == end.position {
                break
            }

            (chunk, offset) = i.nextLeaf()!
        }

        assert(s.count == 1)
        return s[s.startIndex]
    }

    func readLine() -> Substring? {
        guard var (chunk, offset) = read() else {
            return nil
        }

        // An optimization: if the entire line is within
        // the chunk, return a Substring.
        var end = self
        if let endOffset = end.next(withinLeafUsing: .newlines) {
            let i = chunk.string.utf8Index(at: offset)
            let j = chunk.string.utf8Index(at: endOffset - offsetOfLeaf)

            return chunk.string[i..<j]
        }

        end = self
        if end.next(using: .newlines) == nil {
            end = BTreeNode(storage: rootStorage!).endIndex
        }

        var s = ""
        s.reserveCapacity(end.position - position)

        var i = self
        while true {
            let count = min(chunk.count - offset, end.position - i.position)

            let endOffset = offset + count
            assert(endOffset <= chunk.count)

            let cstart = chunk.string.utf8Index(at: offset)
            let cend = chunk.string.utf8Index(at: endOffset)

            s += chunk.string[cstart..<cend]

            if i.position + count == end.position {
                break
            }

            (chunk, offset) = i.nextLeaf()!
        }

        return s[...]
    }
}

extension Rope.Index: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(position)[utf8]"
    }
}


// MARK: - Collection conformances

// TODO: audit default methods from Collection, BidirectionalCollection and RangeReplaceableCollection for default implementations that perform poorly.
extension Rope: Collection {
    typealias Index = BTreeNode<RopeSummary>.Index

    var count: Int {
        root.measure(using: .characters)
    }

    var startIndex: Index {
        root.startIndex
    }

    var endIndex: Index {
        root.endIndex
    }

    subscript(position: Index) -> Character {
        root.index(roundingDown: position, using: .characters).readChar()!
    }

    subscript(bounds: Range<Index>) -> Rope {
        let start = index(roundingDown: bounds.lowerBound)
        let end = index(roundingDown: bounds.upperBound)
        return Rope(root, slicedBy: Range(start..<end))
    }

    func index(after i: Index) -> Index {
        root.index(after: i, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        root.index(i, offsetBy: distance, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        root.index(i, offsetBy: distance, limitedBy: limit, using: .characters)
    }

    func distance(from start: Rope.Index, to end: Rope.Index) -> Int {
        root.distance(from: start, to: end, using: .characters)
    }
}

extension Rope: BidirectionalCollection {
    func index(before i: Index) -> Index {
        root.index(before: i, using: .characters)
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        let rangeStart = index(roundingDown: subrange.lowerBound)
        let rangeEnd = index(roundingDown: subrange.upperBound)

        // We have to ensure that root isn't mutated directly because that would
        // invalidate indices and counts when we push the suffix (rangeEnd..<endIndex)
        // onto the builder.
        //
        // A nice optimization would be to make BTreeBuilder more like the RopeBuilder
        // in swift-collections, which has two stacks: a prefix stack descending in
        // height, and a suffix stack ascending in height. Then you have a "split"
        // operation that pushes the prefix and suffix onto the builder simultaneously
        // and then push() pushes in between prefix and suffix.
        //
        // Pushing both the prefix and suffix onto the builder in one step should
        // make the copying here unnecessary.
        var dup = self

        if var new = newElements as? Rope {
            var b = RopeBuilder()
            b.push(&dup, slicedBy: startIndex..<rangeStart)
            b.push(&new)
            b.push(&dup, slicedBy: rangeEnd..<endIndex)
            self = b.build()

            return
        }

        var b = RopeBuilder()
        b.push(&dup, slicedBy: startIndex..<rangeStart)
        b.push(string: newElements)
        b.push(&dup, slicedBy: rangeEnd..<endIndex)

        self = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, S.Element == Element {
        if var r = newElements as? Rope {
            var b = RopeBuilder()
            b.push(&self)
            b.push(&r)
            self = b.build()
            return
        }

        var b = RopeBuilder()
        b.push(&self)
        b.push(string: newElements)
        self = b.build()
    }
}

// MARK: - Conveniences

// A few niceties that make Rope more like String.
extension Rope {
    static func + (_ left: Rope, _ right: Rope) -> Rope {
        var l = left
        var r = right

        var b = RopeBuilder()
        b.push(&l)
        b.push(&r)
        return b.build()
    }

    mutating func append(_ string: String) {
        append(contentsOf: string)
    }

    mutating func append(_ rope: Rope) {
        append(contentsOf: rope)
    }

    func index(roundingDown i: Index) -> Index {
        root.index(roundingDown: i, using: .characters)
    }
}

// Some convenience methods that make string indexing not
// a total pain to work with.
extension Rope {
    func index(at offset: Int) -> Index {
        root.index(at: offset, using: .characters)
    }

    subscript(offset: Int) -> Character {
        self[root.index(at: offset, using: .characters)]
    }

    subscript(bounds: Range<Int>) -> Rope {
        self[index(at: bounds.lowerBound)..<index(at: bounds.upperBound)]
    }
}

// MARK: - Grapheme breaking

extension Rope {
    struct GraphemeBreaker: Equatable {
        #if swift(<5.9)
        static func == (lhs: GraphemeBreaker, rhs: GraphemeBreaker) -> Bool {
            false
        }
        #endif

        var recognizer: Unicode._CharacterRecognizer

        init(_ recognizer: Unicode._CharacterRecognizer = Unicode._CharacterRecognizer(), consuming s: Substring? = nil) {
            self.recognizer = recognizer

            if let s {
                consume(s)
            }
        }

        // assumes upperBound is valid in rope
        init(for rope: Rope, upTo upperBound: Rope.Index, withKnownNextScalar next: Unicode.Scalar? = nil) {
            assert(upperBound.isBoundary(in: .unicodeScalars))

            if rope.isEmpty || upperBound.position == 0 {
                self.init()
                return
            }

            if upperBound == rope.endIndex {
                let (leaf, _) = upperBound.read()!

                self = leaf.endBreakState
                return
            }

            if let next {
                let i = rope.unicodeScalars.index(before: upperBound)
                let prev = rope.unicodeScalars[i]

                if Unicode._CharacterRecognizer.quickBreak(between: prev, and: next) ?? false {
                    self.init()
                    return
                }
            }

            let (chunk, offset) = upperBound.read()!
            let i = chunk.string.utf8Index(at: offset)

            if i <= chunk.firstBreak {
                self.init(chunk.startBreakState.recognizer, consuming: chunk.string[..<i])
                return
            }

            let prev = chunk.characters.index(before: i)

            self.init(consuming: chunk.string[prev..<i])
        }

        mutating func hasBreak(before next: Unicode.Scalar) -> Bool {
            recognizer.hasBreak(before: next)
        }

        mutating func firstBreak(in s: Substring) -> Range<String.Index>? {
            let r = s.withExistingUTF8 { buf in
                recognizer._firstBreak(inUncheckedUnsafeUTF8Buffer: buf)
            }

            if let r {
                return s.utf8Index(at: r.lowerBound)..<s.utf8Index(at: r.upperBound)
            } else {
                return nil
            }
        }

        mutating func consume(_ s: Substring) {
            for u in s.unicodeScalars {
                _ = recognizer.hasBreak(before: u)
            }
        }
    }
}


// MARK: - Views

extension Rope {
    var utf8: UTF8View {
        UTF8View(root: root)
    }

    struct UTF8View {
        var root: BTreeNode<RopeSummary>

        func index(at offset: Int) -> Index {
            root.index(at: offset, using: .utf8)
        }

        func index(roundingDown i: Index) -> Index {
            i.validate(for: root)
            return i
        }

        subscript(offset: Int) -> UTF8.CodeUnit {
            self[root.index(at: offset, using: .utf8)]
        }
    }
}

extension Rope.UTF8View: BidirectionalCollection {
    var startIndex: Rope.Index {
        root.startIndex
    }

    var endIndex: Rope.Index {
        root.endIndex
    }

    subscript(position: Rope.Index) -> UTF8.CodeUnit {
        position.validate(for: root)
        return position.readUTF8()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        root.index(before: i, using: .utf8)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        root.index(after: i, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        root.index(i, offsetBy: distance, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        root.index(i, offsetBy: distance, limitedBy: limit, using: .utf8)
    }

    func distance(from start: Rope.Index, to end: Rope.Index) -> Int {
        root.distance(from: start, to: end, using: .utf8)
    }

    var count: Int {
        root.measure(using: .utf8)
    }
}

// We don't have a full UTF-16 view because dealing with trailing surrogates
// was a pain. If we need it, we'll add it.
//
// TODO: if we add a proper UTF-16 view, make sure to change the block passed
// to CTLineEnumerateCaretOffsets in layoutInsertionPoints to remove the
// prev == i check and replace it with i.isBoundary(in: .characters), as
// buffer.utf16.index(_:offsetBy:) will no longer round down. If we don't
// do this, our ability to click on a line fragment after an emoji will fail.
extension Rope {
    var utf16: UTF16View {
        UTF16View(root: root)
    }

    struct UTF16View {
        var root: BTreeNode<RopeSummary>

        var count: Int {
            root.measure(using: .utf16)
        }

        func index(_ i: Index, offsetBy distance: Int) -> Index {
            root.index(i, offsetBy: distance, using: .utf16)
        }

        func distance(from start: Index, to end: Index) -> Int {
            root.distance(from: start, to: end, using: .utf16)
        }
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(root: root)
    }

    struct UnicodeScalarView {
        var root: BTreeNode<RopeSummary>

        func index(at offset: Int) -> Index {
            root.index(at: offset, using: .unicodeScalars)
        }

        func index(roundingDown i: Index) -> Index {
            root.index(roundingDown: i, using: .unicodeScalars)
        }

        subscript(offset: Int) -> UnicodeScalar {
            self[root.index(at: offset, using: .unicodeScalars)]
        }
    }
}

extension Rope.UnicodeScalarView: BidirectionalCollection {
    var startIndex: Rope.Index {
        root.startIndex
    }

    var endIndex: Rope.Index {
        root.endIndex
    }

    subscript(position: Rope.Index) -> Unicode.Scalar {
        root.index(roundingDown: position, using: .unicodeScalars).readScalar()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        root.index(before: i, using: .unicodeScalars)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        root.index(after: i, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        root.index(i, offsetBy: distance, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        root.index(i, offsetBy: distance, limitedBy: limit, using: .unicodeScalars)
    }

    func distance(from start: Rope.Index, to end: Rope.Index) -> Int {
        root.distance(from: start, to: end, using: .unicodeScalars)
    }

    var count: Int {
        root.measure(using: .unicodeScalars)
    }
}

extension Rope {
    var lines: LinesView {
        LinesView(root: root)
    }

    struct LinesView {
        var root: BTreeNode<RopeSummary>

        func index(at offset: Int) -> Index {
            // The LinesView has one more line than the newlines
            // metric, which counts the number of characters (e.g.
            // a string with a single "\n" has two lines).
            //
            // This means we need to special case all of our index
            // functions to deal with endIndex.
            if offset == count {
                return root.endIndex
            }

            return root.index(at: offset, using: .newlines)
        }

        func index(roundingDown i: Index) -> Index {
            root.index(roundingDown: i, using: .newlines)
        }

        func index(roundingUp i: Index) -> Index {
            i.validate(for: root)

            if i.isBoundary(in: .newlines) || i == endIndex {
                return i
            }

            return index(after: i)
        }

        subscript(offset: Int) -> Substring {
            self[root.index(at: offset, using: .newlines)]
        }
    }
}

extension Rope.LinesView: BidirectionalCollection {
    // TODO: I'd like to remove this and just use IndexingIterator,
    // but I can't until I fix RopeTests.testMoveToLastLineIndexInEmptyRope
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> Substring? {
            guard let line = index.readLine() else {
                return nil
            }

            index.next(using: .newlines)
            return line
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: root.startIndex)
    }

    var startIndex: Rope.Index {
        root.startIndex
    }

    var endIndex: Rope.Index {
        root.endIndex
    }

    // TODO: make this a Subrope so we don't allocate a big String.
    subscript(position: Rope.Index) -> Substring {
        position.validate(for: root)
        return root.index(roundingDown: position, using: .newlines).readLine()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        i.validate(for: root)
        return root.index(before: i, using: .newlines)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        i.validate(for: root)

        // Does this slow things down? Is there a nicer way to do this?
        if i >= index(before: endIndex) && i < endIndex {
            return endIndex
        }

        return root.index(after: i, using: .newlines)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        i.validate(for: root)

        var i = i
        let m = root.count(.newlines, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= count, "Index out of bounds")
        if m + distance == count {
            return endIndex
        }
        let pos = root.countBaseUnits(upThrough: m + distance, measuredIn: .newlines)
        i.set(pos)

        return i
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        i.validate(for: root)
        limit.validate(for: root)

        var l = root.distance(from: i, to: limit, using: .newlines)

        // there's always one more line than # of "\n" characters
        if limit.position == endIndex.position {
            l += 1
        }

        // This is a hack and I have no idea if it's right. My mind is too wooly.
        if distance > 0 && i.position > limit.position && l == 0 {
            l -= 1
        } else if distance < 0 && i.position < limit.position && l == 0 {
            l += 1
        }

        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }

        return index(i, offsetBy: distance)
    }

    func distance(from start: Rope.Index, to end: Rope.Index) -> Int {
        root.distance(from: start, to: end, using: .newlines)
    }

    var count: Int {
        root.measure(using: .newlines) + 1
    }
}

extension Rope: Equatable {
    static func == (lhs: Rope, rhs: Rope) -> Bool {
        if lhs.root == rhs.root {
            return true
        }

        if lhs.utf8.count != rhs.utf8.count {
            return false
        }

        if lhs.root.leaves.count != rhs.root.leaves.count {
            return false
        }

        for (l, r) in zip(lhs.root.leaves, rhs.root.leaves) {
            if l.string != r.string {
                return false
            }
        }

        return true
    }
}


// MARK: - Standard library integration

extension Rope: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension String {
    init(_ rope: Rope) {
        self.init()
        self.reserveCapacity(rope.utf8.count)
        for chunk in rope.root.leaves {
            append(chunk.string)
        }
    }
}

extension NSString {
    convenience init(_ rope: Rope) {
        self.init(string: String(rope))
    }
}

extension Data {
    init(_ rope: Rope) {
        self.init(capacity: rope.utf8.count)
        for chunk in rope.root.leaves {
            chunk.string.withExistingUTF8 { p in
                append(p.baseAddress!, count: p.count)
            }
        }
    }
}

extension Range where Bound == Rope.Index {
    init?(_ range: NSRange, in rope: Rope) {
        if range == .notFound {
            return nil
        }

        guard range.lowerBound >= 0 && range.lowerBound <= rope.utf16.count else {
            return nil
        }

        guard range.upperBound >= 0 && range.upperBound <= rope.utf16.count else {
            return nil
        }

        var i = rope.root.countBaseUnits(upThrough: range.lowerBound, measuredIn: .utf16)
        var j = rope.root.countBaseUnits(upThrough: range.upperBound, measuredIn: .utf16)

        // NSTextInputClient seems to sometimes receive ranges that start
        // or end on a trailing surrogate. Round them to the nearest
        // unicode scalar.
        if rope.root.count(.utf16, upThrough: i) != range.lowerBound {
            assert(rope.root.count(.utf16, upThrough: i) == range.lowerBound - 1)
            print("!!! got NSRange starting on a trailing surrogate: \(range). I think this is expected, but try to reproduce and figure out if it's ok")
            i -= 1
        }

        if rope.root.count(.utf16, upThrough: j) != range.upperBound {
            assert(rope.root.count(.utf16, upThrough: j) == range.upperBound - 1)
            j += 1
        }

        self.init(uncheckedBounds: (rope.utf8.index(at: i), rope.utf8.index(at: j)))
    }

    init(_ range: Range<Int>, in rope: Rope) {
        precondition(range.lowerBound >= 0 || range.lowerBound < rope.utf8.count + 1, "lowerBound is out of bounds")
        precondition(range.upperBound >= 0 || range.upperBound < rope.utf8.count + 1, "upperBound is out of bounds")

        let i = range.lowerBound
        let j = range.upperBound

        self.init(uncheckedBounds: (rope.utf8.index(at: i), rope.utf8.index(at: j)))
    }
}

extension Range where Bound == Int {
    init(_ range: Range<Rope.Index> , in rope: Rope) {
        let start = rope.utf8.distance(from: rope.utf8.startIndex, to: range.lowerBound)
        let end = rope.utf8.distance(from: rope.utf8.startIndex, to: range.upperBound)

        self.init(uncheckedBounds: (start, end))
    }
}

extension NSRange {
    init<R>(_ region: R, in rope: Rope) where R : RangeExpression, R.Bound == Rope.Index {
        let range = region.relative(to: rope)

        range.lowerBound.validate(for: rope.root)
        range.upperBound.validate(for: rope.root)

        assert(range.lowerBound.position >= 0 && range.lowerBound.position <= rope.root.count)
        assert(range.upperBound.position >= 0 && range.upperBound.position <= rope.root.count)

        // TODO: is there a reason the majority of this initializer isn't just distance(from:to:)?
        let i = rope.root.count(.utf16, upThrough: range.lowerBound.position)
        let j = rope.root.count(.utf16, upThrough: range.upperBound.position)

        self.init(location: i, length: j-i)
    }
}

// MARK: - Helpers

fileprivate func countNewlines(in buf: Slice<UnsafeBufferPointer<UInt8>>) -> Int {
    let nl = UInt8(ascii: "\n")
    var count = 0

    for b in buf {
        if b == nl {
            count += 1
        }
    }

    return count
}

