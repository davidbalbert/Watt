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
    var bounds: Range<Rope.Index>

    init() {
        self.init(BTreeNode<RopeSummary>())
    }

    init(_ root: BTreeNode<RopeSummary>) {
        self.root = root

        let start = root.startIndex
        let end = root.endIndex
        assert(start <= end)
        self.bounds = Range(uncheckedBounds: (Index(start, alignment: .line), Index(end, alignment: .line)))
    }
}

struct RopeSummary: BTreeSummary {
    var utf16: Int
    var scalars: Int
    var leadingChars: Int
    var trailingChars: Int
    var newlines: Int

    static func += (left: inout RopeSummary, right: RopeSummary) {
        left.utf16 += right.utf16
        left.scalars += right.scalars
        left.leadingChars += right.leadingChars
        left.trailingChars += right.trailingChars
        left.newlines += right.newlines
    }

    static var zero: RopeSummary {
        RopeSummary()
    }

    init() {
        self.utf16 = 0
        self.scalars = 0
        self.leadingChars = 0
        self.trailingChars = 0
        self.newlines = 0
    }

    init(summarizing chunk: Chunk) {
        self.utf16 = chunk.string.utf16.count
        self.scalars = chunk.string.unicodeScalars.count
        self.leadingChars = chunk.leadingBoundaryCount
        self.trailingChars = chunk.trailingBoundaryCount

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

    var leadingBoundaryCount: Int {
        characters.count
    }

    var trailingBoundaryCount: Int {
        var n = characters.count
        if prefixCount > 0 {
            n += 1
        }
        if lastCharSplits {
            n -= 1
        }
        assert(n >= 0)
        return n
    }

    init() {
        self.string = ""
        self.prefixCount = 0
        self.lastCharSplits = false
        self.breaker = Rope.GraphemeBreaker()
    }

    init(_ substring: Substring, findPrefixCountUsing breaker: inout Rope.GraphemeBreaker) {
        let s = String(substring)
        assert(s.isContiguousUTF8)
        assert(s.utf8.count <= Chunk.maxSize)

        // save the breaker at the start of the chunk
        self.breaker = breaker

        self.string = s
        self.prefixCount = findPrefixCount(in: substring, using: &breaker)
        self.lastCharSplits = false
    }

    init(string: String, prefixCount: Int, lastCharSplits: Bool, breaker: Rope.GraphemeBreaker) {
        self.string = string
        self.prefixCount = prefixCount
        self.lastCharSplits = lastCharSplits
        self.breaker = breaker
    }

    mutating func pushMaybeSplitting(other: Chunk) -> Chunk? {
        string += other.string
        var b = breaker

        if string.utf8.count <= Chunk.maxSize {
            prefixCount = findPrefixCount(in: string[...], using: &b)
            lastCharSplits = other.lastCharSplits
            return nil
        } else {
            let i = boundaryForMerge(string[...])

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])
            prefixCount = min(prefixCount, string.utf8.count)

            b.consume(string[...])
            let next = Chunk(rest[...], findPrefixCountUsing: &b)
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

        if bounds.lowerBound == 0 {
            // Optimization: if we're slicing from the beginning, we can just calculate prefixCount
            // ourselves. There's no need to run the grapheme breaker at all.
            let c = min(prefixCount, bounds.upperBound)
            return Chunk(string: String(string[start..<end]), prefixCount: c, lastCharSplits: false, breaker: breaker)
        }

        var b = breaker
        b.consume(string[string.startIndex..<start])
        return Chunk(string[start..<end], findPrefixCountUsing: &b)
    }

    func isValidUnicodeScalarIndex(_ i: String.Index) -> Bool {
        i.samePosition(in: string.unicodeScalars) != nil
    }

    func isValidCharacterIndex(_ i: String.Index) -> Bool {
        i == characters._index(roundingDown: i)
    }
}

fileprivate func findPrefixCount(in substring: Substring, using breaker: inout Rope.GraphemeBreaker) -> Int {
    guard let r = breaker.firstBreak(in: substring) else {
        // uncommon, no character boundaries
        return substring.utf8.count
    }
    return substring.utf8.distance(from: substring.startIndex, to: r.lowerBound)
}

// MARK: - Metrics

