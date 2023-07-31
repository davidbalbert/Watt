//
//  IntervalCache.swift
//  Watt
//
//  Created by David Albert on 7/31/23.
//

import Foundation

struct IntervalCache<T> {
    var spans: Spans<T>

    init() {
        let b = SpansBuilder<T>(totalCount: 0)
        spans = b.build()
    }

    init(_ spans: Spans<T>) {
        self.spans = spans
    }

    var count: Int {
        spans.count
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(position: Int) -> T? {
        precondition(position >= 0 && position < count)

        let i = BTree.Index(offsetBy: position, in: spans.t)
        guard let (leaf, offset) = i.read() else {
            return nil
        }

        return leaf.spans.first(where: { $0.range.contains(offset) })?.data
    }

    subscript(bounds: Range<Int>) -> IntervalCache {
        precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
        
        let i = BTree.Index(offsetBy: bounds.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: bounds.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? bounds.lowerBound
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? bounds.upperBound

        return IntervalCache(Spans(BTree(spans.t, slicedBy: start..<end)))
    }

    mutating func set(_ value: T, forRange range: Range<Int>) {
        var sb = SpansBuilder<T>(totalCount: count)
        sb.add(value, covering: range)
        let new = sb.build()

        self.spans = spans.merging(new) { $1 }
    }

    mutating func invalidate(bounds: Range<Int>) {
        precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)

        let i = BTree.Index(offsetBy: bounds.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: bounds.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? bounds.lowerBound
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? bounds.upperBound

        var t = spans.t
        var b = BTree<SpansSummary<T>>.Builder()
        b.push(&t.root, slicedBy: 0..<start)

        var new = SpansBuilder<T>(totalCount: bounds.count).build().t.root
        b.push(&new)

        b.push(&t.root, slicedBy: end..<count)

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
        t.count
    }

    init(_ tree: BTree<SpansSummary<T>>) {
        self.t = tree
    }

    /// Creates a new Spans instance by merging spans from `other` with `self`,
    /// using a closure to transform values.
    ///
    /// New spans are created from non-overlapping regions of existing spans,
    /// and by combining overlapping regions into new spans. In all cases,
    /// new values are generated by calling a closure that transforms the
    /// value of the existing span or spans.
    ///
    /// If transform returns nil, no span will be created for that region.

    func merging<O>(_ other: Spans<T>, transform: (T, T?) -> O?) -> Spans<O> {
        precondition(count == other.count)

        var sb = SpansBuilder<O>(totalCount: count)

        var left = self.makeIterator()
        var right = other.makeIterator()

        var nextLeft = left.next()
        var nextRight = right.next()

        while true {
            if nextLeft == nil && nextRight == nil {
                break
            } else if (nextLeft == nil) != (nextRight == nil) {
                var iter = nextLeft == nil ? right : left

                let span = (nextLeft ?? nextRight)!

                if let transformed = transform(span.data, nil) {
                    sb.add(transformed, covering: span.range)
                }

                while let span = iter.next() {
                    if let transformed = transform(span.data, nil) {
                        sb.add(transformed, covering: span.range)
                    }
                }

                break
            }

            let spanLeft = nextLeft!
            let spanRight = nextRight!

            let rangeLeft = spanLeft.range
            let rangeRight = spanRight.range

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




            
        }
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
        assert(range.upperBound <= totalCount)

        if leaf.spans.count == SpansLeaf<T>.maxSize {
            leaf.count = range.lowerBound - count
            self.count = range.lowerBound
            b.push(leaf: leaf)
            leaf = SpansLeaf()
        }

        leaf.spans.append(Span(range: range, data: data))
    }

    consuming func build() -> Spans<T> {
        leaf.count = totalCount - count
        b.push(leaf: leaf)

        return Spans(BTree(b.build()))
    }
}

extension Range where Bound: Comparable {
    func union(_ other: Range<Bound>) -> Range<Bound> {
        let start = Swift.min(lowerBound, other.lowerBound)
        let end = Swift.max(upperBound, other.upperBound)

        return start..<end
    }
}
