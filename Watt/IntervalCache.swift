//
//  IntervalCache.swift
//  Watt
//
//  Created by David Albert on 7/31/23.
//

import Foundation

struct IntervalCache<T> {
    var spans: Spans<T>

    init(upperBound: Int) {
        let b = SpansBuilder<T>(totalCount: upperBound)
        spans = b.build()
    }

    init(_ spans: Spans<T>) {
        self.spans = spans
    }

    var count: Int {
        spans.spanCount
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(position: Int) -> T? {
        precondition(position >= 0 && position < spans.count)

        let i = BTree.Index(offsetBy: position, in: spans.t)
        guard let (leaf, offset) = i.read() else {
            return nil
        }

        return leaf.spans.first(where: { $0.range.contains(offset) })?.data
    }

    // Returns a cache of the same size, but only with the spans that
    // overlap bounds.
    subscript(bounds: Range<Int>) -> IntervalCache {
        precondition(bounds.lowerBound >= 0 && bounds.upperBound <= spans.count)

        let i = BTree.Index(offsetBy: bounds.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: bounds.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? bounds.lowerBound
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? bounds.upperBound

        var b = BTree<SpansSummary<T>>.Builder()
        var prefix = SpansBuilder<T>(totalCount: start).build().t
        b.push(&prefix.root)

        var t = spans.t
        b.push(&t.root, slicedBy: start..<end)

        var suffix = SpansBuilder<T>(totalCount: spans.count - end).build().t
        b.push(&suffix.root)

        return IntervalCache(Spans(BTree(b.build())))
    }

    mutating func set(_ value: T, forRange range: Range<Int>) {
        var sb = SpansBuilder<T>(totalCount: spans.count)
        sb.add(value, covering: range)
        let new = sb.build()

        self.spans = spans.merging(new) { $0 ?? $1 }
    }

    mutating func invalidate(range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= spans.count)

        let i = BTree.Index(offsetBy: range.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: range.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? range.lowerBound
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? range.upperBound

        var b = BTree<SpansSummary<T>>.Builder()

        var t = spans.t
        b.push(&t.root, slicedBy: 0..<start)

        var new = SpansBuilder<T>(totalCount: range.count).build().t.root
        b.push(&new)

        b.push(&t.root, slicedBy: end..<spans.count)

        self.spans = Spans(BTree(b.build()))
    }
}

struct Span<T> {
    var range: Range<Int>
    var data: T
}

struct SpansLeaf<T>: BTreeLeaf {
    static var minSize: Int { 32 }
    static var maxSize: Int { 64 }

    var count: Int
    var spans: [Span<T>]

    init() {
        count = 0
        spans = []
    }

    init(count: Int, spans: [Span<T>]) {
        self.count = count
        self.spans = spans
    }

    static var zero: SpansLeaf {
        SpansLeaf()
    }

    var isUndersized: Bool {
        spans.count < SpansLeaf.minSize
    }

    mutating func pushMaybeSplitting(other: SpansLeaf) -> SpansLeaf? {
        for span in other.spans {
            let range = span.range.offset(by: count)
            assert(!range.isEmpty)
            spans.append(Span(range: range, data: span.data))
        }
        count += other.count

        if count <= SpansLeaf.maxSize {
            return nil
        } else {
            let splitIndex = spans.count / 2
            let splitCount = spans[splitIndex].range.lowerBound

            var new = Array(spans[splitIndex...])
            for i in 0..<new.count {
                new[i].range = new[i].range.offset(by: -splitCount)
            }
            let newCount = count - splitCount

            spans.removeLast(new.count)
            count = splitCount

            return SpansLeaf(count: newCount, spans: new)
        }
    }

    subscript(bounds: Range<Int>) -> SpansLeaf {
        var s: [Span<T>] = []
        for span in spans {
            let range = span.range.clamped(to: bounds).offset(by: -bounds.lowerBound)

            if !range.isEmpty {
                s.append(Span(range: range, data: span.data))
            }
        }

        return SpansLeaf(count: bounds.count, spans: s)
    }
}

struct SpansSummary<T>: BTreeSummary {
    static func += (left: inout SpansSummary<T>, right: SpansSummary<T>) {
        left.spans += right.spans
        left.range = left.range.union(right.range)
    }

    static var zero: SpansSummary<T> {
        SpansSummary()
    }

    var spans: Int
    var range: Range<Int>

    init() {
        self.spans = 0
        self.range = 0..<0
    }

    init(summarizing leaf: SpansLeaf<T>) {
        spans = leaf.spans.count

        var range = 0..<0
        for span in leaf.spans {
            range = range.union(span.range)
        }

        self.range = range
    }
}

struct Spans<T> {
    var t: BTree<SpansSummary<T>>

    var count: Int {
        // TODO: once we make Rope, etc. wrap BTree, then
        // we can define BTree/count directly.
        t.root.count
    }

    var spanCount: Int {
        t.root.summary.spans
    }

    init(_ tree: BTree<SpansSummary<T>>) {
        self.t = tree
    }

    func merging<O>(_ other: Spans<T>, transform: (T?, T?) -> O?) -> Spans<O> {
        precondition(count == other.count)

        var sb = SpansBuilder<O>(totalCount: count)

        var left = self.makeIterator()
        var right = other.makeIterator()

        var nextLeft = left.next()
        var nextRight = right.next()

        while true {
            if nextLeft == nil && nextRight == nil {
                break
            } else if nextLeft == nil {
                let span = nextRight!

                if let transformed = transform(nil, span.data) {
                    sb.add(transformed, covering: span.range)
                }

                while let span = right.next() {
                    if let transformed = transform(nil, span.data) {
                        sb.add(transformed, covering: span.range)
                    }
                }

                break

            } else if nextRight == nil {
                let span = nextLeft!

                if let transformed = transform(span.data, nil) {
                    sb.add(transformed, covering: span.range)
                }

                while let span = left.next() {
                    if let transformed = transform(span.data, nil) {
                        sb.add(transformed, covering: span.range)
                    }
                }

                break
            }

            let spanLeft = nextLeft!
            let spanRight = nextRight!

            var rangeLeft = spanLeft.range
            var rangeRight = spanRight.range

            if !rangeLeft.overlaps(rangeRight) {
                if rangeLeft.lowerBound < rangeRight.lowerBound {
                    if let transformed = transform(spanLeft.data, nil) {
                        sb.add(transformed, covering: rangeLeft)
                    }
                    nextLeft = left.next()
                } else {
                    if let transformed = transform(spanRight.data, nil) {
                        sb.add(transformed, covering: rangeRight)
                    }
                    nextRight = right.next()
                }

                continue
            }

            if rangeLeft.lowerBound < rangeRight.lowerBound {
                let prefix = rangeLeft.prefix(rangeRight)
                if let transformed = transform(spanLeft.data, nil) {
                    sb.add(transformed, covering: prefix)
                }
                rangeRight = rangeRight.suffix(prefix)
            } else if rangeRight.lowerBound < rangeLeft.lowerBound {
                let prefix = rangeRight.prefix(rangeLeft)
                if let transformed = transform(spanRight.data, nil) {
                    sb.add(transformed, covering: prefix)
                }
                rangeLeft = rangeLeft.suffix(prefix)
            }

            assert(rangeLeft.lowerBound == rangeRight.lowerBound)

            let intersection = rangeLeft.clamped(to: rangeRight)
            assert(!intersection.isEmpty)
            if let transformed = transform(spanLeft.data, spanRight.data) {
                sb.add(transformed, covering: intersection)
            }

            rangeLeft = rangeLeft.suffix(intersection)
            rangeRight = rangeRight.suffix(intersection)

            if rangeLeft.isEmpty {
                nextLeft = left.next()
            } else {
                nextLeft = Span(range: rangeLeft, data: spanLeft.data)
            }

            if rangeRight.isEmpty {
                nextRight = right.next()
            } else {
                nextRight = Span(range: rangeRight, data: spanRight.data)
            }
        }

        return sb.build()
    }
}

extension Spans: Sequence {
    struct Iterator: IteratorProtocol {
        var i: BTree<SpansSummary<T>>.Index
        var ii: Int

        init(_ spans: Spans<T>) {
            self.i = spans.t.startIndex
            self.ii = 0
        }

        mutating func next() -> Span<T>? {
            guard let (leaf, _) = i.read() else {
                return nil
            }

            if leaf.spans.isEmpty {
                return nil
            }

            let span = leaf.spans[ii]
            let offsetOfLeaf = i.offsetOfLeaf
            ii += 1
            if ii == leaf.spans.count {
                _ = i.nextLeaf()
                ii = 0
            }

            return Span(range: span.range.offset(by: offsetOfLeaf), data: span.data)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(self)
    }
}


struct SpansBuilder<T> {
    var b: BTree<SpansSummary<T>>.Builder
    var leaf: SpansLeaf<T>
    var count: Int
    var totalCount: Int

    init(totalCount: Int) {
        self.b = BTree<SpansSummary>.Builder()
        self.leaf = SpansLeaf()
        self.count = 0
        self.totalCount = totalCount
    }

    mutating func add(_ data: T, covering range: Range<Int>) {
        assert(range.lowerBound > count + (leaf.spans.last?.range.upperBound ?? 0))

        if leaf.spans.count == SpansLeaf<T>.maxSize {
            leaf.count = range.lowerBound - count
            self.count = range.lowerBound
            b.push(leaf: leaf)
            leaf = SpansLeaf()
        }

        leaf.spans.append(Span(range: range, data: data))
        totalCount = Swift.max(totalCount, range.upperBound)
    }

    consuming func build() -> Spans<T> {
        leaf.count = totalCount - count
        b.push(leaf: leaf)

        return Spans(BTree(b.build()))
    }
}

extension Range {
    func union(_ other: Range<Bound>) -> Range<Bound> {
        let start = Swift.min(lowerBound, other.lowerBound)
        let end = Swift.max(upperBound, other.upperBound)

        return start..<end
    }

    // The porton of `self` that comes before `other`.
    // If `other` starts before `self`, returns an empty
    // starting at other.lowerBounds.
    func prefix(_ other: Range) -> Range {
        return Swift.min(lowerBound, other.lowerBound)..<Swift.min(upperBound, other.lowerBound)
    }

    // The portion of `self` that comes after `other`.
    // If `other` ends after `self`, returns an empty
    // range ending at other.upperBound.
    func suffix(_ other: Range) -> Range {
        return Swift.max(lowerBound, other.upperBound)..<Swift.max(upperBound, other.upperBound)
    }
}