// The base metric, which measures UTF-8 code units.
extension Rope {
    struct UTF8Metric: RopeMetric {
        func measure(summary: RopeSummary, count: Int, edge: BTreeMetricEdge) -> Int {
            count
        }

        func convertToBaseUnits(_ measuredUnits: Int, in leaf: Chunk, edge: BTreeMetricEdge) -> Int {
            switch edge {
            case .leading: Swift.max(measuredUnits - 1, 0)
            case .trailing: measuredUnits
            }
        }

        func convertToMeasuredUnits(_ baseUnits: Int, in leaf: Chunk, edge: BTreeMetricEdge) -> Int {
            switch edge {
            case .leading: Swift.min(baseUnits + 1, leaf.count)
            case .trailing: baseUnits
            }
        }

        // Because UTF8Metric is atomic, we can ignore edge for isBoundary, prev, and next.
        func isBoundary(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Bool {
            true
        }

        func prev(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset > 0)
            return offset - 1
        }

        func next(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset < chunk.count)
            return offset + 1
        }

        var canFragment: Bool {
            false
        }

        var isAtomic: Bool {
            true
        }

        var alignment: Index.Alignment {
            .byte
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
    struct UTF16Metric: RopeMetric {
        func measure(summary: RopeSummary, count: Int, edge: BTreeMetricEdge) -> Int {
            summary.utf16
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            let startIndex = chunk.string.startIndex
            let delta = (edge == .leading ? 1 : 0)
            let i = chunk.string.utf16Index(at: measuredUnits - delta)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            // Slightly optimized version of returning Swift.min(d + 1, chunk.string.utf16.count)
            // for .leading. Skips the string index math below. Also works for .trailing.
            if baseUnits == chunk.string.utf8.count {
                return chunk.string.utf16.count
            }

            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)
            let d = chunk.string.utf16.distance(from: startIndex, to: i)

            switch edge {
            case .leading: return d + 1
            case .trailing: return d
            }
        }

        // Because UTF16Metric is atomic, we can ignore edge for isBoundary, prev, and next.
        func isBoundary(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Bool {
            assert(offset >= 0 || offset <= chunk.count)
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset > 1 || (edge == .trailing && offset > 0))

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset < chunk.count-1 || (edge == .leading && offset < chunk.count))

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        var canFragment: Bool {
            false
        }

        var isAtomic: Bool {
            true
        }

        var alignment: Index.Alignment {
            .unicodeScalar
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF16Metric {
    static var utf16: Rope.UTF16Metric { Rope.UTF16Metric() }
}

extension Rope {
    struct UnicodeScalarMetric: RopeMetric {
        func measure(summary: RopeSummary, count: Int, edge: BTreeMetricEdge) -> Int {
            summary.scalars
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            let startIndex = chunk.string.startIndex
            let delta = (edge == .leading ? 1 : 0)
            let i = chunk.string.unicodeScalarIndex(at: measuredUnits - delta)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            // Slightly optimized version of returning Swift.min(d + 1, chunk.unicodeScalars.count)
            // for .leading. Skips the string index math below. Also works for .trailing.
            if baseUnits == chunk.string.utf8.count {
                return chunk.string.unicodeScalars.count
            }

            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)
            let d = chunk.string.unicodeScalars.distance(from: startIndex, to: i)

            switch edge {
            case .leading: return d + 1
            case .trailing: return d
            }
        }

        // Because UnicodeScalarMetric is atomic, we can ignore edge for isBoundary, prev, and next.
        func isBoundary(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Bool {
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        func next(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }

        var canFragment: Bool {
            false
        }

        var isAtomic: Bool {
            true
        }

        var alignment: Index.Alignment {
            .unicodeScalar
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UnicodeScalarMetric {
    static var unicodeScalars: Rope.UnicodeScalarMetric { Rope.UnicodeScalarMetric() }
}

extension Rope {
    struct CharacterMetric: RopeMetric {
        func measure(summary: RopeSummary, count: Int, edge: BTreeMetricEdge) -> Int {
            switch edge {
            case .leading:
                summary.leadingChars
            case .trailing:
                summary.trailingChars
            }
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            assert(measuredUnits <= chunk.characters.count || (measuredUnits == 1 && chunk.characters.count == 0 && chunk.prefixCount == chunk.count && !chunk.lastCharSplits))
            assert(measuredUnits >= 0 || (measuredUnits == 0 && edge == .trailing) || (measuredUnits == 0 && chunk.prefixCount == chunk.count))

            if measuredUnits == 0 {
                switch edge {
                case .leading:
                    assert(chunk.prefixCount == chunk.count)
                    return 0
                case .trailing:
                    return chunk.prefixCount
                }
            }


            if measuredUnits == 1 && chunk.prefixCount == chunk.count {
                assert(edge == .trailing && !chunk.lastCharSplits)
                return chunk.count
            }

            let startIndex = chunk.characters.startIndex
            let delta = (edge == .leading ? 1 : 0)
            let i = chunk.characters.index(startIndex, offsetBy: measuredUnits - delta)
            assert(chunk.isValidCharacterIndex(i))
            return chunk.prefixCount + chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            if baseUnits < chunk.prefixCount {
                return 0
            }

            if baseUnits == chunk.count && chunk.prefixCount == chunk.count && !chunk.lastCharSplits && edge == .trailing {
                return 1
            } else if baseUnits == chunk.count {
                // Slightly optimized version of returning Swift.min(d + 1, chunk.characters.count)
                // for .leading. Skips the string index math below. Also works for .trailing.
                return chunk.characters.count
            }

            let startIndex = chunk.characters.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)
            let d = chunk.characters.distance(from: startIndex, to: i)

            switch edge {
            case .leading: return d + 1
            case .trailing: return d
            }
        }

        // CharacterMetric is atomic, so edge can be ignored in isBoundary, prev, and next.
        func isBoundary(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Bool {
            assert(offset >= 0 && offset <= chunk.count)

            if offset < chunk.prefixCount {
                return false
            }
            if offset == chunk.count {
                return !chunk.lastCharSplits
            }

            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidCharacterIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset > 0 && offset <= chunk.count)

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

        func next(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            assert(offset >= 0 && offset < chunk.count)

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

        var isAtomic: Bool {
            true
        }

        var alignment: Index.Alignment {
            .character
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.CharacterMetric {
    static var characters: Rope.CharacterMetric { Rope.CharacterMetric() }
}

extension Rope {
    struct NewlinesMetric: RopeMetric {
        func measure(summary: RopeSummary, count: Int, edge: BTreeMetricEdge) -> Int {
            summary.newlines
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            let nl = UInt8(ascii: "\n")

            var offset = 0
            var count = 0
            chunk.string.withExistingUTF8 { buf in
                while count < measuredUnits {
                    precondition(offset < buf.count)
                    offset = buf[offset...].firstIndex(of: nl)! + 1
                    count += 1
                }
            }

            // The above code calculates the offset one byte after the Nth newline.

            switch edge {
            case .leading: return Swift.max(offset - 1, 0)
            case .trailing: return offset
            }
        }

        func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int {
            return chunk.string.withExistingUTF8 { buf in
                precondition(baseUnits <= buf.count)
                let delta = edge == .leading ? 1 : 0
                let end = Swift.min(baseUnits+delta, buf.count)
                return countNewlines(in: buf[..<end])
            }
        }

        func isBoundary(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Bool {
            precondition(offset > 0 || (edge == .leading && offset == 0))
            precondition(offset < chunk.count || (edge == .trailing && offset == chunk.count))

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                switch edge {
                case .leading:
                    buf[offset] == nl
                case .trailing:
                    buf[offset - 1] == nl
                }
            }
        }

        func prev(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            precondition(offset > 0 && offset <= chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                switch edge {
                case .leading:
                    buf[..<offset].lastIndex(of: nl)
                case .trailing:
                    buf[..<(offset - 1)].lastIndex(of: nl).map { $0 + 1 }
                }
            }
        }

        func next(_ offset: Int, in chunk: Chunk, edge: BTreeMetricEdge) -> Int? {
            precondition(offset >= 0 && offset < chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                switch edge {
                case .leading:
                    buf[(offset+1)...].firstIndex(of: nl)
                case .trailing:
                    buf[offset...].firstIndex(of: nl).map { $0 + 1 }
                }
            }
        }

        var canFragment: Bool {
            false
        }

        var isAtomic: Bool {
            false
        }

        var alignment: Index.Alignment {
            .line
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

            let chunk = Chunk(s[..<end], findPrefixCountUsing: &br)
            br.consume(s[s.utf8Index(at: chunk.prefixCount)..<end])
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
        b.push(&rope.root, slicedBy: Range(range, in: rope))
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


// MARK: - Index

extension Rope {
    struct Index {
        enum Alignment: Comparable {
            case byte
            case unicodeScalar
            case character
            case line
        }

        var i: BTreeNode<RopeSummary>.Index
        var alignment: Alignment

        init(_ i: BTreeNode<RopeSummary>.Index, alignment: Alignment) {
            self.i = i
            self.alignment = alignment
        }

        init?(_ i: BTreeNode<RopeSummary>.Index?, alignment: Alignment) {
            guard let i else { return nil }
            self.init(i, alignment: alignment)
        }

        var position: Int {
            i.position
        }

        func validate(for rope: Rope) {
            i.validate(for: rope.root)
        }

        func validate(_ other: Index) {
            i.validate(other.i)
        }

        func assertValid(for rope: Rope) {
            i.assertValid(for: rope.root)
        }

        func assertValid(_ other: Index) {
            i.assertValid(other.i)
        }
    }
}

extension Rope.Index: Comparable {
    static func == (lhs: Rope.Index, rhs: Rope.Index) -> Bool {
        lhs.i == rhs.i
    }

    static func < (lhs: Rope.Index, rhs: Rope.Index) -> Bool {
        lhs.i < rhs.i
    }
}


extension Rope.Index {
    func readUTF8() -> UTF8.CodeUnit? {
        guard let (chunk, offset) = i.read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    func readScalar() -> Unicode.Scalar? {
        guard let (chunk, offset) = i.read() else {
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
        guard var (chunk, offset) = i.read() else {
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
        if end.i.next(using: .characters, edge: .leading) == nil {
            end = Rope(BTreeNode(storage: i.rootStorage!)).endIndex
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

            (chunk, offset) = i.i.nextLeaf()!
        }

        assert(s.count == 1)
        return s[s.startIndex]
    }
}

extension Rope.Index: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(position)[utf8]"
    }
}


// MARK: - Collection conformances


// N.b. Rope and Subrope have a different behavior than String when subscripting
// on a non-character boundary. String will round down to the closest UnicodeScalar
// and then do some interesting things depending on what the index is pointing to:
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

extension Rope: RopeView {
    typealias Element = Character
    typealias SubSequence = Subrope

    init(base: Rope, bounds: Range<Index>) {
        assert(base.bounds == bounds)
        self = base
    }

    var base: Rope {
        self
    }

    var metric: CharacterMetric {
        .characters
    }

    var edge: BTreeMetricEdge {
        .leading
    }

    var alignment: Index.Alignment {
        .character
    }

    var sliceMetric: UnicodeScalarMetric {
        .unicodeScalars
    }

    func readElement(at i: Index) -> Character {
        i.readChar()!
    }
}

// TODO: audit default methods from RangeReplaceableCollection for default implementations that perform poorly.
extension Rope: RangeReplaceableCollection {
    init(_ rope: Rope) {
        self.root = rope.root
        self.bounds = rope.bounds
    }

    init(_ subrope: Subrope) {
        self = Rope(subrope.root, slicedBy: Range(unvalidatedRange: subrope.bounds))
    }

    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: self)
        subrange.upperBound.validate(for: self)

        let rangeStart = unicodeScalars.index(roundingDown: subrange.lowerBound)
        let rangeEnd = unicodeScalars.index(roundingDown: subrange.upperBound)

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
}

extension Rope {
    func index(fromOldIndex oldIndex: consuming Index) -> Index {
        utf8.index(at: oldIndex.position)
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
            assert(rope.unicodeScalars.isBoundary(upperBound))

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

            let (chunk, offset) = upperBound.i.read()!
            let i = chunk.string.utf8Index(at: offset)

            if i <= chunk.firstBreak {
                self.init(chunk.breaker.recognizer, consuming: chunk.string[..<i])
                return
            }

            let j = chunk.characters._index(roundingDown: i)
            let prev = j == i ? chunk.characters.index(before: i) : j

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

protocol RopeMetric: BTreeMetric<RopeSummary> {
    var alignment: Rope.Index.Alignment { get }
}

// TODO: RopeView is really an implementation detail for code deduplication.
// Consider making it fileprivate and making each view conform to
// BidirectionalCollection directly, forwarding to a private struct implementing
// RopeView. It's possible we could use a macro to generate the forwarding methods.
protocol RopeView: BidirectionalCollection where Index == Rope.Index, SubSequence: RopeView {
    associatedtype Element
    associatedtype Metric: RopeMetric where Metric.Unit == Int
    associatedtype SliceMetric: RopeMetric where Metric.Unit == Int

    var base: Rope { get }
    var bounds: Range<Rope.Index> { get }
    var metric: Metric { get }
    var edge: BTreeMetricEdge { get }

    // An optional, more granular boundary for rounding when slicing.
    // Specifically, when slicing Subropes, indices are rounded down
    // to UnicodeScalar boundaries instead of Character boundaries.
    var sliceMetric: SliceMetric { get }

    init(base: Rope, bounds: Range<Index>)
    func readElement(at i: Index) -> Element

    // These have default implementations
    func index(at offset: Int) -> Index
    subscript(offset: Int) -> Element { get }
    func index(roundingDown i: Index) -> Index
    func isBoundary(_ i: Index) -> Bool
}

extension RopeView {
    var root: BTreeNode<RopeSummary> {
        base.root
    }
}

// BidirectionalCollection
extension RopeView {
    var count: Int {
        root.count(in: startIndex.i..<endIndex.i, using: metric)
    }

    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    subscript(position: Index) -> Element {
        readElement(at: position.alignment < metric.alignment ? index(roundingDown: position) : position)
    }

    subscript(r: Range<Index>) -> SubSequence {
        // We always set the alignment of start and end to .line because startIndex and endIndex are aligned to
        // everything, and .line is the highest known alignment. We don't delegate to index(roundingDown:) because
        // we need to round using sliceMetric, not metric.
        let start: Rope.Index
        if r.lowerBound.alignment >= sliceMetric.alignment {
            start = Index(r.lowerBound.i, alignment: .line)
        } else {
            start = Index(root.index(roundingDown: r.lowerBound.i, in: startIndex.i..<endIndex.i, using: sliceMetric, edge: edge), alignment: .line)
        }

        let end: Rope.Index
        if r.upperBound.alignment >= sliceMetric.alignment {
            end = Index(r.upperBound.i, alignment: .line)
        } else {
            end = Index(root.index(roundingDown: r.upperBound.i, in: startIndex.i..<endIndex.i, using: sliceMetric, edge: edge), alignment: .line)
        }

        return SubSequence(base: base, bounds: start..<end)
    }

    func index(before i: consuming Index) -> Index {
        Index(root.index(before: i.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge, isKnownAligned: i.alignment >= metric.alignment), alignment: metric.alignment)
    }

    func index(after i: consuming Index) -> Index {
        Index(root.index(after: i.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge), alignment: metric.alignment)
    }

    func index(_ i: consuming Index, offsetBy distance: Int) -> Index {
        Index(root.index(i.i, offsetBy: distance, in: startIndex.i..<endIndex.i, using: metric, edge: edge), alignment: metric.alignment)
    }

    func index(_ i: consuming Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        Index(root.index(i.i, offsetBy: distance, limitedBy: limit.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge, isKnownAligned: i.alignment >= metric.alignment), alignment: metric.alignment)
    }

    func distance(from start: Index, to end: Index) -> Int {
        root.distance(from: start.i, to: end.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge)
    }
}

extension RopeView {
    func index(at offset: Int) -> Index {
        Index(root.index(at: offset, in: startIndex.i..<endIndex.i, using: metric, edge: edge), alignment: metric.alignment)
    }

    subscript(offset: Int) -> Element {
        self[index(at: offset)]
    }

    func index(roundingDown i: consuming Index) -> Index {
        if i.alignment >= metric.alignment {
            return i
        }
        return Index(root.index(roundingDown: i.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge), alignment: metric.alignment)
    }

    func isBoundary(_ i: Index) -> Bool {
        root.isBoundary(i.i, in: startIndex.i..<endIndex.i, using: metric, edge: edge)
    }
}

extension Rope {
    var utf8: UTF8View {
        UTF8View(base: self, bounds: bounds)
    }

    struct UTF8View: RopeView {
        // I don't think I should need this typealias – Element should
        // be inferred from readElement(at:), but as of Swift 5.9, UTF8View
        // doesn't conform to RopeView without it.
        //
        // Even stranger, the other views works fine without the typealias.
        typealias Element = UTF8.CodeUnit
        typealias SubSequence = Self

        var base: Rope
        var bounds: Range<Index>

        var metric: UTF8Metric {
            .utf8
        }

        var edge: BTreeMetricEdge {
            .leading
        }

        var alignment: Rope.Index.Alignment {
            .byte
        }

        var sliceMetric: UTF8Metric {
            .utf8
        }

        func readElement(at i: Index) -> UTF8.CodeUnit {
            i.readUTF8()!
        }

        // faster than using root.index(at:in:using:edge:)
        func index(at offset: Int) -> Index {
            Index(root.index(at: offset), alignment: .byte)
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
        UTF16View(base: self, bounds: bounds)
    }

    struct UTF16View {
        var base: Rope
        var bounds: Range<Index>
    }
}

extension Rope.UTF16View {
    var root: BTreeNode<RopeSummary> {
        base.root
    }
}

extension Rope.UTF16View {
    typealias Index = Rope.Index

    var count: Int {
        root.count(in: Range(uncheckedBounds: (bounds.lowerBound.i, bounds.upperBound.i)), using: .utf16)
    }

   var startIndex: Index {
       bounds.lowerBound
   }

   var endIndex: Index {
       bounds.upperBound
   }

    func index(_ i: consuming Index, offsetBy distance: Int) -> Index {
        Index(root.index(i.i, offsetBy: distance, in: startIndex.i..<endIndex.i, using: .utf16, edge: .leading), alignment: .unicodeScalar)
    }

    func distance(from start: Index, to end: Index) -> Int {
        root.distance(from: start.i, to: end.i, in: startIndex.i..<endIndex.i, using: .utf16, edge: .leading)
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(base: self, bounds: bounds)
    }

    struct UnicodeScalarView: RopeView {
        typealias Element = UnicodeScalar
        typealias SubSequence = Self

        let base: Rope
        let bounds: Range<Index>

        var metric: UnicodeScalarMetric {
            .unicodeScalars
        }

        var edge: BTreeMetricEdge {
            .leading
        }

        var alignment: Index.Alignment {
            .unicodeScalar
        }

        var sliceMetric: UnicodeScalarMetric {
            .unicodeScalars
        }

        func readElement(at i: Index) -> UnicodeScalar {
            i.readScalar()!
        }
    }
}

extension Rope {
    var lines: LineView {
        LineView(base: self, bounds: bounds)
    }

    struct LineView {
        var base: Rope
        var bounds: Range<Index>

        var root: BTreeNode<RopeSummary> {
            base.root
        }
    }
}

extension Rope.LineView: Sequence {
    typealias Index = Rope.Index

    struct Iterator: IteratorProtocol {
        let base: Rope.LineView
        var i: Index
        var done: Bool
        let hasEmptyLastLine: Bool

        init(base: Rope.LineView) {
            self.base = base
            self.i = base.startIndex
            self.done = false
            self.hasEmptyLastLine = base.isBoundary(base.endIndex)
        }

        mutating func next() -> Subrope? {
            if done {
                return nil
            }

            let line = base[i]
            i = line.endIndex

            if line.isEmpty || (i == base.endIndex && !hasEmptyLastLine) {
                done = true
            }
            return line
        }
    }

    func makeIterator() -> Iterator {
        Iterator(base: self)
    }
}

// LineView looks a lot like a Collection, but it violates Collection semantics, so we don't make
// it conform. Specifically, if the underlying Rope ends in a blank line, endIndex is valid for
// subscripting, and returns an empty Subrope.
//
// Because of this semantic mismatch, we should assume that none of Collection's
// default implementations will return correct results for LineView. It's perfectly fine to
// implement any Collection methods we need below. We just can't pass LineView to a function
// expecting a Collection.
extension Rope.LineView {
    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    var count: Int {
        root.count(in: startIndex.i..<endIndex.i, using: .newlines) + 1
    }

    subscript(position: Index) -> Subrope {
        if position == endIndex && isBoundary(endIndex) {
            return Subrope(base: base, bounds: endIndex..<endIndex)
        }

        let start = position.alignment < .line ? index(roundingDown: position) : position
        let end = index(after: start)
        return Subrope(base: base, bounds: start..<end)
    }

    subscript(r: Range<Index>) -> Self {
        let start = r.lowerBound.alignment < .line ? index(roundingDown: r.lowerBound) : r.lowerBound
        let end = r.upperBound.alignment < .line ? index(roundingDown: r.upperBound) : r.upperBound
        return Self(base: base, bounds: start..<end)
    }

    func index(before i: Index) -> Index {
        Index(root.index(before: i.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing, isKnownAligned: i.alignment >= .line), alignment: .line)
    }

    func index(after i: Index) -> Index {
        Index(root.index(after: i.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing), alignment: .line)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        Index(root.index(i.i, offsetBy: distance, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing), alignment: .line)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        Index(root.index(i.i, offsetBy: distance, limitedBy: limit.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing, isKnownAligned: i.alignment >= .line), alignment: .line)
    }

    func distance(from start: Index, to end: Index) -> Int {
        root.distance(from: start.i, to: end.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing)
    }
}

extension Rope.LineView {
    func index(at offset: Int) -> Index {
        Index(root.index(at: offset, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing), alignment: .line)
    }

    subscript(offset: Int) -> Subrope {
        self[index(at: offset)]
    }

    func index(roundingDown i: consuming Index) -> Index {
        if i.alignment >= .line {
            return i
        }
        return Index(root.index(roundingDown: i.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing), alignment: .line)
    }

    func isBoundary(_ i: Index) -> Bool {
        root.isBoundary(i.i, in: startIndex.i..<endIndex.i, using: .newlines, edge: .trailing)
    }
}

// MARK: - Subropes

struct Subrope: RopeView {
    typealias Element = Character
    typealias Index = Rope.Index
    typealias SubSequence = Self

    init(base: Rope, bounds: Range<Rope.Index>) {
        self.base = base
        self.bounds = bounds
    }

    var base: Rope
    var bounds: Range<Rope.Index>

    var metric: Rope.CharacterMetric {
        .characters
    }

    var edge: BTreeMetricEdge {
        .leading
    }

    var alignment: Index.Alignment {
        .character
    }

    var sliceMetric: Rope.UnicodeScalarMetric {
        .unicodeScalars
    }

    func readElement(at i: Index) -> Character {
        i.readChar()!
    }
}


extension Subrope {
    typealias UTF8View = Rope.UTF8View
    typealias UTF16View = Rope.UTF16View
    typealias UnicodeScalarView = Rope.UnicodeScalarView
    typealias LineView = Rope.LineView

    var utf8: UTF8View {
        UTF8View(base: base, bounds: bounds)
    }

    var utf16: UTF16View {
        UTF16View(base: base, bounds: bounds)
    }

    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(base: base, bounds: bounds)
    }

    var lines: LineView {
        LineView(base: base, bounds: bounds)
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

    // The default implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, S.Element == Element {
        let new = Rope(newElements)
        base.replaceSubrange(endIndex..<endIndex, with: new)
        let start = base.index(fromOldIndex: startIndex)
        let end = base.index(base.index(fromOldIndex: endIndex), offsetBy: new.count)
        bounds = start..<end
    }
}


// MARK: - Standard library integration

// TODO: normalized comparisons
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

// TODO: normalized comparisons
extension Subrope: Equatable {
    static func == (lhs: Subrope, rhs: Subrope) -> Bool {
        if lhs.base.root == rhs.base.root && Range(unvalidatedRange: lhs.bounds) == Range(unvalidatedRange: rhs.bounds) {
            return true
        }
        return Rope(lhs) == Rope(rhs)
    }
}

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
        if subrope.bounds.lowerBound.position == 0 && subrope.bounds.upperBound.position == subrope.base.utf8.count {
            self.init(subrope.base)
            return
        }

        self.init()
        self.reserveCapacity(subrope.utf8.count)

        // manually iterate over chunks, starting at subrope.startIndex, slicing the first and last chunk if necessary
        var i = subrope.startIndex
        let end = subrope.endIndex

        while i.i.isValid && i.position < end.position {
            let chunk = i.i.read()!.0

            if i.i.offsetInLeaf == 0 && i.i.offsetOfLeaf + chunk.count <= end.i.offsetOfLeaf {
                append(chunk.string)
            } else {
                let j = i.i.offsetInLeaf == 0 ? chunk.string.startIndex : chunk.string.utf8Index(at: i.i.offsetInLeaf)

                let k: String.Index
                if i.i.offsetOfLeaf == end.i.offsetOfLeaf && end.i.offsetInLeaf < chunk.count {
                    k = chunk.string.utf8Index(at: end.i.offsetInLeaf)
                } else {
                    k = chunk.string.endIndex
                }

                append(contentsOf: chunk.string[j..<k])
            }

            i.i.nextLeaf()
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

        var i = rope.root.countBaseUnits(upThrough: range.lowerBound, measuredIn: .utf16, edge: .trailing)
        var j = rope.root.countBaseUnits(upThrough: range.upperBound, measuredIn: .utf16, edge: .trailing)

        // NSTextInputClient seems to sometimes receive ranges that start
        // or end on a trailing surrogate. Round them to the nearest
        // unicode scalar.
        if rope.root.count(.utf16, upThrough: i, edge: .trailing) != range.lowerBound {
            assert(rope.root.count(.utf16, upThrough: i, edge: .trailing) == range.lowerBound - 1)
            print("!!! got NSRange starting on a trailing surrogate: \(range). I think this is expected, but try to reproduce and figure out if it's ok")
            i -= 1
        }

        if rope.root.count(.utf16, upThrough: j, edge: .trailing) != range.upperBound {
            assert(rope.root.count(.utf16, upThrough: j, edge: .trailing) == range.upperBound - 1)
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
    // Don't use for user provided ranges.
    init(unvalidatedRange range: Range<Rope.Index>) {
        self.init(uncheckedBounds: (range.lowerBound.position, range.upperBound.position))
    }

    init(_ range: Range<Rope.Index>, in rope: Rope) {
        let start = range.lowerBound.position
        let end = range.upperBound.position

        self.init(uncheckedBounds: (start, end))
    }
}

extension NSRange {
    init<R>(_ region: R, in rope: Rope) where R : RangeExpression, R.Bound == Rope.Index {
        let range = region.relative(to: rope)

        range.lowerBound.validate(for: rope)
        range.upperBound.validate(for: rope)

        assert(range.lowerBound.position >= 0 && range.lowerBound.position <= rope.root.count)
        assert(range.upperBound.position >= 0 && range.upperBound.position <= rope.root.count)

        self.init(unvalidatedRange: range, in: rope)
    }

    // Don't use for user provided ranges.
    init(unvalidatedRange range: Range<Rope.Index>, in rope: Rope) {
        let i = rope.root.count(.utf16, upThrough: range.lowerBound.position, edge: .trailing)
        let j = rope.root.count(.utf16, upThrough: range.upperBound.position, edge: .trailing)

        self.init(location: i, length: j-i)
    }

    init(unvalidatedRange range: Range<Rope.Index>, in subrope: Subrope) {
        let nsRange = NSRange(unvalidatedRange: range, in: subrope.base)
        self.init(location: nsRange.location - subrope.bounds.lowerBound.position, length: nsRange.length)
    }
}

extension CFRange {
    init<R>(_ region: R, in rope: Rope) where R : RangeExpression, R.Bound == Rope.Index {
        let nsRange = NSRange(region, in: rope)
        self.init(location: nsRange.location, length: nsRange.length)
    }

    // Don't use for user provided ranges.
    init(unvalidatedRange range: Range<Rope.Index>, in rope: Rope) {
        let nsRange = NSRange(unvalidatedRange: range, in: rope)
        self.init(location: nsRange.location, length: nsRange.length)
    }

    init(unvalidatedRange range: Range<Rope.Index>, in subrope: Subrope) {
        let nsRange = NSRange(unvalidatedRange: range, in: subrope)
        self.init(location: nsRange.location, length: nsRange.length)
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
