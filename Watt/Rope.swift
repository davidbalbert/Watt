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
    static var needsFixupOnAppend: Bool {
        true
    }

    // measured in base units
    static let minSize = 511
    static let maxSize = 1023

    static var zero: Chunk {
        Chunk()
    }

    var string: String

    // The number of bytes that continue a grapheme from
    // the previous chunk.
    var prefixCount: Int

    // does the last grapheme continue on to the next Chunk
    var lastCharSplits: Bool

    // a breaker ready to consume the first
    // scalar in the Chunk. Used for prefix
    // calculation in pushMaybeSplitting(other:)
    // and fixup(withNext:)
    var breaker: Rope.GraphemeBreaker

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
        self.lastCharSplits = false
        self.breaker = Rope.GraphemeBreaker()
    }

    init(_ substring: Substring, breaker b: inout Rope.GraphemeBreaker) {
        let s = String(substring)
        assert(s.isContiguousUTF8)
        assert(s.utf8.count <= Chunk.maxSize)

        // save the breaker at the start of the chunk
        self.breaker = b

        self.string = s
        self.prefixCount = consumeAndFindPrefixCount(in: s, using: &b)
        self.lastCharSplits = false
    }

    mutating func pushMaybeSplitting(other: Chunk) -> Chunk? {
        string += other.string
        var b = breaker

        if string.utf8.count <= Chunk.maxSize {
            prefixCount = consumeAndFindPrefixCount(in: string, using: &b)
            lastCharSplits = other.lastCharSplits
            return nil
        } else {
            let i = boundaryForMerge(string[...])

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])

            prefixCount = consumeAndFindPrefixCount(in: string, using: &b)
            let next = Chunk(rest[...], breaker: &b)
            if next.prefixCount > 0 {
                lastCharSplits = true
            }
            return next
        }
    }

    mutating func fixup(withNext next: inout Chunk) -> Bool {
        let s = next.string
        var i = s.startIndex
        var first: String.Index?

        var old = next.breaker
        var new = breaker
        new.consume(self.string[...])

        next.breaker = new

        while i < s.unicodeScalars.endIndex {
            let scalar = s.unicodeScalars[i]
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

            i = s.unicodeScalars.index(after: i)
        }

        if let first {
            // We found a new first break
            next.prefixCount = s.utf8.distance(from: s.startIndex, to: first)
        } else if i >= next.lastBreak {
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

            next.prefixCount = s.utf8.count
        } else if i >= next.firstBreak {
            // We made it up through firstBreak without finding any breaks
            // but we got in sync before lastBreak. Find a new firstBreak:

            let j = s.unicodeScalars.index(after: i)
            var tmp = new
            let first = tmp.firstBreak(in: s[j...])!.lowerBound
            next.prefixCount = s.utf8.distance(from: s.startIndex, to: first)

            // If this is false, there's a bug in the code, or my assumptions are wrong.
            assert(next.firstBreak <= next.lastBreak)
        }

        // There's an implicit else clause to the above– we're in sync, and we
        // didn't even get to the old firstBreak. This means the breaks didn't
        // change at all.


        lastCharSplits = next.prefixCount > 0

        // We're done if we synced up before the end of the chunk.
        return i < s.endIndex
    }

    subscript(bounds: Range<Int>) -> Chunk {
        let start = string.utf8Index(at: bounds.lowerBound).samePosition(in: string.unicodeScalars)
        let end = string.utf8Index(at: bounds.upperBound).samePosition(in: string.unicodeScalars)

        guard let start, let end else {
            fatalError("invalid unicode scalar offsets")
        }

        var b = breaker
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

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)
            return offset - 1
        }

        func next(_ offset: Int, in chunk: Chunk) -> Int? {
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

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk) -> Int? {
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

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk) -> Int? {
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

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
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

        func next(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            if current >= chunk.lastBreak && chunk.lastCharSplits {
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

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            precondition(offset > 0 && offset <= chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                buf[..<(offset - 1)].lastIndex(of: nl).map { $0 + 1 }
            }
        }

        func next(_ offset: Int, in chunk: Chunk) -> Int? {
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

// An optimized builder that handles grapheme breaking and skips unnecessary
// calls to fixup.
struct RopeBuilder {
    var b: BTreeBuilder<Rope>
    var breaker: Rope.GraphemeBreaker

    init() {
        self.b = BTreeBuilder<Rope>()
        self.breaker = Rope.GraphemeBreaker()
    }

    mutating func push<S>(characters: S) where S: Sequence<Character>{
        if var r = characters as? Rope {
            push(&r)
            return
        } else if var r = characters as? Subrope {
            push(&r.base, slicedBy: r.bounds)
            return
        }

        var s = String(characters)[...]
        s.makeContiguousUTF8()
        var br = breaker

        func nextChunk() -> Chunk? {
            if s.isEmpty {
                return nil
            }

            let end: String.Index
            if s.utf8.count <= Chunk.maxSize {
                end = s.endIndex
            } else {
                end = boundaryForBulkInsert(s)
            }

            let chunk = Chunk(s[..<end], breaker: &br)
            s = s[end...]
            return chunk
        }

        var chunk = nextChunk()
        let iter = AnyIterator<Chunk> {
            guard var c = chunk else {
                return nil
            }
            let next = nextChunk()
            defer { chunk = next }
            c.lastCharSplits = (next?.prefixCount ?? 0) > 0
            return c
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

        assert(offset >= chunk.prefixCount)
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
extension Rope: BidirectionalCollection {
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

    // N.b. This has a different behavior than String when subscripting on a
    // non-character boundary. String will round down to the closest UnicodeScalar
    // and then do some interesting things depending on what the index is
    // pointing to:
    //
    // All example indices are unicode scalar indices.
    //
    // s = "e\u{0301}"          - "e" + combining accute accent
    //   s[0] = "e\u{0301}"
    //   s[1] = "\u{0301}"
    //
    // s = "👨‍👩‍👧‍👦"
    //   = "👨\u{200D}👩\u{200D}👧\u{200D}👦"
    //   = "\u{0001F468}\u{200D}\u{0001F469}\u{200D}\u{0001F467}\u{200D}\u{0001F466}"
    //
    //   s[0] = "👨‍👩‍👧‍👦"
    //   s[1] = "\u{200D}"
    //   s[2] = "👩\u{200D}👧\u{200D}👦"
    //   s[3] = "\u{200D}"
    //   s[4] = "👧\u{200D}👦"
    //   s[5] = "\u{200D}"
    //   s[6] = "👦"
    //
    // This is pretty gnarley behavior that is doing special things with grapheme breaking,
    // so it's not worth reproducing.
    subscript(position: Index) -> Character {
        root.index(roundingDown: position, using: .characters).readChar()!
    }

    subscript(bounds: Range<Index>) -> Subrope {
        let start = index(roundingDown: bounds.lowerBound)
        let end = index(roundingDown: bounds.upperBound)
        return Subrope(base: self, bounds: start..<end)
    }

    func index(before i: Index) -> Index {
        root.index(before: i, using: .characters)
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

        var b = RopeBuilder()
        b.push(&dup, slicedBy: startIndex..<rangeStart)
        b.push(characters: newElements)
        b.push(&dup, slicedBy: rangeEnd..<endIndex)

        self = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, S.Element == Element {
        var b = RopeBuilder()
        b.push(&self)
        b.push(characters: newElements)
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

    func index(fromOldIndex oldIndex: Index) -> Index {
        root.index(at: oldIndex.position, using: .utf8)
    }

    subscript(offset: Int) -> Character {
        self[root.index(at: offset, using: .characters)]
    }

    subscript(bounds: Range<Int>) -> Subrope {
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
                self.init(chunk.breaker.recognizer, consuming: chunk.string[..<i])
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

protocol RopeView: BidirectionalCollection where Index == BTreeNode<RopeSummary>.Index {
    associatedtype Element
    associatedtype Metric: BTreeMetric<RopeSummary> where Metric.Unit == Int

    var root: BTreeNode<RopeSummary> { get }
    var bounds: Range<Index> { get }
    var metric: Metric { get }

    init(root: BTreeNode<RopeSummary>, bounds: Range<Index>)

    func readElement(at i: Index) -> Element
}

extension RopeView {
    var count: Int {
        root.distance(from: startIndex, to: endIndex, using: metric)
    }

    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    subscript(position: Index) -> Element {
        precondition(position >= startIndex && position < endIndex, "Index out of bounds")
        let i = root.index(roundingDown: position, using: metric)
        precondition(i >= startIndex, "Index out of bounds")
        return readElement(at: i)
    }

    subscript(r: Range<Index>) -> Self {
        precondition(r.lowerBound >= startIndex && r.upperBound <= endIndex, "Index out of bounds")
        let start = root.index(roundingDown: r.lowerBound, using: metric)
        let end = root.index(roundingDown: r.upperBound, using: metric)
        precondition(start >= startIndex && end <= endIndex, "Index out of bounds")
        return Self(root: root, bounds: start..<end)
    }

    func index(before i: Index) -> Index {
        precondition(i > startIndex, "Index out of bounds")
        return root.index(before: i, using: metric)
    }

    func index(after i: Index) -> Index {
        precondition(i < endIndex, "Index out of bounds")
        return root.index(after: i, using: metric)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        let j = root.index(i, offsetBy: distance, using: metric)
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        guard let j = root.index(i, offsetBy: distance, limitedBy: limit, using: metric) else {
            return nil
        }
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    func distance(from start: Index, to end: Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "Index out of bounds")
        return root.distance(from: start, to: end, using: metric)
    }
}

extension RopeView {
    func index(at offset: Int) -> Index {
        precondition(offset >= 0 && offset <= count)
        return root.index(at: offset, using: metric)
    }

    func index(roundingDown i: Index) -> Index {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        let j = root.index(roundingDown: i, using: metric)
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    subscript(offset: Int) -> Element {
        self[index(at: offset)]
    }
}

extension Rope {
    var utf8: UTF8View {
        UTF8View(root: root, bounds: startIndex..<endIndex)
    }

    struct UTF8View: RopeView {
        // I don't think I should need this typealias – Element should
        // be inferred from readElement(at:), but as of Swift 5.9, UTF8View
        // doesn't conform to RopeView without it.
        //
        // Even stranger, UnicodeScalarView works fine without the typealias.
        typealias Element = UTF8.CodeUnit

        var root: BTreeNode<RopeSummary>
        var bounds: Range<Index>

        var metric: UTF8Metric {
            .utf8
        }

        func readElement(at i: Index) -> UTF8.CodeUnit {
            i.readUTF8()!
        }
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
        UTF16View(root: root, bounds: startIndex..<endIndex)
    }

    struct UTF16View {
        var root: BTreeNode<RopeSummary>
        var bounds: Range<Index>
    }
}

extension Rope.UTF16View {
    typealias Index = Rope.Index

    var count: Int {
        root.distance(from: startIndex, to: endIndex, using: .utf16)
    }

   var startIndex: Index {
       bounds.lowerBound
   }

   var endIndex: Index {
       bounds.upperBound
   }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        let j = root.index(i, offsetBy: distance, using: .utf16)
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    func distance(from start: Index, to end: Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "Index out of bounds")
        return root.distance(from: start, to: end, using: .utf16)
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(root: root, bounds: startIndex..<endIndex)
    }

    struct UnicodeScalarView: RopeView {
        let root: BTreeNode<RopeSummary>
        let bounds: Range<Index>

        var metric: UnicodeScalarMetric {
            .unicodeScalars
        }

        func readElement(at i: Index) -> UnicodeScalar {
            i.readScalar()!
        }
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


// MARK: - Subropes

struct Subrope {
    var base: Rope
    var bounds: Range<Rope.Index>

    var root: BTreeNode<RopeSummary> {
        base.root
    }
}

extension Subrope: BidirectionalCollection {
    typealias Index = Rope.Index

    var count: Int {
        base.distance(from: startIndex, to: endIndex)
    }

    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    // See note on Rope.subscript(_:) for behavior differences from String.
    subscript(position: Index) -> Character {
        precondition(position >= startIndex && position < endIndex, "Index out of bounds")
        let i = root.index(roundingDown: position, using: .characters)
        precondition(i >= startIndex, "Index out of bounds")
        return i.readChar()!
    }

    subscript(bounds: Range<Index>) -> Subrope {
        precondition(bounds.lowerBound >= startIndex && bounds.upperBound <= endIndex, "Index out of bounds")
        return Subrope(base: base, bounds: bounds)
    }

    func index(before i: Index) -> Index {
        precondition(i > startIndex, "Index out of bounds")
        let j = root.index(before: i, using: .characters)
        precondition(j >= startIndex, "Index out of bounds")
        return j
    }

    func index(after i: Index) -> Index {
        precondition(i < endIndex, "Index out of bounds")
        let j = root.index(after: i, using: .characters)
        precondition (j <= endIndex, "Index out of bounds")
        return j
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        let j = root.index(i, offsetBy: distance, using: .characters)
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        precondition(i >= startIndex && i <= endIndex, "Index out of bounds")
        guard let j = root.index(i, offsetBy: distance, limitedBy: limit, using: .characters) else {
            return nil
        }
        precondition(j >= startIndex && j <= endIndex, "Index out of bounds")
        return j
    }

    func distance(from start: Index, to end: Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "Index out of bounds")
        return root.distance(from: start, to: end, using: .characters)
    }
}

extension Subrope {
    typealias UTF8View = Rope.UTF8View
    typealias UTF16View = Rope.UTF16View
    typealias UnicodeScalarView = Rope.UnicodeScalarView

    var utf8: UTF8View {
        UTF8View(root: root, bounds: bounds)
    }

    var utf16: UTF16View {
        UTF16View(root: root, bounds: bounds)
    }

    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(root: root, bounds: bounds)
    }
}

extension Subrope: RangeReplaceableCollection {
    init() {
        let r = Rope()
        base = r
        bounds = r.startIndex..<r.endIndex
    }

    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        precondition(subrange.lowerBound >= startIndex && subrange.upperBound <= endIndex, "Index out of bounds")
        base.replaceSubrange(subrange, with: newElements)
        bounds = base.index(fromOldIndex: startIndex)..<base.index(fromOldIndex: endIndex)
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, S.Element == Element {
        let new = Rope(newElements)
        base.replaceSubrange(endIndex..<endIndex, with: new)
        let start = base.index(fromOldIndex: startIndex)
        let end = base.index(base.index(fromOldIndex: endIndex), offsetBy: new.count)
        bounds = start..<end
    }
}


// MARK: - Standard library integration

extension Rope: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension Subrope: ExpressibleByStringLiteral {
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

    init(_ subrope: Subrope) {
        let r = Rope(subrope)
        self.init(r)
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

